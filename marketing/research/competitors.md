# XA competitive landscape: retro, film, digicam, camcorder and booth camera apps (iOS, US App Store, checked 14 Oct 2026)

Written for copywriters and the launch planner. Prices, ratings and chart positions come from live US App Store pages unless marked otherwise. Download and revenue numbers are Sensor Tower's public estimates for last month and are rough. I paraphrased the reviews rather than quoting them.

---

## 0. Read first: film resolution, and some facts in the brief that need fixing

**You said film photos are all low res. The code agrees, for the version that has shipped so far.**
- Until now, FILM saved a "Lab scan" by default. That is 3088 px on the long side: about 6.4 MP for a 35mm frame, and less for half frame and 110. It was also taken from a sensor frame capped at 12 MP. So the brief's claim that FILM "saves full resolution HEIC" was **not true of the default**.
- **A fix is being written in the working tree while I research. I did not make it.** It adds a `drum` scan as the new default and switches existing users to it once. It scans at about 5600 dpi (4.5 µm per pixel), capped at 48 MP, from the whole sensor:
  - 35mm: about 8000×5333, roughly 43 MP
  - half frame: about 5333×4000, roughly 21 MP
  - 110: about 3777×2888, roughly 11 MP
  - 120: capped at 48 MP
  - The Lock Screen camera stays at the 3088 px lab scan because of its memory limit.
  - Files: `/Users/giovannilupo/gi-os/XA/XA/Film/FilmRoll.swift`, `/Users/giovannilupo/gi-os/XA/XA/Camera/CameraModel.swift`, `/Users/giovannilupo/gi-os/XA/XA/Camera/Settings.swift`, `/Users/giovannilupo/gi-os/XA/XA/Film/Stack.swift`.
- **What this means for copy:**
  - Don't claim a FILM resolution until the drum scan ships and has been checked on a real device.
  - On iPhones without a 48 MP sensor, a drum scan is bigger than what the sensor took: it is scaled up, with grain drawn at scan size. One reviewer criticised Analogue for exactly this (an 8 MP capture scaled up to a 33 MP file).
  - So say "scanned like a drum scan, up to 48 MP". Don't say "48 MP of detail".

**Other fact fixes:**
- **Date backs:** `DateBack.swift` has **8** styles. The eighth is "digicam", a 2005 pocket-digicam style in red pixels. The brief and `description.txt` say seven.
- **Video tapes:** there are 12 in shelf order: CLEAN, POCKET, POCKET COLOR, POCKET 3D, SUPER 8, VHS, TRAILS, MOTION, STOP MOTION, CCTV, SLIT-SCAN, DATAMOSH. "Camcorder / home movie / security camera" in the listing are descriptions of VHS, SUPER 8 and CCTV. That's fine, as long as nobody treats them as tape names.
- **FILM stocks (11):** Bowery 400 and 800, Coney 200, Chelsea 100, Prospect 200, Canal 500T, Orchard 400, Ludlow 1600, Bleecker 400, Delancey 3200, Essex P3200. All the names are made up, which is the safe choice.
- **Sims:** Nocturne 800T, Visage 800, Prima X 400, Amethyst 400, Sunday 600, Onyx 3200, plus Neutral.
- **Stale README:** `marketing_url.txt` points to the GitHub README, and the README still says "Two cameras" (DIGI and PRO only). Update it, or point the marketing URL at the docs site.

---

## 1. The market at a glance

### Film and disposable (the core category)
| App | Rating (count) | US chart | Est. DL / revenue per month | Price model | Ads | App Privacy label |
|---|---|---|---|---|---|---|
| **Dazz Cam – Vintage Camera** (DAZZ PTE) | 4.8 (116K) | #15 Photo & Video | ~2M DL / ~$800K (worldwide) | Dazz Pro $6.99/yr, $19.99 one-time; single cameras and accessories $0.99–2.99 | none seen | Data Not Linked (usage, diagnostics) |
| **NOMO CAM** (Beijing Lingguang) | 4.7 (48K) | not ranked | ~50K / ~$30K | NOMO PRO $24.99/yr; single cameras $0.99–1.99 | none seen | Contact Info linked to you |
| **1998 Cam** (AAAI Studio) | 4.8 (40K) | #225 | ~90K / ~$8K | $1.99–5.99/mo, $15.99–29.99/yr, $39.99 lifetime | Yes, plus review prompts | **Tracks** identifiers |
| **Huji Cam** (Manhole) | 4.2 (12K) | #131 | ~80K / <$5K | $0.99 "Extra Options" | Banner ads | **Tracks** location, identifiers, usage, diagnostics |
| **OldRoll** | 4.7 (5.6K) | #139 | ~200K / ~$90K | $4.49–4.99/mo, $12.99–19.99/yr, $17.99–19.99 lifetime | none seen | **Tracks** identifiers |
| **Hipstamatic** | 4.6 (2.8K), Editors' Choice | not ranked | <5K / <$5K | Camera Club $7.99/mo, $19.99 multi-month, $29.99/yr; needs a Hipstaccount | None ("No ads. No tracking.") | Data Not Linked (location, contact info, user content, identifiers) |
| **FIMO** | 4.0 (258) | — | — | Pro $29.99/yr; films $0.99–1.99; Pro removes the **watermark and ads** | Yes | — |
| **Kuji Cam** | 4.6 (121) | — | — | $0.99/mo, $6.49/yr, $15.99 lifetime | — | Last updated Oct 2021 (abandoned) |
| **RetroCam** (BrainCake) | 4.7 (14K) | — | — | $19.99/yr after a 3-day trial | — | Last updated Feb 2022 |
| **KD Pro Disposable** (GinnyPix) | was 4.5 (~434) | — | — | was a $0.99 premium | — | **US and JP store pages return 404 today; looks delisted** |

### Digicam, CCD and Y2K (the fastest-moving segment)
| App | Rating | Chart | Price model | Notes |
|---|---|---|---|---|
| **ProCCD** | 4.7 (2.2K) | #247 | $2.99/wk, $5.99–8.99/yr, $13.99–17.99 lifetime, cameras $0.99 | ~200K DL / ~$50K. 40+ film, digicam and VHS cameras, plus a "Photobooth". Third-party ads. **Tracks** identifiers |
| **Retrica** | 4.7 (34K) | — | Premium $5.99/wk, $12.99/mo, $59.99/yr; Plus $29.99/yr; "No More Ads" $49.99 | **Tracks** identifiers |
| **LoFi Cam** | 4.7 (1.5K) | — | PRO $1.99–6.99/yr, $14.99–19.99 lifetime | Data Not Linked |
| **Kapi Cam – Y2K & CCD** | 4.7 (1.7K) | #186 | **$4.99/wk, $69.99–89.99/yr, $149 lifetime** | The most expensive app in the category |
| **flag7x: g7x style camera** | 4.6 (188) | — | $4.99, $19.99, $24.99 lifetime; **the purchase removes the watermark** | Rides the Canon G7X trend; there are clones (Lumo, Flash7x) |

### Video, VHS and camcorder
| App | Rating | Price model | Notes |
|---|---|---|---|
| **Rarevision VHS: Retro Cam** | 4.7 (6.7K) | **$5.99 upfront** | #3 in Photo & Video (paid). Used by celebrities. Users want editing after recording |
| **VHS Cam – Retro Camcorder FX** (Ringtones LLC) | 4.4 (11K) | $19.99/yr "Pro + Remove Ads"; $2.99 unlocks | Last updated Feb 2023 |
| **Dazz Cam – Old Film & VHS** (Yili, a name-alike) | 3.9 (204) | $2.99/wk, $4.99/mo, $19.99/yr, $49.99 lifetime | Reviewers say none of the filters are free |
| Dazz Cam main app | — | — | Has 8mm, 16mm, VHS and DCR video, but behind Dazz Pro |

### Photo booth and purikura
- **Korean four-cut strip apps:** FourCut ($2.99 Pro, too few ratings to show), MY4CUT, FramePic.
- **Povie Booth:** a Japanese kawaii *video* booth, released 29 Apr 2026, no ratings yet, beauty effects sold as in-app purchases.
- **Older sticker apps:** Photo Sticker, Qtiie.
- **Booth modes inside camera apps:** ProCCD ("Photobooth"), OldRoll ("Booth"), 1998 Cam (a photo strip).
- I found **no app** that offers a full purikura booth (big eyes, skin, a sticker sheet) free inside a full camera.

### Social disposable apps
| App | Rating | Model | Notes |
|---|---|---|---|
| **Dispo** | 4.3 (8.2K) | Max $1.99–9.99/mo, $19.99–**59.99**/yr; filters $0.99 | ~10K DL / ~$30K. Full-screen ads. **Tracks** identifiers; links contacts, contact info and purchases. Added AI "DreamCams" |
| **Lapse** | 4.8 (118K) | Free, no in-app purchases listed, invite-gated | Was #1 overall in Oct 2023; #99 in Photo & Video by Mar 2025. Saved photos get a watermark |

### New entrants, 2025–2026
| App | Launched | Model | Why it matters |
|---|---|---|---|
| **101cam** (SNOW Corp, the maker of B612 and SNOW) | Jul 2026 | 101 PRO $13.99/yr with a 7-day trial; in-app purchases only, no ads | Already **#61 Photo & Video, 4.8 (331)**. Big-company money and distribution. **Tracks** identifiers. **No video** (users complain). Just added format, resolution and timer settings, so they are hearing the same resolution demand |
| **Kiosk 27** (indie, Marko Zamurovic) | Mar 2026 | $9.99 paid ($12.99 at launch), no in-app purchases | Leads with **"12 MP" sensor-RAW**, shoots a negative then prints a positive, 27-shot roll, contact sheet, widget. 9to5Mac noted no Camera Control support |
| **Analogue** | 2025 | $3.99/mo, $19.99/yr, $34.99 lifetime | Log capture. A reviewer noted it **upscales 8 MP to 33 MP** |
| **mood.camera** | 2024 | $1.99/mo or $14.99 once; free tier is "random" mode only | Indie, buy-once |
| Better Camera: No AI, GrainyCam | 2026 | One-time purchases | A small "no subscription" indie trend |

**Overall:** the category is free to download and sells VIP cameras: yearly plans run $6.99 to $89.99, weekly plans $2.99 to $5.99. Some indies push back with pay-once pricing ($6–15). **Nobody is free with everything included.**

---

## 2. App-by-app notes

**Dazz Cam (the leader).**
- **Positioning:** pro photographer in your pocket; real sampled film stock; no editing needed.
- **Formats:** 135, 120, half frame, instant, 3D, disposable, CCD, plus 8mm, 16mm, VHS and DCR video.
- **What users love:** steady updates (it adopted Liquid Glass), very authentic date formats, a free tier people used happily for years.
- **What users complain about:**
  - Most good cameras are VIP (~30% of review complaints per Clarity).
  - A confusing camera picker with tiny buttons (~15%).
  - Paid lifetime or subscription access breaking (~10%).
  - Exports get the export time instead of the capture time, which scrambles albums.
  - No account or backup, so photos are lost when switching phones.
  - Black lines or noise in high-quality modes on new hardware.
  - No iPad version; the date's year can't be changed.
- **Lock Screen:** a reviewer remapped their Lock Screen camera to Dazz, so it supports it.
- **Clones:** at least two name-alikes (ids 1500395485, 1502071279) sell weekly plans on the Dazz name.
- **Screenshots:** no device frames. One captioned hero ("Analog Vintage Cameras / Photos and Videos") over a grid of camera icons on a red gradient. The rest are full-bleed sample photos (instant-print collages on black, young fashion subjects), each with a small camera icon and name, and a photographer credit.

**NOMO CAM.**
- **Positioning:** a minimal point-and-shoot that adds random analog presets to each shot.
- **What users love:** simplicity; it got people into photography.
- **What users complain about:** they pay $24.99 a year but no new cameras have arrived in a long time. Store sources disagree on whether the last update was April 2025 or 2026.
- **Screenshots:** a full-bleed skeuomorphic camera body per screenshot (black, silver, a box camera, a red Lunar New Year edition). No captions, no frames.

**1998 Cam.**
- **Positioning:** 100+ filters, a powerful editor, "no watermark", output sold as "Full HD" (about 2 MP).
- **What users love:** no watermark; a generous free tier.
- **What users complain about:** ads and review prompts on almost every swipe in and out of the editor. The developer replied that they cut the ad frequency.
- **Screenshots:** raw editor UI; one serif caption panel for the photo strip.

**Huji Cam.**
- **Positioning:** "Just Like The Year 1998", one tap.
- **What users love:** the look, the orange date, works offline.
- **What users complain about:**
  - Photos kept inside the app were **lost when switching phones**.
  - You **can't date-stamp without the Huji filter** (one reviewer's northern-lights photos were ruined by it).
  - The viewfinder isn't full screen.
  - Small banner ads.
  - Last updated Dec 2024.
- **Privacy:** tracks location.
- **Screenshots:** dated raw UI, no captions.

**OldRoll.**
- **Positioning:** recreates specific cameras; sells a lifetime price that reviewers call fair.
- **What users love:** a reviewer said it doesn't degrade photo quality the way many rival apps do; the widget.
- **What users complain about:** the paywall, mostly from younger users.
- **New:** Camera Control launch, a Booth filter, Color Match.
- **Screenshots:** bold white sans-serif captions on black ("Awesome Analog Filter", "Digital Camera", "Film Editor", "Vintage Film Effect"), phone and camera-body mockups, model photos.

**Hipstamatic.**
- **Positioning:** the 2009 original. Tagline: "Shoot first. Edit never." 200+ lenses and films, an opt-in chronological community, member-funded, **"No ads. No tracking. No algorithm."** Needs an account. Supports Camera Control.
- **What users complain about:** people who bought the app and every film pack outright are now asked to subscribe. The UI is called messy, and TapSmart calls the app sluggish.
- **Screenshots:** the loudest in the category. Condensed all-caps captions on solid yellow, navy and red-orange, award laurels, phones in device frames.

**ProCCD.**
- **Positioning:** 40+ digicams, camcorders and film cameras, plus collage and stickers.
- **What users love:** fair pricing.
- **Downsides:** carries ads; tracks.
- **Screenshots:** small typewriter-style captions inside corner brackets on black ("Digital Film Camera", "2000S Aesthetics", "Photobooth", "Instant Camera"), rendered digicam bodies, model photos.

**Retrica.**
- **Positioning:** 388 presets.
- **What users complain about:** they paid once to remove ads and now have to pay again; crashes after subscribing; **photo resolution doesn't match the camera's**; repeated price rises.

**Dispo.**
- **Positioning:** photos develop at 9am.
- **What users complain about:** full-screen ads every few seconds; paywalls up to $60 a year, some even to view your own photos; a vacation's photos lost after a crash.

**Lapse.**
- **Positioning:** friends, not followers.
- **What users complain about:** an **ugly watermark on saved photos** (bad for prints); slow processing; a Dec 2025 redesign that moved away from friends-only; account recovery tied to a phone number.

**FIMO.** Watermark and ads unless you pay $29.99 a year. Reviewers say it went downhill after moving to a subscription and that the lifetime price is far above rivals'.

**Legacy and abandoned apps:**
- Kuji: paying users report failed saves and exports, and crashes.
- RetroCam: a trial that was hard to cancel; filters with codes like "B21" for names.
- KD Pro: premium asked for twice; ads after paying; photos lost when the app was deleted; now delisted.
- Gudak: the original 72-hour-wait app.

**Digicam apps:**
- LoFi Cam: users want a one-time purchase and the ability to hide cameras or make their own collections; the date stops appearing after a few videos.
- Kapi Cam: lag, "camera quality is bad", too many locked cameras.
- flag7x: you pay to remove the watermark; support is hard to reach.

**VHS apps:**
- Rarevision is the authentic-looking paid leader. Users want editing after recording and playback control for imported clips.
- VHS Cam (Ringtones LLC): an ad after every save, a watermark removed by leaving a rating, **exports measured at 352×288 px**, crashes.

---

## 3. Complaint themes across the category (evidence, then XA's answer)

| Theme | Evidence | XA's answer |
|---|---|---|
| Good cameras locked behind VIP | Dazz (~30% of complaints), OldRoll, Kapi, Dazz clones, 1998 Cam | Everything included |
| **Paid once, asked to pay again** | Hipstamatic, Retrica, KD Pro, Dazz lifetime users, FIMO | No subscription; tips unlock nothing; GPLv3 source |
| Weekly plans and trial traps | Dazz clones $2.99–4.99/wk, Retrica $5.99/wk, Kapi $4.99/wk, RetroCam cancellation | None |
| Ads and review-prompt spam | 1998 Cam, Dispo, VHS Cam, Huji banners, Retrica, FIMO, ProCCD | No ads |
| Watermarks | FIMO, flag7x, Lapse, VHS Cam | No watermark (I found no watermark code in XA) |
| **Low resolution or degraded quality** | VHS Cam 352×288, 1998 Cam "Full HD", Analogue upscaling, Retrica mismatch, an OldRoll reviewer saying rivals degrade, Kapi | PRO saves the sensor's largest photo now; FILM drum scan once it ships; DIGI's 1–5 MP is a deliberate choice |
| **Lost photos** | Huji, Dispo, KD Pro, Dazz (no backup) | Saves to Photos in an XA album, so iCloud Photos backs it up |
| Abandoned apps | NOMO, Huji, Kuji, RetroCam, VHS Cam, KD Pro (delisted) | Open source; the roadmap is public |
| Rigid, coupled looks | Huji (date tied to filter), Dazz (date year fixed), RetroCam (code names), LoFi (no custom collections) | Sims, looks, shapes and date backs are separate layers; everything editable; save your own |
| Tracking labels | Huji (location), 1998 Cam, OldRoll, ProCCD, Retrica, Dispo, 101cam (identifiers) | Should be "Data Not Collected" |
| Missing modes | 101cam has no video; most film apps have no manual mode | Five cameras, including VIDEO and PRO |

---

## 4. Screenshot styles and what to do with XA's 10

**The three styles in use:**
- **Raw UI, no captions:** Huji, NOMO, mostly 1998 Cam, Rarevision (landscape camcorder screen). Reads as dated or confusing.
- **Lifestyle sample photos with small labels:** Dazz, OldRoll, ProCCD, 101cam. Young fashion models on black are the category default.
- **Poster style:** Hipstamatic. Bold condensed all-caps captions on solid saturated colors, device frames, award laurels.

**Common traits:**
- Black backgrounds dominate, with red or orange accents.
- Device frames are rare.
- Captions are short nouns ("Photobooth", "Film Editor").
- **No competitor uses screenshots to talk about price, ads, privacy or resolution**, because they all paywall. That space is open.

**Suggestions for XA's ids:**
1. Make the first three a spread across cameras, so a search result reads as "five cameras": **digi → film → video**.
2. Then: booth → sims → pro → dates → shapes → lock → roll.
3. Show the real viewfinder, not model photos. XA's selling point is that the viewfinder shows the finished photo, and real UI stands apart from the lifestyle-model norm.
4. Use one caption style throughout, in XA's plain voice. Examples:
   - digi: "A 2003 digicam. 1 to 5 megapixels, on purpose."
   - film: "Load a roll. Time the print."
   - video: "Twelve tapes, from VHS to datamosh."
   - booth: "Four shots. One sticker sheet."
   - pro: "The whole sensor, when you want it."
   - lock: "Shoot from the Lock Screen or Camera Control."
   - roll: "Saved to Photos. Nothing locked in the app."
5. Put the business model on screenshot 1 or a closing panel: "Every feature included. No subscription, no ads, no account."

**Review risk:** App Review guideline 2.3.7 bans pricing information in the name, subtitle and keywords. Keep "free" out of those three. "No subscription / no ads" is fine in the description and promotional text. In screenshots it is a gray area: phrase it as "every feature included" and be ready for pushback.

---

## 5. The 8 clearest gaps XA can win

1. **Nothing locked, nothing stamped.**
   - Every rival paywalls cameras, and several also watermark (FIMO, flag7x, Lapse, VHS Cam). Prices reach $89.99 a year or $149 lifetime (Kapi).
   - XA: free, every camera, sim, look, shape, date back and tape included, no watermark. The tip jar unlocks nothing.
   - **Caveat:** the tips make the listing say "In-App Purchases", the same badge every paywalled rival shows. Say in the description's first line that tips unlock nothing.

2. **No ads, no account, no tracking.**
   - Huji tracks location. 1998 Cam, OldRoll, ProCCD, Retrica, Dispo and 101cam track identifiers. Hipstamatic says "no tracking" but needs an account and collects data.
   - XA: no account, no server, no analytics. Set App Privacy to "**Data Not Collected**" in App Store Connect, because that label is visible proof.

3. **Real resolution where it matters, and low resolution only as a choice.**
   - Low-res exports are a standing complaint (352×288, "Full HD", upscaling). Kiosk 27 now sells "12 MP" as its headline.
   - XA: PRO saves the biggest photo the sensor makes as HEIF or JPEG. DIGI's 1/2/3/5 MP is the costume, not a limit. FILM's drum scan (up to ~43 MP at 35mm, 48 MP cap) beats Kiosk 27, **once it ships and is verified** (section 0).

4. **Your photos live in Photos, not trapped in the app.**
   - Users of Huji, Dispo and KD Pro lost whole rolls when they switched phones, deleted the app or hit a crash.
   - XA saves every shot to Photos in an XA album; the roll is just a view of that album.

5. **Video tapes included, not sold separately.**
   - The VHS segment is paid upfront (Rarevision $5.99), full of ads and tiny exports (VHS Cam), or behind Pro (Dazz). 101cam has no video at all.
   - XA: 12 tapes free, including tapes nobody else bundles: slit-scan, datamosh, stop motion, Pocket 3D.

6. **One app instead of four.**
   - Today you need a film app, a CCD app, a VHS app and a four-cut booth app.
   - XA: DIGI, FILM, PRO, VIDEO and BOOTH in one app. BOOTH is a real purikura (four shots, big eyes, a sticker sheet), not just a strip template. ProCCD, OldRoll and 1998 Cam only have strip or booth filters.

7. **Built for the iPhone's buttons, plus a real manual camera.**
   - Gadget Hacks lists only Hipstamatic and OldRoll among retro apps that support Camera Control (Dazz supports the Lock Screen; Kiosk 27 has none).
   - XA: Lock Screen camera, Control Center control, Camera Control as the launch button that **slides through sims and looks**, volume buttons shoot, QR codes open from the viewfinder.
   - PRO adds a live histogram and WB, EV, shutter, ISO and focus dials with shutter and ISO priority. No retro rival has that.

8. **Film science you can open up, from an app that can't pull a bait-and-switch.**
   - Rivals use random presets (NOMO), lock the date to the filter (Huji), fix the date year (Dazz) or name looks with codes (RetroCam). Several moved paid users onto subscriptions (Hipstamatic, Retrica, FIMO).
   - XA: physically modelled grain and halation (spektrafilm-derived), 110, half, 35mm and 120 formats, lab printing and timing, fully editable sims you can save, and date backs that work independently of looks (8 styles).
   - GPLv3 open source makes "free, no subscription" credible long-term.

---

## 6. Threats and claims to avoid

- **Booth, Lock Screen and Camera Control are not unique.** Win on depth (sliding through sims and looks, a full purikura) and on everything being free. Don't claim to be "the only" app.
- **Hipstamatic already says "No ads. No tracking."** XA's difference is free, no account, and the Data Not Collected label.
- **101cam (SNOW) is the fastest riser:** #61 in about 3 months, with a corporate budget, and it is adding resolution settings.
- **Dazz owns the category** (~2M downloads a month) and updates constantly. Compete on the business model. Don't name competitors in metadata (guideline 2.3.7).
- **The name "XA":** it is also the Olympus XA camera model, and XA's finder references it. Rivals avoid real brands (Huji even carries a Fujifilm disclaimer). Low-priority IP check.

---

## 7. App Store search keywords (ASO)

- Rival titles and subtitles cluster around: Vintage Camera, Film Camera, Disposable, Retro, Digicam, CCD, Y2K, VHS, Photo Booth.
- `keywords.txt` (99 characters) repeats "film" and "digicam", which are already in the subtitle and so already indexed. Swap them for **vhs, ccd, y2k**:
  `retro,vintage,vhs,ccd,y2k,grain,date stamp,point and shoot,disposable,camcorder,photo booth,analog` (98 characters).
- Consider dropping "point and shoot" for "half frame,8mm" or "purikura".
- `privacy.html` doesn't mention tips. Add a line saying Apple processes the purchases and XA receives no personal data.

---

## Sources
- Dazz Cam: https://apps.apple.com/us/app/dazz-cam-vintage-camera/id1422471180 · https://app.sensortower.com/api/ios/apps/1422471180?country=US · https://www.onclarity.com/leaderboard/insight/dazzapp
- Dazz name-alikes: https://apps.apple.com/us/app/-/id1500395485 · https://apps.apple.com/us/app/-/id1502071279 · https://apps.apple.com/app/id1600636838
- NOMO CAM: https://apps.apple.com/us/app/nomo-cam-point-and-shoot/id1362548649 · https://app.sensortower.com/api/ios/apps/1362548649?country=US
- 1998 Cam: https://apps.apple.com/us/app/1998-cam-vintage-camera/id1450480287 · https://app.sensortower.com/api/ios/apps/1450480287?country=US
- Huji Cam: https://apps.apple.com/us/app/huji-cam/id781383622 · https://app.sensortower.com/api/ios/apps/781383622?country=US
- OldRoll: https://apps.apple.com/us/app/oldroll-vintage-film-camera/id1570093460 · https://app.sensortower.com/api/ios/apps/1570093460?country=US
- Hipstamatic: https://apps.apple.com/us/app/hipstamatic-r/id1450672436 · https://app.sensortower.com/api/ios/apps/1450672436?country=US
- ProCCD: https://apps.apple.com/us/app/-/id1616113199 · https://app.sensortower.com/api/ios/apps/1616113199?country=US
- Retrica: https://apps.apple.com/us/app/retrica-digicam-filter-camera/id577423493 · https://app.sensortower.com/api/ios/apps/577423493?country=US
- Dispo: https://apps.apple.com/us/app/dispo-live-in-the-moment/id1491684197 · https://app.sensortower.com/api/ios/apps/1491684197?country=US
- Lapse: https://apps.apple.com/us/app/lapse-disposable-camera/id1636699256 · https://www.onlineoptimism.com/blog/lapse-app-stats/ · https://en.wikipedia.org/wiki/Lapse_(social_network)
- FIMO: https://apps.apple.com/us/app/-/id1454219307
- Kuji Cam: https://apps.apple.com/us/app/id1468247478
- RetroCam: https://apps.apple.com/us/app/retrocam-vintage-film-camera/id298796414
- KD Pro (now 404): https://apps.apple.com/us/app/kd-pro-disposable-camera/id1291297394 · https://justuseapp.com/en/app/1291297394/kd-pro-disposable-camera/reviews
- Gudak: https://www.digitalcameraworld.com/news/this-app-makes-you-wait-three-days-for-pictures-to-develop
- LoFi Cam: https://apps.apple.com/us/app/-/id1604592450
- Kapi Cam: https://apps.apple.com/us/app/id6740760807
- flag7x: https://apps.apple.com/us/app/-/id6747452095
- 101cam: https://apps.apple.com/us/app/101cam-film-digital-camera/id6781998623 · https://appgoblin.info/apps/6781998623 · https://en.edaily.co.kr/news/eda202608055514/
- Kiosk 27: https://apps.apple.com/us/app/kiosk-27/id6759038503 · https://9to5mac.com/2026/03/14/indie-app-spotlight-kiosk-27-film-camera-app-for-iphone/
- Analogue: https://apps.apple.com/us/app/analogue-film-camera/id6748702405
- mood.camera: https://petapixel.com/2024/04/22/mood-camera-is-a-film-like-iphone-app-with-point-and-shoot-style
- Rarevision VHS: https://apps.apple.com/us/app/rarevision-vhs-retro-cam/id679454835
- VHS Cam (Ringtones LLC): https://apps.apple.com/us/app/vhs-cam-retro-camcorder-fx/id1091555594
- Booth apps: https://apps.apple.com/app/id6761323909 · https://apps.apple.com/sg/app/my4cut/id6504497435 · https://mwm.ai/apps/povie-booth/6763999258 · https://apps.apple.com/app/id306938028
- Camera Control support list: https://ios.gadgethacks.com/how-to/always-updated-list-apps-support-camera-control-button-iphone-16-series-models-0385633/
- 2026 roundups: https://theappwhisperer.com/2026/05/best-film-camera-apps-for-iphone-and-android-in-2026/ · https://www.tapsmart.com/apps/photo-video/best-camera-apps/
