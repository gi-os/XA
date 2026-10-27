# XA

A camera for iPhone: DIGI (a 2003 point-and-shoot with film sims, looks and shapes), FILM (rolls of
emulated stock), and more. Free, no account, nothing collected. The house rules, pipeline and skills
come from the gi-os kit, loaded at session start (`.gios/`, read-only here).

- Code: `XA/` app (App, Camera, Film, UI, Resources), `Capture/` and `Control/` extensions,
  `Shared/` capture intent, `StoreKit/Tips.storekit` for the tip jar, `XATests/`.
- Built with the iOS 27.1 SDK for iPhone Duo. The tip-jar purchase test hangs on CI's simulator and
  is skipped there (SKIP_TESTS); it runs from Xcode.
- App Store: screenshots are taken on a phone (the simulator has no camera) and committed in
  `fastlane/screenshots/en-US`; `asc-setup.yml` creates the tips, age rating and availability.
  Approved versions go live automatically (AUTO_RELEASE).
