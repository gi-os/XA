# filmsim: proving spektrafilm for DIGI

A prototype, run on a laptop or a Linux box, that answers one question: can XA give DIGI
photos [spektrafilm](https://github.com/andreavolpato/spektrafilm)'s film simulation on the
phone? It can.

## The idea

spektrafilm bakes a stock into two tables with the negative's dye density as the wire between
them (its `2lut` topology): scene light → negative density, and negative density → print.
Everything that depends on neighbouring pixels runs on the phone around those tables:

```
light → scatter + halation → table 1 → couplers (local contrast) → dye blur → grain → table 2 → scan sharpen
```

## What it showed (Portra 400 on Portra Endura, two iPhone photos, 1500 px)

| Check | Result |
|---|---|
| Tables against spektrafilm's own per-pixel model | ΔE2000 mean **0.10**, 95th percentile 0.28: identical to the eye |
| Spatial effects, tables only vs full sim (grain off) | ΔE mean 2.40 |
| Spatial effects, tables + our phone effects vs full sim | ΔE mean **1.60–1.71** |
| Full sim, grain on, vs our path with grain on | ΔE mean 2.1–2.6, including two different random grains |
| Time, full simulation (CPU, numpy) | 6–12 s for 2 MP |
| Time, our path (CPU, numpy, unoptimised) | 0.5–0.8 s for 2 MP; Core Image on the iPhone GPU will be milliseconds |

`fitted.json` holds the effect strengths fitted against the full simulation.

## Run it

Python 3.13 and spektrafilm (`pip install -e .` in a clone of it), then:

```
python bake.py kodak_portra_400 kodak_portra_endura 2lut   # tables → build/lut_bundles
python fidelity.py        # tables vs the per-pixel model
python spatial.py det IMG 1500 && python fit.py && python evalp.py
python sheet.py           # one frame through six stocks
```

The scripts expect sRGB PNGs next to them (`IMG_0682.png`, `IMG_1011.png`, `stadium.png`).
Test photos are not in the repo.

## License

These scripts import spektrafilm and are GPL version 3. The tables they bake are CC BY-SA 4.0
(see spektrafilm's LICENSE notes).
