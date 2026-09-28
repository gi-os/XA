# XA

A camera for iPhone that's fun to use, and serious when you want it to be. iOS port of
[Roll](https://github.com/gi-os/Roll) for the Light Phone III.

## Two cameras

- **DIGI** is a 2003 point-and-shoot. 1, 2, 3 or 5 megapixels, cheap processing on purpose
  (clipped highlights, a sharpening halo, color noise, a JPEG squeezed hard), and a stack of:
  - **a sim**: a film simulation, fully editable (color, tone curve, split tone, grain,
    halation, vignette, its own film box);
  - **a look**: Clean, Grain, Sixteen, Pocket, 1-Bit, Press, Heat, Booth;
  - **a shape**: Capsule, Porthole, Window, Crush, Nova. Outside the shape is empty pixels,
    saved as a PNG.
- **PRO** is the iPhone at its best: the biggest photo the sensor makes, quality-first
  processing, saved as the camera made it (HEIF or JPEG). Lens buttons, a live histogram, and
  a WB · EV · S · ISO · FOCUS strip with a tick dial. Shutter and ISO priority work the way Roll's do.

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
(on white tape) and Edge. In the corner or following the frame, around the Porthole and up the
side of Crush. The instant sims write the date by hand on the print instead.

## The camera button

XA ships a Lock Screen camera and a Control Center control, so it can be the camera:
Settings › Camera › Camera Control › Launch Camera › XA. The Lock Screen camera takes its
settings from the app through the capture intent.

## Controls

- Pull down on the camera for the roll; flick up to go back.
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

Fonts are bundled open-licence faces from Google Fonts (SIL OFL 1.1, Apache 2.0 for Roboto
Condensed and Yellowtail).
