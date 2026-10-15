# XA FILM vs spektrafilm: the gaps

A ranked list of where XA's FILM output differs from spektrafilm's full simulation, at full
view and zoomed into a drum scan, with what each would cost to port to Core Image on an iPhone.
Written by an analysis pass over both pipelines (October 2026); the port itself is still to do.

**Ported so far:** grain (gaps 2, 4 and 12, and the look of 9). FilmLab's grain is spektrafilm's
sublayer model: each dye layer's fast, mid and slow sublayer has the granularity its layer curves
give at the pixel's density (grain_bake.py → grain.json), independent per layer, hashed so it never
repeats. Its strength at a phone screen's pixel (18 µm of film) is spektrafilm's to within a few
percent at drum and lab pitch (FilmGrainTests). The dye clouds are drawn 5× spektrafilm's size
(Fit.cloudScale), so a drum scan shows clouds when zoomed instead of single-pixel speckle; at a
lab scan they are below a pixel, as spektrafilm's are. Stocks follow spektrafilm's data, with a
gentle ladder by speed ((ISO/400)^¼) on top.

I measured XA's real develop (exported from the iPhone Air simulator) against spektrafilm v0.3.4's full simulation at the same pixel size. Stocks were Bowery 400 vs Portra 400 on Endura, and Canal 500T vs Vision3 500T on 2383, at drum 4.5 µm/px and lab 11.66 µm/px.

Main findings:
- **Exposure and lab correction** cause the biggest difference at full view: ΔE00 12.2 on the test portrait.
- **Grain** differs a lot.
  - Per pixel at drum, spektrafilm's std is 16/11/18 levels (R/G/B) against XA's 5.5/4.8/3.6.
  - spektrafilm's grain is independent per channel and about one pixel in size. XA's is monochrome, soft blobs.
  - XA's grain field repeats exactly every 256 px (correlation 0.999 when shifted by 256 px).
- **XA's dye blur plus a large unsharp mask** remove fine detail and put black rings on high-contrast edges: −38 levels next to the edge.
- **XA's halation** is a hard red ring, not spektrafilm's faint wide glow.
- **Glare and the wide-gamut clip** add measurable errors: milky blacks, and ΔE 5–15 on saturated P3 colours.
- **Dye clouds when zoomed:** spektrafilm does not show them at drum pitch either. They only appear when it renders a crop at about 0.5 µm/px (the README's 12× crops). Matching that needs a zoom-time re-render of the visible area.

**Setup.** I extended XATests/FilmExportTests.swift with new options. It is the only file changed in the worktree, not committed:
- XA_FILM_RECIPES: several named recipe overrides in one run.
- XA_FILM_CROPS: 1:1 crops.
- XA_FILM_TRACE: saves FilmLab trace stages of each crop as Float32.
- XA_FILM_FULL=0: skips the full-size PNG and HEIC.
- XA_FILM_SMALL: also saves a phone-size copy.

Targets:
- target.png: a 16-bit 8000×5333 frame, which is exactly drum size. It has a grey wedge from −5 to +2 EV, a 5° slanted edge, bar patterns from 3.5 to 56 c/mm, white discs on a dark ground, a black square in a white field, and a grey field.
- hdr.exr: a highlight wedge to +8 EV, lamps at 16× linear on grey and on dark, and P3 colour patches.
- portrait12mp.png.

spektrafilm was run on matching crops with film_format_mm set so the pixel size matches. Auto exposure was off unless noted.

**Disk.** Only about 5 GB is free. One XA run hit "no space left on device"; it was re-run with crops and small copies only.

**Speed.** In my runs a 43 MP develop plus 8-bit render took 4–30 s on the simulator, not 2.5 s.

Everything is in /private/tmp/claude-501/-Users-giovannilupo-Library-Application-Support-Claude-scratch-workspaces-4321fd8d-5d6d-4b51-9188-756b7c291a34-46bfb955-ee91-4036-b53d-5f53687e8c50-scratch-2026-10-14-36b3df/026833a1-9bc2-4083-b543-c8468bea7be2/scratchpad/fidelity/gaps/:
- Scripts:
  - make_target.py, make_hdr.py: build the two targets.
  - sfrun.py: spektrafilm runner.
  - wedge.py: grain on the wedge.
  - spatial_cmp.py: edge, bars, halation, glare and grain autocorrelation.
  - decomp.py: spektrafilm with one effect turned off at a time.
  - hdr_cmp.py: highlights, P3 colours and lamps.
  - sf_portrait.py: spektrafilm on the portrait.
  - fullview.py: phone-size colour statistics.
  - xarun.sh: runs the XA export test.
- Outputs:
  - wedge_pure_drum.out, wedge_pure_lab.out
  - spatial_drum.out, decomp.out
  - hdr_bowery.out, hdr_canal.out
  - fullview.out
- Side-by-side images: panel_portrait_full.png, panel_eye_zoom.png, panel_eye_50.png, panel_sky_zoom.png.
- Raw renders: xa_wedge, xa_sp, xa_hdr, xa_por, xa_splab (XA), and sf_sp, sf_por (spektrafilm).

Priorities below weigh impact at full view, impact zoomed and porting cost together. Items 1, 7 and 12 are product decisions as much as fidelity fixes.

## 1. Exposure and lab correction: spektrafilm auto exposure vs LabAuto, scanner levels, saturation and the underexposure lift

- **spektrafilm:** Default full simulation runs centre-weighted auto exposure on a 256 px thumbnail of the whole frame (Gaussian mask, sigma 0.2 of the long edge). It fully normalises the weighted mean Y to 0.184, with no clamp. There is no colour balance: neutral enlarger CMY filters are fixed per film and paper from the database. There are no levels, no saturation boost and no shadow lift. The print keeps paper white at about 218/255 and black at about 13/255. On the test portrait the auto exposure is +2.82 EV.
- **XA:** No auto exposure: the stocks are calibrated so 0.18 grey prints at G 0.4614. LabAuto at its 0.7 default does the following:
- Exposure is corrected only beyond a ±0.45-stop dead band, at about 45% strength, clamped to −0.8…+1.2 stops (+1.19 on the portrait).
- Per-channel balance of up to ±25%, plus warming of cool frames (portrait gains R 1.04, G 0.98, B 1.12).
- Scanner levels from the 2nd/98th percentiles: black up to 0.14, white down to 0.8, so whites reach 255.
- Saturation up to +35%.
- An underexposure lift on any frame more than 0.9 stop under: the stock's toe vector plus +0.09 code on lab scans or +0.05 on drum. The portrait gets the full lift (1.0).
- **Full view:** The largest difference on most photos. On the portrait at phone size (1179 px wide), XA default vs spektrafilm default gives ΔE00 mean 12.2 (p95 25.0). Face L* is 42 vs 65, skin a* +20 vs +10 (XA is orange-red), and leaves L* 23 vs 33. XA's levels clip the sky to 255 with blue fringing, while spektrafilm keeps paper white at 218. LabAuto alone accounts for ΔE00 10.8. Even with both corrections off (XA without camera effects, glare or LabAuto, vs spektrafilm with auto exposure off), ΔE00 is still 8.0: XA's underexposure lift raises the leaves from L* 6 to 13 and chroma from 3.4 to 9.8.
- **Zoomed:** The same tone and colour shift at every zoom. The levels stretch makes grain stronger and clips highlight grain to flat 255, where spektrafilm keeps grain in paper-white areas.
- **Port cost:** Low, CPU only. spektrafilm's auto exposure is one Gaussian-weighted mean of Y on the existing meter copy (Darkroom.reduced, 1024 px), applied as a 2^EV gain in FilmLab. A spektrafilm mode would set labAuto to 0 and turn off applyScan levels, saturation and the underexposure lift; that also removes the 256 px proxy develop when glare is off. No GPU cost. Product risk: spektrafilm's auto exposure overrides the phone's own exposure (+2.8 EV on this low-key portrait).

## 2. Grain: amplitude, per-channel independence, pixel-scale texture, dependence on density, scaling with pixel size

- **spektrafilm:** Poisson-binomial grain in density, per channel × 3 sublayers, after the DIR couplers. The fields are independent per channel: output correlation R–G about 0.2, R–B about 0. Variance is Σ_l D_l·od_l·(1−u·p_l), so granularity does not depend on pixel size (Selwyn's law). Dye clouds have sigma 0.5–1.7 µm, below one pixel at drum and lab. The whole density image then gets a 0.65 px blur, so grain is about one pixel (output lag-1 autocorrelation 0.42). Density std at grey is 0.036/0.032/0.055 on drum and 0.014/0.012/0.022 on lab, roughly flat from −3 to +2 EV.
- **XA:** xaGrain uses three CIRandomGenerator fields blurred at 1.3/2.6/5.3 px on drum (clump sigma 5.9 µm). R and G share one noise (correlation 0.94), with chroma 0.06. Amplitude is rms·√d/(1+(d/0.7)²), which falls in highlights. An aperture factor 1.8·clamp(12/µm) breaks Selwyn's law. Measured on the simulator, density std at grey is 0.0096/0.0096/0.0089 on drum and 0.0058 on lab, with lag-1 0.87/0.96.
- **Full view:** At about 18–20 µm per display pixel (a 35 mm frame across a phone), grey-patch output std is about 6.5/4.3/7.2 levels R/G/B for spektrafilm vs about 3.9/3.5/3.1 for XA drum. Luma is similar (×1.2), but spektrafilm's grain is strongly coloured and 1.7–2.3× stronger in R and B. At +2 EV (27 µm aperture) it is 2.3/1.35/2.5 vs 0.9/0.8/1.0. Lab scans are about 2× XA at every aperture (grey, 6-px box: 1.72/1.15/1.92 vs 0.85/0.76/1.03). XA looks clean, monochrome and smooth; spektrafilm looks visibly grainy, with colour speckle even in highlights.
- **Zoomed:** Drum at 100–800%: spektrafilm per-pixel std is 16.2/10.8/18.0 levels with lag-1 0.42, i.e. single-pixel multicoloured speckle and no dye clouds at 4.5 µm. XA is 5.5/4.8/3.6 with lag-1 0.86 and autocorrelation 0.55 at 2 px: soft, 4–5 px monochrome blobs. The textures look nothing alike (panel_eye_zoom.png).
- **Port cost:** Low, and faster than now. One CIColorKernel draws a hash random number on destCoord + seed and turns it into 3 independent normals, scaled by a per-channel sigma(D) from spektrafilm's sublayer variance formula (baked per stock into stocks.json, e.g. 33 samples). Then spektrafilm's 0.65 px blur (5 taps) runs on the density image. This drops the 3 noise blurs (1.3–5.3 px) and replaces the 14.4 µm dye blur. Tile-safe.

## 3. Sharpness chain: dye blur, unsharp mask sized in µm, scatter kernel shape

- **spektrafilm:** The image is only softened by physics:
- in-emulsion scatter (core sigma about 2 µm plus an exponential tail of λ about 9.3 µm at 65–78% weight, energy-preserving);
- DIR adjacency;
- grain's 0.65 px blur;
- a scanner unsharp mask of 0.7 px sigma (in pixels), amount 0.7, in linear light.

On a −2 / +1.5 EV drum edge: 10–90% rise 12.4 µm, overshoot +8 levels within 2 px, and the dark side glows +11 levels at 5 px from scatter, with no dark ring. Bars keep 96/91/85 levels peak-to-peak at 28/37/56 cycles/mm, against 160 at 3.5 c/mm.
- **XA:** - Dye blur: G(14.4 µm) on the whole negative, 3.2 px on drum and 1.24 px on lab.
- Scatter: 0.705 + 0.295·G(13 µm).
- Couplers: a code-space unsharp, k 0.56 at 7.64 µm.
- CIUnsharpMask: radius 20.95 µm (4.66 px drum, 1.8 px lab), intensity 0.774, in linear light.

All of these were fitted at 24 µm/px, where they were smaller than a pixel.
- **Full view:** Black outlines. On drum the dark side of a high-contrast edge drops −38 levels (clipped to 0) at 5 px (22 µm) and −14 at 10 px; on lab it drops −37 at 2–3 px. At phone size that is 1–1.5 display pixels, so it shows as over-sharpened halos around leaves against sky, window frames and backlit hair. The bright side gets +9 at 6 px. Edge contrast at 5–10 c/mm is about 1.1 in both.
- **Zoomed:** Fine detail is destroyed. MTF of luminance at 20/30/40 c/mm is 0.63/0.28/0.08 vs spektrafilm 0.92/0.81/0.73. Bars at 28/37/56 c/mm keep 11.7/1.3/0.1 levels vs 96/91/85, and the 10–90% rise is 18 µm vs 12.4 µm. Drum scans look like a soft upscale with a black ring; spektrafilm stays crisp to the pixel.
- **Port cost:** Low:
- delete the dye blur;
- unsharp mask radius 0.7 px (in pixels, not µm), intensity 0.7;
- spektrafilm's scatter as a core plus a 3-Gaussian exponential-tail mixture (sigma 0.536/1.52/2.77 × λ = 1.1/3.2/5.8 px on drum), mixed per channel with colour matrices.

Net: fewer and smaller blurs than now. A linear estimate that keeps XA's current coupler unsharp puts bar contrast within about 0.1 of spektrafilm at 14–56 c/mm. Dropping only the dye blur without the new scatter kernel would over-sharpen (estimated 1.4× at 56 c/mm). Tune with spatial_cmp.py and decomp.py.

## 4. Grain noise repeats every 256 px

- **spektrafilm:** numpy random fields with no repetition: correlation at a 256 px shift is 0.000.
- **XA:** CIRandomGenerator has a 256 px period, and the three noise images a, b, c are offsets of the same tile, so the grain field is exactly periodic. On the simulator output, luma-noise correlation at +256 px is 0.999 in x and y (0.013 at +128).
- **Full view:** A faint lattice in flat areas. 256 px is 1.15 mm of film: about 38 display px on a drum frame and about 146 on a lab frame at phone width. Most visible in skies and walls on lab scans.
- **Zoomed:** Obvious when panning a zoomed drum scan: identical grain repeats about 31×21 times across the frame.
- **Port cost:** Trivial: a hash random number generator (e.g. PCG on integer destCoord + seed) in a CIColorKernel. Tile-safe and cheaper than CIRandomGenerator plus blurs. Comes free with gap 2.

## 5. Halation: strength, width, renormalisation, highlight boost

- **spektrafilm:** Per-stock preset by (use, antihalation):
- width: still sigma 65 µm, cine 50 µm;
- strength (R,G,B): strong (0.015, 0.005, 0) for Portra, Ektar and Vision3; weak (0.08, 0.02, 0) for Gold 200, C200 and X-tra 400.

Three bounces, each √k wider, weighted 0.571/0.286/0.143, taken from the scattered exposure and divided by (1+a). boost_ev is 0.
- **XA:** R 0.072, G 0.012 at 42.88 µm for every stock (× stock factor 0.9–1.5; Canal ×1.5). Three bounces taken from the pre-scatter scene, with no renormalisation. Clipped SDR highlights are boosted 1.5 EV (×2.83) as halo source.
- **Full view:** Night lights and specular highlights. A lamp at +6.5 EV (radius 90 µm) on a −4 EV background:
- XA paints a saturated red ring: R +150 levels at 27 µm from the rim, +92 at 45 µm, +50 at 68 µm, gone by 100 µm (R 168 / G 43 / B 3).
- spektrafilm shows a white scatter bloom out to about 45 µm, then a soft red glow of +19/+24 at 45/68 µm, +10 at 100 µm and +2 at 150 µm.

On mid grey, XA's red halo is about 5× spektrafilm's (+48 vs +10 at 45 µm). Flat areas get +3 red levels at grey because of the missing renormalisation. Canal 500T shows the same pattern (XA R +160 at 27 µm).
- **Zoomed:** A hard red fringe hugs every bright edge instead of a wide faint glow. Combined with the unsharp-mask black ring it reads as a coloured outline.
- **Port cost:** Low: spektrafilm's constants per stock class, sigma 65/50 µm, applied after scatter, divided by (1+a), boost 0. Same 3 blurs as now (14–25 px on drum; can run at half resolution). Tile-safe.

## 6. Glare veil on film and print

- **spektrafilm:** No film glare (film_render.glare is never read). Print glare is lognormal noise with mean 0.03% of the illuminant (3e-4 × the illuminant's XYZ), blurred 0.5 px, independent of the frame.
- **XA:** Film glare adds 3% of a frame-wide veil to exposure (a 64 px copy blurred sigma 9 px, about 14% of the long side). Print glare adds 1.2% of a veil of the proxy print.
- **Full view:** A 1000 px black square in a white field prints 29.6/31.9/32 levels in XA, against 13/14/17 with glare off and 13.5/14.4/17.4 in spektrafilm. Blacks in bright or backlit scenes turn milky grey (×3 in linear). A mid-grey field gains +2–2.7 levels. On the dark portrait it is only ΔE 0.6.
- **Zoomed:** The same lift, plus lower local contrast in shadows.
- **Port cost:** Trivial: film glare default 0, print glare 0.0003 (optionally as lognormal per-pixel noise). Removes the veil graph and part of the proxy develop.

## 7. Camera effects (lens, flash, leak, mist) that spektrafilm does not have

- **spektrafilm:** No lens effects (lens_blur_um 0, no vignetting), no flash model, no light leaks; diffusion filters off.
- **XA:** The default recipe has:
- lens 0.5: corner falloff to −27.5% light and soft corners blurred min(w,h)·0.002 (10.7 px on drum);
- light leak 0.3, which fires on about 43% of frames (probability 0.25 + 0.6·leak);
- a flash gradient plus shadow gamma when the flash fired;
- mist 0.
- **Full view:** Lens alone vs no camera effects: ΔE00 mean 1.8, p95 5.8 (corners). A frame with a leak differs massively. These are XA's camera character, not film fidelity.
- **Zoomed:** Soft corners blur detail and grain over the outer half of the frame radius on drum.
- **Port cost:** Trivial: set lens, flash, leak and mist to 0 in a spektrafilm-faithful recipe.

## 8. Wide-gamut (P3) colours clipped where the image enters the film table

- **spektrafilm:** Accepts linear input with negative values (P3 colours outside sRGB) and compresses them with its input gamut compression (Reinhard knee in xy) before spectral upsampling. No upper clip on exposure.
- **XA:** Code-in is CILinearToSRGBToneCurve then CIColorClamp to [0,1]. Every negative channel, i.e. every P3 colour outside sRGB, and all scene light above 2.83 × gain are hard-clipped before the 33³ film table.
- **Full view:** Saturated P3 colours, which iPhone photos contain:
- P3 green: ΔE00 6.4 at Y 0.18 and 10.1 at Y 0.45; hue 130° vs 142°.
- P3 red: ΔE 2.5/4.8 on Portra, 7.5/13.1 on 500T/2383.
- Bright saturated blue (B 6.2 linear): ΔE 11.7 (Portra) / 15.2 (500T).

spektrafilm given the same colours pre-clipped matches XA within about 1, so the clamp is the cause. Foliage, flowers, neon and LEDs lose hue and gradation.
- **Zoomed:** Flattened, posterised gradations inside saturated objects.
- **Port cost:** Low to medium:
- rebake the film table over an extended domain, e.g. a log2 shaper on linear sRGB [−0.25, 32], or linear Rec.2020/P3 input with spektrafilm's gamut compression;
- replace code-in with that shaper (one colour kernel);
- possibly a 49³ or 64³ table.

Same GPU cost per pixel. Also removes the +4 EV clip (gap 13).

## 9. Dye clouds when zoomed (spektrafilm's 12× crops)

- **spektrafilm:** At 4.5 µm its grain is per pixel: dye clouds (sigma 0.5–1.7 µm) are smaller than a pixel, and the blur is skipped below 0.17 px. The clouds only appear when spektrafilm renders a crop at fine pitch (the README's 12× crop at 0.49 µm/px):
- Poisson grain centres per sublayer;
- Gaussian clouds of sigma 1.1–3.4 px;
- fewer than 0.6 particles per pixel;
- lognormal micro-structure (0.2 µm, 30 nm), which switches on only below 0.6 µm/px.
- **XA:** Renders one drum frame at 4.5 µm/px. Its "clouds" are its own 5.9 µm clumps; zooming only magnifies pixels.
- **Full view:** None.
- **Zoomed:** Very high for the product goal. At 400–800%, spektrafilm-style rendering shows discrete dye clouds. XA shows enlarged blobs today, and after gap 2 would show enlarged pixel noise, as spektrafilm itself does at 4.5 µm.
- **Port cost:** Medium to high. A viewer "loupe" that re-develops only the visible crop at µm per px = 4.5/zoom (spektrafilm's own crop + upscale method). FilmLab already scales every kernel by µm; it needs an explicit µm/crop parameter. The loupe uses spektrafilm's sublayer grain:
- per channel × sublayer, Poisson/binomial counts from a hash random number generator;
- cloud blur b·√od px;
- micro-structure below 0.6 µm.

Exposure and lab settings come from the full frame's meter. Cost scales with the viewport (about 3–4 MP), not the frame: about 9 small blurs. Tile-safe.

## 10. DIR couplers, spatial part: log exposure, cross-channel, 20 µm + 200 µm

- **spektrafilm:** Inhibitor I = Mᵀ·blur(D before couplers), using the 3×3 negative matrix (cross-layer terms such as R→G 0.353, R→B 0.302, G→B 0.353). Blur is 0.94·G(20 µm) + 0.06·Exp(200 µm), then D = curve0(logE − I). This is the main source of spektrafilm's edge crispness at drum: without DIR, edge MTF at 20/40 c/mm falls from 0.92/0.73 to 0.57/0.41, and bars at 56 c/mm from 85 to 48 levels.
- **XA:** The non-spatial DIR effect is baked into the film table. The spatial part is a per-channel unsharp in normalised density code: c + 0.56(c − G(7.64 µm)c) + 0.089(c − G(193.6 µm)c). No cross-channel term, and no dependence on density or curve slope.
- **Full view:** Moderate. Long-range shoulders are similar: +1.8/−1.2 levels at 40 px vs spektrafilm's +1.3/−1.0. But spektrafilm's 20 µm adjacency gives crisper midtone detail and colour-dependent edge effects (a red edge changes the green and blue records), which XA lacks.
- **Zoomed:** Moderate: the edge profile and the coloured fringing at saturated edges differ. After gap 3, most of the remaining sharpness difference is here.
- **Port cost:** Medium:
- split the film table into rgb → log raw (3D table) plus per-channel 1D curves for curve and curve0 (CIColorCurves), rebaked in tools/filmsim with spektrafilm's 3lut/4lut taps;
- a CIColorMatrix for M;
- one 4.4 px blur at full resolution;
- the 200 µm exponential tail (sigma 24/68/123 px on drum) on a 1/8 copy inside the lazy graph.

Tile-safe.

## 11. Mean grey level and colour bias

- **spektrafilm:** 0.18 linear prints 116/116/116 deterministically and 113.7/115.0/114.3 with grain, because Poisson grain shifts the mean through the print curve. 0.184 prints 117.4.
- **XA:** calibrate_ev targets G 0.4614, which is spektrafilm's value for 0.184 grey, for a 0.18 card. Result: 119/118/117 without halation; the unrenormalised halation adds +3 R, giving 122/118/117.
- **Full view:** +6/+3/+2.4 levels vs spektrafilm's full simulation at mid grey: a slight warm, bright cast on every frame (ΔE about 2–3).
- **Zoomed:** Same.
- **Port cost:** Trivial: renormalise halation (gap 5), recalibrate the exposure to spektrafilm's 0.18 output, and let the matched grain amplitude (gap 2) bring the mean shift.

## 12. Grain differences between stocks

- **spektrafilm:** Grain parameters are global (particle area 0.2 µm² × scales); stocks differ only through their curves and print paper. Measured std at an 18 µm aperture at grey, R/G/B levels:
- Ektar 100: 6.35/4.34/7.61
- Portra 400: 6.53/4.25/7.16
- Portra 800: 6.48/4.34/7.38
- Gold 200: 6.05/4.02/6.61
- Vision3 500T: 7.37/4.77/7.35
- C200: 7.61/6.71/10.57
- X-tra 400: 9.25/7.55/10.99
- **XA:** Hand-set RMS per stock: chelsea100 0.006, bowery400 0.010, bowery800 0.015, coney200 0.013, prospect200 0.013, orchard400 0.015, canal500t 0.017, ludlow1600 0.023. That is 0.6× to 2.3× of Bowery.
- **Full view:** Chelsea (Ektar) is nearly grain-free in XA but at Portra level in spektrafilm. Bowery 800 is 1.5× Bowery 400 in XA but equal in spektrafilm. The Fuji consumer stocks are grainier in spektrafilm only because of their print paper.
- **Zoomed:** The same ratios at pixel level.
- **Port cost:** Trivial: per-stock factors derived from spektrafilm's variance curves. A product decision, because spektrafilm's equal Ektar/Portra grain comes from its global grain parameters, not from data.

## 13. Highlights above +4 EV

- **spektrafilm:** No input clip. The film curve runs to logE 4, and the paper keeps compressing toward paper white.
- **XA:** Scene light above 2.83 linear (+3.97 EV over grey) is clipped at code-in.
- **Full view:** Small. Portra on Endura stays within 1 level up to +8 EV, because paper white (218) is reached by +4 EV. On Vision3 500T/2383, spektrafilm reaches 225.6/221.4/210.7 against XA's 222/219/206.7 above +5 EV (−1 L*). HDR iPhone highlights lose a little separation.
- **Zoomed:** A flat highlight plateau; negligible.
- **Port cost:** Covered by the shaper in gap 8.

## 14. Viewfinder cube (FilmPreview) vs the saved develop

- **spektrafilm:** Its preview mode keeps the scatter and halation widths and turns off grain and DIR diffusion.
- **XA:** FilmPreview uses a 25³ table with no scatter, couplers, dye blur, sharpening, underexposure lift or glare. Halation is a single Gaussian added before exposure. Grain is applied multiplicatively on the print from a tiled 512² texture (×3.2 stretch, amplitude 2.3·3.2·clamp(12/µm)).
- **Full view:** Finder only; the saved photo uses the full develop. Once gaps 2 and 5 are ported, the finder's grain and halation will no longer match the saved photo.
- **Zoomed:** Not applicable.
- **Port cost:** Low: derive the finder grain from the new grain model (sigma(D) in density at finder pitch) and use spektrafilm's halation constants; keep the cube.

## 15. Push and pull processing

- **spektrafilm:** Ships measured push profiles kodak_portra_800_push1 and push2; there is no generic push model (density_curve_gamma 1).
- **XA:** Push = gamma 1 + 0.12·push on density, plus per-stock offsets, plus grain × (1 + 0.3·push), the same for every stock.
- **Full view:** Only on pushed rolls. The contrast and colour of Bowery 800 at +1/+2 likely differ from spektrafilm's measured push curves (not measured here).
- **Zoomed:** Grain scales with push differently.
- **Port cost:** Low: bake bowery800 push tables from the push1/push2 profiles.

## 16. Table precision and the deep-shadow floor

- **spektrafilm:** Exact per-pixel spectral simulation (the GUI uses 17³ tables).
- **XA:** 33³ trilinear film and print tables. At −5 EV the blue output is stuck at 17 with zero variance.
- **Full view:** Negligible: tables vs per-pixel ΔE00 0.10 (tools/filmsim README).
- **Zoomed:** Deep-shadow blue grain is missing (spektrafilm std 0.6 levels at −5 EV).
- **Port cost:** None needed.

## 17. Long edge of the frame (35 vs 36 mm)

- **spektrafilm:** film_format_mm 35 for the long edge.
- **XA:** 36 mm long side for 35 mm film.
- **Full view:** Negligible: 2.9% difference in µm per pixel.
- **Zoomed:** Negligible.
- **Port cost:** Trivial.
