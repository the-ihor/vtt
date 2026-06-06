import AppKit

// Manual NSApplication bootstrap so we get full control over the panel and run
// as an accessory (no Dock icon, no menu bar app menu) — the bar IS the app.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
