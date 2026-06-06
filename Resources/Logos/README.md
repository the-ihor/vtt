# Provider logos

The bundled PNGs are the official brand glyphs for each cloud provider, used in
the Settings sidebar in place of an SF Symbol fallback:

- `openai.png`
- `deepgram.png`
- `elevenlabs.png`

They're rendered from each vendor's official brand mark (sourced from their
press / brand kits) as square, transparent alpha masks (~128 px). The app
treats them as template images and tints them with the provider's accent color
(`ProviderIcon` in `SettingsView.swift`), so a single monochrome glyph adapts to
both light and dark mode. To swap in a different logo, drop a replacement PNG
here with the same filename — alpha is all that matters since the color comes
from the tint.

These are third-party trademarks; they ship here for in-app provider
identification only. Refer to each vendor's brand guidelines before reusing them
elsewhere:

- OpenAI: https://openai.com/brand
- Deepgram: https://deepgram.com (brand assets / press)
- ElevenLabs: https://elevenlabs.io (brand assets / press)

`scripts/make-app.sh` copies any PNGs in this folder into the app bundle, and
the app loads them at runtime (falling back to SF Symbols when absent).
