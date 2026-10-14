# XA

A camera for iPhone that's fun to use, and serious when you want it to be. iOS port of
[Roll](https://github.com/gi-os/Roll) for the Light Phone III.

Free, with every feature: no subscription, no ads, no account, nothing collected. An optional
tip jar (tips unlock nothing) keeps it going.

## Five cameras

- **DIGI** is a 2003 point-and-shoot. 1, 2, 3 or 5 megapixels, cheap processing on purpose
  (clipped highlights, a sharpening halo, color noise, a JPEG squeezed hard), its whole live
  screen, and a stack of:
  - **a sim**: a film simulation, fully editable (color, tone curve, split tone, grain,
    halation, vignette, its own film box);
  - **a look**: Clean, Grain, Sixteen, Pocket, Pocket Color, 1-Bit, Press, Heat, Booth;
  - **a shape**: Capsule, Porthole, Window, Crush, Nova and the instant prints. Outside the
    shape is empty pixels, saved as a PNG.
- **FILM** loads a roll: eleven stocks modelled with [spektrafilm](https://github.com/andreavolpato/spektrafilm),
  seen through an XA-style rangefinder finder. 110, half frame, 35mm or 120; flash, light leaks,
  a mist filter; the lab's auto-correction, color timing and preflash. The default **drum scan**
  scans the negative at about 5600 dpi (up to 48 MP, the whole sensor on a 48 MP iPhone), so the
  grain is resolved into dye clouds when you zoom in.
- **PRO** is the iPhone at its best: the biggest photo the sensor makes, quality-first
  processing, saved as the camera made it (HEIF or JPEG). Lens buttons, a live histogram, and
  a WB · EV · S · ISO · FOCUS strip with a tick dial. Shutter and ISO priority work the way Roll's do.
- **VIDEO** has twelve tapes: Clean, Pocket, Pocket Color, Pocket 3D, Super 8, VHS, Trails,
  Motion, Stop Motion, CCTV, Slit-scan and Datamosh.
- **BOOTH** is a photo-sticker booth: four shots with a countdown, big eyes, backdrops and a
  sticker sheet.

## Sims

| Sim | After |
|---|---|
| XAcolor Nocturne 800T | tungsten cinema stock, red halation |
| XAcolor Visage 800 | portrait pro stock |
| XAcolor Prima X 400 | green-box consumer 400 |
| XAcolor Amethyst 400 | the purple cast |
| XA Instant Sunday 600 | instant film, printed on a white frame |
| XA Instant Sunday Round | the round instant |
| XApan Onyx 3200 | high-contrast black and white |

Long-press a sim to edit it. Edits to a preset save as a film of your own. **Save** in the
film picker turns the current sim + look + shape into a new sim.

## Date backs

Quartz, Dots and Camcorder are Roll's DateStamp drawn the same way: seven mitred segments,
5×7 round lamps that lean as a staircase, a keylined condensed face. Plus LCD, Stamp, Marker
(on white tape), Edge and Digicam. In the corner or following the frame, around the Porthole and up the
side of Crush. The instant sims write the date by hand on the print instead.

## The camera button

XA ships a Lock Screen camera and a Control Center control, so it can be the camera:
Settings › Camera › Camera Control › Launch Camera › XA. The Lock Screen camera takes its
settings from the app through the capture intent.

## Controls

- Swipe up from the shutter row (or tap the roll button) for the roll; drag it down to go back.
- Camera Control: DIGI slides through sims and looks, PRO through exposure and zoom. Click to shoot.
- Volume buttons shoot too.

## Build

```
brew install xcodegen
xcodegen generate
open XA.xcodeproj
```

CI: `check.yml` builds and tests every branch unsigned. A push to `main` runs `build.yml`,
which signs with fastlane match (`gi-os/ios-certs`) and uploads to TestFlight.
`release.yml` (run by hand) uploads the App Store text in `fastlane/metadata`, the screenshots in
`fastlane/screenshots/en-US` and the App Review details; ticking **submit** sends the newest build to
App Review. The support and privacy pages are `docs/`, served at https://gi-os.github.io/XA/.

Screenshots: `tools/screenshots/capture.py` runs a debug build in the simulator on still photos
(the simulator has no camera; the demo feed sends them through the real viewfinder and develop),
and `frame.py` adds the headline and the phone. Swap in your own photos and run them again.

Fonts are bundled open-licence faces from Google Fonts (SIL OFL 1.1, Apache 2.0 for Roboto
Condensed and Yellowtail).

## License

XA is free software: the GNU General Public License version 3 (`LICENSE`), with an additional
permission for the App Store and TestFlight (`EXCEPTION.md`). Credits, font licenses and the
spektrafilm notice are in `NOTICE.md`.
