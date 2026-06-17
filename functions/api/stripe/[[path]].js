const STRIPE_API = "https://api.stripe.com/v1";
const ACTIVE_STATUSES = new Set(["active", "trialing", "past_due"]);

export async function onRequest(context) {
  const path = Array.isArray(context.params.path)
    ? context.params.path.join("/")
    : String(context.params.path || "");

  if (context.request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }
  if (context.request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  try {
    switch (path) {
      case "checkout":
        return await checkout(context);
      case "price":
        return await price(context);
      case "activate":
        return await activate(context);
      case "recover":
        return await recover(context);
      case "validate":
        return await validate(context);
      case "portal":
        return await portal(context);
      default:
        return json({ error: "Unknown Stripe endpoint." }, 404);
    }
  } catch (error) {
    const message = error instanceof PublicError ? error.message : "Stripe endpoint failed.";
    const status = error instanceof PublicError ? error.status : 500;
    return json({ error: message }, status);
  }
}

async function checkout({ request, env }) {
  const body = await readJSON(request);
  const baseURL = publicBaseURL(request, env);
  const instanceID = cleanString(body.instance_id, "");
  if (!instanceID) throw new PublicError("Missing VTT instance ID.", 400);

  // Always create the Checkout Session server-side: it is the only path that can
  // stamp this Mac's instance_id into session/subscription metadata, which
  // activate() then verifies. A Stripe Payment Link cannot carry per-request
  // metadata, so a link-based checkout could never satisfy that binding.
  const params = new URLSearchParams({
    mode: "subscription",
    "line_items[0][price]": required(env.STRIPE_PRICE_ID, "STRIPE_PRICE_ID"),
    "line_items[0][quantity]": "1",
    success_url: `${baseURL}/stripe-success.html?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${baseURL}/#download`,
    allow_promotion_codes: "true",
    billing_address_collection: "auto",
    client_reference_id: cleanString(body.instance_name, "Mac"),
    "metadata[app]": "vtt",
    "metadata[plan]": "unlimited_dictation",
    "metadata[instance_id]": instanceID,
    "subscription_data[metadata][app]": "vtt",
    "subscription_data[metadata][plan]": "unlimited_dictation",
    "subscription_data[metadata][instance_id]": instanceID,
  });

  const session = await stripe(env, "checkout/sessions", {
    method: "POST",
    body: params,
  });

  if (!session.url) throw new PublicError("Stripe did not return a checkout URL.", 502);
  return json({ url: session.url });
}

async function price({ env }) {
  // Let the app show the live price/currency instead of a hardcoded string, so a
  // price change in Stripe needs no app update. Stripe is the source of truth.
  const priceID = required(env.STRIPE_PRICE_ID, "STRIPE_PRICE_ID");
  const p = await stripe(env, `prices/${encodeURIComponent(priceID)}`);
  return json({
    unit_amount: p.unit_amount,
    currency: p.currency,
    interval: p.recurring?.interval || "month",
  });
}

async function activate({ request, env }) {
  const body = await readJSON(request);
  const sessionID = cleanString(body.checkout_session_id || body.activation_code, "");
  const instanceID = cleanString(body.instance_id, "");
  if (!sessionID.startsWith("cs_")) {
    throw new PublicError("Paste the activation code from the Stripe success page.", 400);
  }
  if (!instanceID) {
    throw new PublicError("Missing VTT instance ID.", 400);
  }

  const session = await stripe(env, `checkout/sessions/${encodeURIComponent(sessionID)}?expand[]=subscription`);
  if (cleanString(session.metadata?.instance_id, "") !== instanceID) {
    throw new PublicError("This activation code belongs to a different Mac.", 403);
  }
  const subscription = await subscriptionFromSession(env, session);
  if (subscription.status === "incomplete" || subscription.status === "incomplete_expired") {
    // The redirect can outrun Stripe finalizing a card payment. Let the user retry.
    throw new PublicError("Your payment is still being confirmed. Wait a few seconds, then tap Activate again.", 425);
  }
  assertSubscriptionActiveForProduct(subscription, env);

  const customerID = customerIDFromSession(session);
  if (!customerID) throw new PublicError("Stripe did not attach a customer to this checkout.", 409);

  const token = await signEntitlement(env, {
    version: 1,
    customer_id: customerID,
    subscription_id: subscription.id,
    instance_id: instanceID,
    product_id: required(env.STRIPE_PRODUCT_ID, "STRIPE_PRODUCT_ID"),
    customer_email: cleanString(session.customer_details?.email || session.customer_email, null),
    issued_at: Math.floor(Date.now() / 1000),
  });

  return json({
    active: true,
    entitlement_token: token,
    customer_id: customerID,
    subscription_id: subscription.id,
  });
}

async function recover({ request, env }) {
  const body = await readJSON(request);
  const customerID = cleanString(body.customer_id, "");
  const instanceID = cleanString(body.instance_id, "");
  if (!customerID.startsWith("cus_")) {
    throw new PublicError('Enter your Stripe customer ID — it starts with "cus_".', 400);
  }
  if (!instanceID) throw new PublicError("Missing VTT instance ID.", 400);

  // The customer ID is a support-issued license key: mint a fresh entitlement for
  // this Mac only if the customer has an active VTT subscription. Stateless by
  // design — no per-user server record, no seat tracking.
  const list = await stripe(
    env,
    `subscriptions?customer=${encodeURIComponent(customerID)}&status=all&limit=100`
  );
  const subscription = (list.data || []).find((sub) => subscriptionActiveForProduct(sub, env));
  if (!subscription) {
    throw new PublicError("No active VTT subscription was found for that customer ID.", 402);
  }

  const token = await signEntitlement(env, {
    version: 1,
    customer_id: customerID,
    subscription_id: subscription.id,
    instance_id: instanceID,
    product_id: required(env.STRIPE_PRODUCT_ID, "STRIPE_PRODUCT_ID"),
    issued_at: Math.floor(Date.now() / 1000),
  });

  return json({
    active: true,
    entitlement_token: token,
    customer_id: customerID,
    subscription_id: subscription.id,
  });
}

async function validate({ request, env }) {
  const body = await readJSON(request);
  const entitlement = await verifyEntitlement(env, cleanString(body.entitlement_token, ""));
  assertInstanceMatches(entitlement, body);
  const subscription = await stripe(env, `subscriptions/${encodeURIComponent(entitlement.subscription_id)}`);
  const active = subscriptionActiveForProduct(subscription, env);

  return json({
    active,
    customer_id: entitlement.customer_id,
    subscription_id: entitlement.subscription_id,
    status: subscription.status,
  });
}

async function portal({ request, env }) {
  const body = await readJSON(request);
  const entitlement = await verifyEntitlement(env, cleanString(body.entitlement_token, ""));
  assertInstanceMatches(entitlement, body);
  const subscription = await stripe(env, `subscriptions/${encodeURIComponent(entitlement.subscription_id)}`);
  if (!subscriptionActiveForProduct(subscription, env)) {
    throw new PublicError("This subscription is not active.", 402);
  }

  const params = new URLSearchParams({
    customer: entitlement.customer_id,
    return_url: publicBaseURL(request, env),
  });
  const session = await stripe(env, "billing_portal/sessions", {
    method: "POST",
    body: params,
  });

  if (!session.url) throw new PublicError("Stripe did not return a billing portal URL.", 502);
  return json({ url: session.url });
}

async function subscriptionFromSession(env, session) {
  if (typeof session.subscription === "object" && session.subscription?.id) {
    return session.subscription;
  }
  if (typeof session.subscription === "string") {
    return stripe(env, `subscriptions/${encodeURIComponent(session.subscription)}`);
  }
  throw new PublicError("Checkout has not created a subscription yet.", 409);
}

function customerIDFromSession(session) {
  if (typeof session.customer === "string") return session.customer;
  if (typeof session.customer === "object" && session.customer?.id) return session.customer.id;
  return null;
}

function assertSubscriptionActiveForProduct(subscription, env) {
  if (!subscriptionActiveForProduct(subscription, env)) {
    throw new PublicError("The Stripe subscription is not active for VTT.", 402);
  }
}

function subscriptionActiveForProduct(subscription, env) {
  if (!subscription?.id || !ACTIVE_STATUSES.has(subscription.status)) return false;
  const productID = required(env.STRIPE_PRODUCT_ID, "STRIPE_PRODUCT_ID");
  const items = subscription.items?.data || [];
  return items.some((item) => productIDFromPrice(item.price) === productID);
}

function productIDFromPrice(price) {
  if (typeof price?.product === "string") return price.product;
  if (typeof price?.product === "object" && price.product?.id) return price.product.id;
  return null;
}

async function stripe(env, path, init = {}) {
  const response = await fetch(`${STRIPE_API}/${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${required(env.STRIPE_SECRET_KEY, "STRIPE_SECRET_KEY")}`,
      "Content-Type": "application/x-www-form-urlencoded",
      ...(init.headers || {}),
    },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = data?.error?.message || "Stripe request failed.";
    throw new PublicError(message, response.status);
  }
  return data;
}

async function signEntitlement(env, payload) {
  const encodedPayload = base64URL(new TextEncoder().encode(JSON.stringify(payload)));
  const signature = await hmac(env, encodedPayload);
  return `${encodedPayload}.${signature}`;
}

async function verifyEntitlement(env, token) {
  const [encodedPayload, signature, extra] = token.split(".");
  if (!encodedPayload || !signature || extra) {
    throw new PublicError("Invalid entitlement token.", 400);
  }

  const expected = await hmac(env, encodedPayload);
  if (!timingSafeEqual(signature, expected)) {
    throw new PublicError("Invalid entitlement token.", 400);
  }

  let payload;
  try {
    payload = JSON.parse(new TextDecoder().decode(unbase64URL(encodedPayload)));
  } catch {
    throw new PublicError("Invalid entitlement token.", 400);
  }

  if (!payload.customer_id || !payload.subscription_id) {
    throw new PublicError("Invalid entitlement token.", 400);
  }
  return payload;
}

function assertInstanceMatches(entitlement, body) {
  const instanceID = cleanString(body.instance_id, "");
  if (!entitlement.instance_id || !instanceID || entitlement.instance_id !== instanceID) {
    throw new PublicError("This entitlement token belongs to a different Mac.", 403);
  }
}

async function hmac(env, value) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(required(env.ENTITLEMENT_SIGNING_SECRET, "ENTITLEMENT_SIGNING_SECRET")),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return base64URL(new Uint8Array(signature));
}

function base64URL(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function unbase64URL(value) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function timingSafeEqual(a, b) {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i += 1) diff |= left[i] ^ right[i];
  return diff === 0;
}

async function readJSON(request) {
  const text = await request.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    throw new PublicError("Expected a JSON request body.", 400);
  }
}

function publicBaseURL(request, env) {
  if (env.PUBLIC_BASE_URL) return env.PUBLIC_BASE_URL.replace(/\/+$/g, "");
  const url = new URL(request.url);
  return url.origin;
}

function cleanString(value, fallback) {
  if (typeof value !== "string") return fallback;
  const trimmed = value.trim();
  return trimmed || fallback;
}

function required(value, name) {
  if (!value) throw new PublicError(`Missing ${name}.`, 500);
  return value;
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...corsHeaders(),
    },
  });
}

class PublicError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}
