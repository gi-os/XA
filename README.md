# XA

A camera for iPhone that's fun to use. Live filters on the viewfinder and in the file, a quartz
date back, Camera Control as the filter dial, and a contact sheet of everything you've shot.

iOS port of [Roll](https://github.com/gi-os/Roll) for the Light Phone III.

- **Filters**: Film, 16 Color (the m-cas palette), Game Boy, Dither, Halftone, Thermal, Purikura. What the viewfinder shows is what gets saved.
- **Camera Control**: slide to change filter; click to shoot. Volume buttons shoot too.
- **A shutter that never waits**: 12MP, speed-first capture; filtering and saving happen behind the viewfinder.
- **Date back**: `'26 9 26` in the corner, on or off.
- **Roll**: pictures go to an *XA* album in Photos; the contact sheet shows it.
- **iPhone Duo**: on the inner display the roll sits beside the viewfinder.

## Build

```sh
brew install xcodegen
xcodegen generate
open XA.xcodeproj
```

CI: `check.yml` builds and tests every branch unsigned. A push to `main` runs `build.yml`,
which signs with fastlane match (`gi-os/ios-certs`) and uploads to TestFlight.
