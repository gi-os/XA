# XA: App Store rules for the first submission (checklist with citations)

Compiled 14 October 2026 for copywriters and the launch planner. I read these directly on that date:

- App Review Guidelines, page marked "Last Updated: June 8, 2026"
- App Store Connect Help: screenshot specifications, app preview specifications, In-App Purchase pages, age ratings, platform version information, EU DSA
- Apple's product page, asset best practices and marketing guidelines
- App Privacy Details
- HIG > Privacy

Repo facts come from the files in `/Users/giovannilupo/gi-os/XA`. Where a source does not settle a point, I say so.

---

## 0. Fix these before submitting

| # | Item | Why | Rule |
|---|---|---|---|
| B1 | **The tip jar is not in the code yet.** There is no StoreKit or tip code in `XA/`. Either the tip jar ships in the 1.0 build, with its In-App Purchases (IAPs) submitted alongside that version, or no copy, screenshot or review note mentions tips. | Apple rejects IAPs it cannot find or test, and metadata must match the build. | [2.1(b)](https://developer.apple.com/app-store/review/guidelines/#2.1), [2.3.1](https://developer.apple.com/app-store/review/guidelines/#2.3.1), [first IAP needs an app version](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase) |
| B2 | **No privacy policy link and no contact inside the app.** No Swift file links to `privacy.html`, the support page or an email. Add an About row in Customize with Privacy policy, Support/contact, Source code and Licenses. | "All apps must include a link to their privacy policy… and within the app in an easily accessible manner." 1.5 also asks that the app itself offer a way to contact you. | [5.1.1(i)](https://developer.apple.com/app-store/review/guidelines/#5.1.1), [1.5](https://developer.apple.com/app-store/review/guidelines/#1.5) |
| B3 | **"Olympus" appears in the app.** `/Users/giovannilupo/gi-os/XA/XA/UI/CustomizeView.swift:130` says "Look through an Olympus XA's finder…". Remove the brand name and describe the finder generically. | A third-party trademark used without permission. | [5.2.1](https://developer.apple.com/app-store/review/guidelines/#5.2.1) |
| B4 | **FILM resolution copy must match the build that is submitted.** The user asked for higher-resolution FILM photos, and the working tree has uncommitted edits to `FilmRoll.swift`, `Settings.swift`, `CameraModel.swift` and others. They add a "Drum scan" default (up to 48 MP on 48 MP iPhones); the lab scan is 3088 px on the long side. The Lock Screen camera always saves a lab scan and caps capture at 12 MP. | Do not write "full resolution" for FILM unless the drum-scan change is in the submitted binary. Even then, the Lock Screen camera is an exception. | [2.3.1](https://developer.apple.com/app-store/review/guidelines/#2.3.1), [2.3](https://developer.apple.com/app-store/review/guidelines/#2.3) |
| B5 | **No screenshots exist yet.** There is no `fastlane/screenshots/en-US`, and the release lane refuses to submit without it. Capture on a real iPhone; the simulator has no camera. | At least one screenshot per required size is mandatory. | [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) |
| B6 | **Age rating:** answer the post-2025 questionnaire. Expected result: **4+**. | Required. | [2.3.6](https://developer.apple.com/app-store/review/guidelines/#2.3.6), [age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions) |
| B7 | **App Privacy label:** "Data Not Collected". This stays true with StoreKit tips. | Required. | [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) |
| B8 | **EU DSA trader status.** With IAP revenue you are likely a trader, so a public address or P.O. box, phone and email appear on EU product pages. | Required to declare at first submission. | [DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements) |
| B9 | **Paid Apps Agreement, banking and tax must be complete** before any tip IAP can be sold, even though the app is free. | Admin. | App Store Connect > Business |
| B10 | **Copy fixes in the current draft:** DIGI offers 1/2/3/5/8/12 MP (`Settings.swift:25`), but the description says "1, 2, 3 or 5". "On iPhone 16 and later" is wrong for iPhone 16e, which has no Camera Control button. Write "on iPhone with Camera Control". | Accuracy. | [2.3.1](https://developer.apple.com/app-store/review/guidelines/#2.3.1) |

---

## 1. Accurate metadata (guideline 2.3)

### 1.1 What each rule means for XA

| Rule | What it says (paraphrased, with short quotes) | What to do for XA |
|---|---|---|
| [2.3](https://developer.apple.com/app-store/review/guidelines/#2.3) | Metadata (privacy info, description, screenshots, previews) must "accurately reflect the app's core experience" and be kept up to date. | Every number in the copy must match the binary: 5 modes, 12 tapes, 9 looks, 5 shapes plus 4 instant prints, 7 date backs. The code actually has 8 date backs; the 8th is "digicam". Listing fewer is fine. |
| [2.3.1(a)](https://developer.apple.com/app-store/review/guidelines/#2.3.1) | No hidden or undocumented features. Explain features "with specificity" in Review Notes. Promoting things the app does not do, or "a false price", can get the app removed. | Review notes should list the non-obvious gestures: pull down for the roll, long-press a sim to edit, swipe a film box to push/pull. Add the tip jar location if it ships. |
| [2.3.2](https://developer.apple.com/app-store/review/guidelines/#2.3.2) | If there are IAPs, the description, screenshots and previews must make clear whether featured items need extra purchases. | Add one line to the description, for example: "Every feature is included. Optional tips in the app support development and unlock nothing." |
| [2.3.3](https://developer.apple.com/app-store/review/guidelines/#2.3.3) | Screenshots "should show the app in use", not title art, a login page or a splash screen. They "may also include text and image overlays (e.g. to demonstrate input mechanisms…)". | All 10 concepts are real UI, which is fine. Captions are allowed. An overlay showing a physical button press is explicitly allowed. |
| [2.3.4](https://developer.apple.com/app-store/review/guidelines/#2.3.4) | Previews "may only use video screen captures of the app itself". Narration and video or text overlays are allowed. | No footage of a hand holding a phone and no live-action b-roll. Screen-record the viewfinder, the roll and the Lock Screen camera flow. |
| [2.3.5](https://developer.apple.com/app-store/review/guidelines/#2.3.5) | Pick the right category. | Photo & Video, as already set in `fastlane/metadata/primary_category.txt`. |
| [2.3.6](https://developer.apple.com/app-store/review/guidelines/#2.3.6) | Answer age rating questions honestly. | See section 6. |
| [2.3.7](https://developer.apple.com/app-store/review/guidelines/#2.3.7) | Unique name, at most 30 characters. Keywords must describe the app. Don't pack metadata "with trademarked terms, popular app names, pricing information, or other irrelevant phrases". "Metadata such as app names, subtitles, screenshots, and previews should not include prices, terms…" Subtitles must not "reference other apps, or make unverifiable product claims." | **No "Free", "No subscription", "$0" or "forever free" in the name, subtitle, screenshots or previews.** These are fine in the description and promotional text. No competitor names anywhere (Dazz, Huji, NOMO, 1998 Cam, Hipstamatic, KD). No film brands. See the list in 1.3. |
| [2.3.8](https://developer.apple.com/app-store/review/guidelines/#2.3.8) | Icons, screenshots and previews must suit a 4+ rating even if the app is rated higher. "For Kids"/"For Children" is reserved for the Kids category. Name and icons should be consistent. | BOOTH sheets and sample photos must be 4+. Don't use "for kids". The store icon is the primary dot-matrix "XA" icon, which is fine. |
| [2.3.9](https://developer.apple.com/app-store/review/guidelines/#2.3.9) | You must hold the rights to everything in icons, screenshots and previews. Use fictional account data, not a real person's. | Get model releases for every face (BOOTH, roll). No third-party logos, artwork or posters in sample photos. Use your own QR code and a wallpaper you own. No real names or notifications on the Lock Screen. |
| [2.3.10](https://developer.apple.com/app-store/review/guidelines/#2.3.10) | Don't include "names, icons, or imagery of other mobile platforms or alternative app marketplaces" in the app or metadata. Keep metadata about the app. | Never mention the Light Phone or Android. Roll as a port origin stays off the listing. The marketing URL points at the GitHub README, which says "iOS port of Roll for the Light Phone III". That is low risk, but consider pointing the marketing URL to `https://gi-os.github.io/XA/` instead. In-app date-back subtitles say "From Roll" (`DateBack.swift:21-23`); this is harmless but could be dropped. |
| [2.3.12](https://developer.apple.com/app-store/review/guidelines/#2.3.12) | "What's New" must describe significant changes. | Not used for version 1.0 ([platform version info](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)). Needed from 1.1, and it must name the tip jar if that is added later. |
| Product page guidance | Avoid specific prices in the description because pricing is shown by the store and may not be accurate in every region. Keywords: 100 bytes, comma-separated, no app/company names, no category names or "app", no plurals of words already used. Don't use "unauthorized use of trademarked terms… competing app names" ([product page](https://developer.apple.com/app-store/product-page/), [platform version info](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)). | Say "free" without a price figure. Never put a currency amount in copy. |
| Asset best practices | In screenshots: "Don't include specific pricing, discounts, website URLs, copyright symbols." No unverifiable claims or awards, no other platforms, no Apple recognitions such as Editor's Choice. Text should be a short phrase and localized ([asset best practices](https://developer.apple.com/app-store/asset-best-practices/)). | No "github.com/…", no "©", no "#1 film camera". |

### 1.2 Audit of the current draft (`/Users/giovannilupo/gi-os/XA/fastlane/metadata/en-US/`)

| Field | Current | Length | Verdict |
|---|---|---|---|
| Name | XA Camera | 9/30 | OK. Trademark discussion is in section 7. |
| Subtitle | Film, digicam and video looks | 29/30 | OK: no price, no other apps. |
| Keywords | film,retro,vintage,digicam,grain,date stamp,point and shoot,disposable,camcorder,photo booth,analog | 99/100 bytes | OK. It does not repeat "XA" or "Camera", which are already indexed from the name. **Low risk:** "photo booth" is generic but is also the name of Apple's Photo Booth app; "sticker booth" avoids that. Never add a film brand, "purikura" or a competitor name. |
| Promotional text | Film stocks, a 2003 digicam… | 159/170 | OK. Promotional text is the right place for "free, no subscription" lines. |
| Description | 1,723/4,000 | | Fix "1, 2, 3 or 5 megapixels" (the build offers 1 to 12). Fix "iPhone 16 and later" (16e has no Camera Control). Add the tip disclosure if tips ship. The FILM size claim follows B4. "The biggest photo the sensor makes" is true for PRO in the app, but the Lock Screen camera caps at 12 MP, so don't attach that claim to the `lock` screenshot. "What you see in the viewfinder is what you get" is soft for FILM: by default the finder is plain and shows the film for a few seconds after each change. It's acceptable, but don't build a FILM screenshot caption on it. |
| Support URL | gi-os.github.io/XA | | OK. It must lead to real contact info, and it has an email ([platform version info](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)). |
| Privacy URL | …/privacy.html | | Add three things required by 5.1.1(i): (a) retention and deletion ("XA collects nothing, so there is nothing to keep or delete; your pictures live in your Photos library"), (b) how to withdraw consent (Settings > Privacy & Security), (c) a tips paragraph ("payments are handled by Apple; XA receives no payment or personal information"). |
| Copyright | 2026 Giovanni Lupo | | OK. Don't type "©"; Apple adds it. |
| Review notes | `/Users/giovannilupo/gi-os/XA/fastlane/review_notes.txt` | | Add where the tip jar is and that tips unlock nothing. Optionally attach a sample QR code; "Before You Submit" suggests one. Fix the "iPhone 16 and later" wording. |

### 1.3 Terms to keep out of the name, subtitle, keywords, screenshots, previews and IAP names, in every locale

- **Prices and terms:** Free, $/€ amounts, "no subscription", "lifetime", "one-time". These are allowed in the description and promotional text only.
- **Competitors:** Dazz Cam, Huji, NOMO, 1998 Cam, Hipstamatic, KD Pro, VSCO, or any other app name. I did not verify competitor pricing for this report. Whatever it is, naming them in metadata is prohibited ([2.3.7](https://developer.apple.com/app-store/review/guidelines/#2.3.7)).
- **Camera and film brands:** Olympus, OM System, Kodak, Portra, Ektar, Kodacolor, Fujifilm, Superia, Natura, Instax, Polaroid, CineStill, Ilford, Tri-X, Leica, Lomo.
- **Others:** Game Boy, Nintendo, 3DS, "Print Club", "purikura" / プリクラ (a registered Sega trademark; see 7). In the Japanese listing use a generic term such as "写真シール機".
- **Other platforms:** Light Phone, Android.
- **Apple trademarks:** write "iPhone", **never "IPHONE"**. XA's all-caps caption style must not apply to Apple product names. Never translate App Store, iPhone or Siri ([marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/)). Lock Screen, Control Center and Camera Control may follow the iOS localized names in each locale; check them on a device in that language.

---

## 2. Screenshots and app previews: 2026 specs

### 2.1 iPhone screenshot sizes ([screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications))

| Display class (Apple's 2026 names) | Devices | Portrait size |
|---|---|---|
| **iPhone with Dynamic Island (large)** (formerly "6.9-inch") | iPhone 18 Pro Max, 17 Pro Max, 16 Pro Max | **1320 × 2868** |
| | iPhone 16 Plus, 15 Pro Max, 15 Plus, 14 Pro Max | 1290 × 2796 |
| | iPhone Air | 1260 × 2736 |
| **iPhone with Dynamic Island (medium)** | iPhone 18 Pro, 17 Pro, 17, 16 Pro, 16 | **1206 × 2622** |
| | iPhone 15 Pro, 15, 14 Pro | 1179 × 2556 |
| iPhone with Face ID (large) | 14 Plus, 13/12/11 Pro Max, 11, XS Max, XR | 1284 × 2778 or 1242 × 2688 |
| iPhone with Face ID (medium) | 17e, 16e, 14, 13, 12, 11 Pro, X/XS | 1170 × 2532, 1125 × 2436, 1080 × 2340 |
| iPhone Duo (future) | foldable | 1398 × 2034 outer, 2007 × 2853 inner. "Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later." |

**What is required.** Apple's page contradicts itself. The top says "iPhone: At least one screenshot for iPhone with Dynamic Island (medium display)". It also says that if the UI is the same across sizes, you only need the highest resolution and App Store Connect scales it down. **Recommendation:** upload a full **1320 × 2868** set and also a **1206 × 2622** set. The aspect ratios are almost identical, so a careful resize or a second capture costs little and satisfies both readings. iPad screenshots are not needed: `TARGETED_DEVICE_FAMILY` is "1" (iPhone only).

**Format:** .jpeg, .jpg or .png. "Images can't include alpha channels or transparencies."

**How many:** at least 1 and up to **10 per device size, per localization**. Depending on orientation, the first one to three appear in search results when there is no app preview. XA is portrait-only, so **the first three are what search shows**. Lead with digi, film and video (or booth) ([product page](https://developer.apple.com/app-store/product-page/), [asset best practices](https://developer.apple.com/app-store/asset-best-practices/)).

### 2.2 App previews ([app preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications))

- Optional. Up to **3 per device size and language**. They always play **before** the screenshots and autoplay muted, so the first seconds must work without sound.
- **15 to 30 s**, at most 500 MB, .mov/.m4v/.mp4 in H.264 (10–12 Mbps) or ProRes 422 HQ, **at most 30 fps**, stereo AAC 256 kbps at 44.1/48 kHz.
- Accepted resolution for Dynamic Island large and medium: **886 × 1920** portrait.
- Poster frame defaults to 5 s. Processing takes up to 24 h. A preview in a different aspect ratio from the screenshots moves to the "A Closer Look" section.
- Content: screen captures of XA only ([2.3.4](https://developer.apple.com/app-store/review/guidelines/#2.3.4)). Text overlays and narration are allowed.

### 2.3 Captions, device frames and text

- **Captions and text overlays are allowed** ([2.3.3](https://developer.apple.com/app-store/review/guidelines/#2.3.3)). Apple advises "a short phrase that enhances your visual rather than describes it", localized, inside a safe area ([asset best practices](https://developer.apple.com/app-store/asset-best-practices/)).
- **Not allowed in screenshots:** prices, discounts, URLs, ©, unearned awards, Apple recognitions, other platforms. Full-image call-to-action or accolade slides are discouraged ("avoid using the entire asset to highlight general accolades or call-to-action statements").
- **Device frames** are neither required nor banned by the guidelines. If you use them, follow the [marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/):
  - Apple-provided product bezels only, latest generation.
  - Use them "as is": no tilting, cropping, shadows, reflections, or elements coming out of the screen.
  - Copy goes beside the device, "not on top of" it.
  - No competing devices, no cases.
- **Status bar** (marketing guidance): full signal, Wi-Fi and battery, or let the full-screen viewfinder cover it.
- **New in iOS 27:** optional "creative assets" (product page header and search-result art) follow the same policies ([asset best practices](https://developer.apple.com/app-store/asset-best-practices/)).

### 2.4 Localized screenshots

**Yes.** Screenshots are a required, localizable property, and you can upload "specific screenshots and app previews tailored to each device size and localization" ([platform version info](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)). Apple recommends localizing description, keywords, previews and screenshots per market ([product page](https://developer.apple.com/app-store/product-page/)).

Because XA's interface is English-only, localized sets mean localized captions over English UI. That is acceptable. To avoid "misleading" complaints, I recommend adding a line to each localized description such as "The app's interface is in English." The product page also shows "Languages: English" automatically from the bundle.

### 2.5 Notes per screenshot concept

| id | Risk notes |
|---|---|
| `digi` | Fine. Caption must not imply 1–5 MP only. Don't name the film sim after a real stock. |
| `film` | Fine as a feature. Never caption it "Olympus XA finder"; use something like "A rangefinder finder, bright frame and all". No "full resolution" claim unless B4 has shipped. |
| `sims` | Check the film-box art in frame for trade-dress resemblance: Kodak yellow/red, Fujifilm green, CineStill red/black logos. Invented names (Bowery, Coney, Nocturne 800T…) are fine. |
| `video` | Show tape names as they are (VHS, SUPER 8). No JVC/VHS logo artwork. |
| `booth` | Real faces need releases. Keep it 4+. No "purikura" in the caption. |
| `pro` | Fine. "Manual" and "histogram" are verifiable. |
| `dates` | Fine. |
| `shapes` | For the hero image, prefer Porthole, Capsule or the round/wide instants over the square thick-bottom frame (see Polaroid in 7). Never use the word "Polaroid". |
| `roll` | Only XA-made photos you own the rights to, with no recognizable third-party artwork or brands. |
| `lock` | Screen-capture the real Lock Screen camera. Show the physical button with a touch-point overlay on the screenshot ([2.3.3](https://developer.apple.com/app-store/review/guidelines/#2.3.3)), not drawn onto an Apple bezel. Use your own wallpaper, no notifications or personal data. Say "iPhone with Camera Control", not "iPhone 16 and later". Don't say "full size" here (12 MP cap). |

---

## 3. Tip jar: In-App Purchase rules ([3.1.1](https://developer.apple.com/app-store/review/guidelines/#3.1.1))

**What Apple allows.** 3.1.1 says, verbatim: "Apps may use in-app purchase currencies to enable customers to 'tip' the developer or digital content providers in the app." So a tip jar is allowed and **must use Apple In-App Purchase**. In practice that means consumable products. 3.1.1 also requires IAP to unlock any features or functionality, so a tip that unlocks something stops being a tip.

**Is there required wording?** Apple publishes no mandatory script. The binding requirements are accuracy and disclosure ([2.3.1](https://developer.apple.com/app-store/review/guidelines/#2.3.1), [2.3.2](https://developer.apple.com/app-store/review/guidelines/#2.3.2)) and no manipulation ([5.6](https://developer.apple.com/app-store/review/guidelines/#5.6): don't "trick them into making unwanted purchases… or engage in any other manipulative practices").

Checklist:

- [ ] **Product type:** Consumable, one product per tier, e.g. `com.gios.xa.tip.small/.medium/.large`. Product IDs can never be reused once created ([IAP information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)).
- [ ] **Tips unlock nothing:** no badge, alternate icon, "supporter" status or bonus look. Otherwise "every feature included" is false and it becomes a feature IAP.
- [ ] **Wording:**
  - Use Apple's word, **"tip"**.
  - Avoid "donate/donation": charity fundraising is a separate restricted case under [3.2.2(iv)](https://developer.apple.com/app-store/review/guidelines/#3.2.2) and [3.2.1(vi)](https://developer.apple.com/app-store/review/guidelines/#3.2.1).
  - Avoid "unlock", "pro", "premium", "keep XA free" pressure, and countdowns.
  - Suggested screen copy: "XA is free with every feature included. If you'd like to support it, leave a tip. Tips are optional and unlock nothing."
- [ ] **Prices:** show StoreKit's localized display price; never hard-code an amount, because prices vary by storefront ([product page](https://developer.apple.com/app-store/product-page/)).
- [ ] **Placement:** in Customize/About. Never on launch, never blocking capture, no repeat nags.
- [ ] **Restore button:** not needed for consumable-only tips. 3.1.1 asks for restore only for "restorable" purchases.
- [ ] **Transactions:** finish every transaction and listen for transaction updates. If IAPs are promoted on the product page, the app must complete a purchase started from the store at launch ([2.3.2](https://developer.apple.com/app-store/review/guidelines/#2.3.2)).
- [ ] **No external tip links in the app or metadata.** No GitHub Sponsors, Ko-fi, PayPal, Patreon or Buy Me a Coffee. Outside the US, "apps and their metadata may not include buttons, external links, or other calls to action that direct customers to purchasing mechanisms other than in-app purchase" ([3.1.1(a)](https://developer.apple.com/app-store/review/guidelines/#3.1.1a)). The US storefront has been exempt since the April 30, 2025 court order ([explainer](https://median.co/blog/epic-v-apple-payment-links-ruling-explained)), but one worldwide build is simpler: use IAP only. The repo currently has no `.github/FUNDING.yml`. Keep it that way, because the GitHub README is the marketing URL.
- [ ] **App Store Connect fields per tip** ([IAP information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)):
  - Reference name: at most 64 characters, internal.
  - Display name: **2 to 30 characters**.
  - Description: **at most 45 characters**, e.g. "A thank-you. Unlocks nothing." (29).
  - **App Review screenshot (required)** of the tip screen.
  - Review notes.
  - A 1024 × 1024 promo image only if you promote the tip on the product page (optional; probably skip).
  - The product page guide states 35/55 characters, but the App Store Connect field limits above are stricter. Use 30/45.
- [ ] **Submit with the app version:** "The first consumable… In-App Purchase… must be submitted with a new app version." Put v1.0 and all tip IAPs in **the same draft submission** before clicking Submit ([submit an IAP](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)). If tips arrive in 1.1, they go with 1.1.
- [ ] **Reviewer access:** IAPs must be "complete, up-to-date, visible to the reviewer and functional" ([2.1(b)](https://developer.apple.com/app-store/review/guidelines/#2.1)). Say where the tip jar is in the review notes.
- [ ] **Product page effect:** expect the "In-App Purchases" label next to Get, and the tip names and prices in the information section. That is why the names must clearly say "Tip".
- [ ] **Admin prerequisites:** Paid Apps Agreement, banking and tax (B9). IAP revenue is a DSA trader factor (B8).

**3.1.2 Subscriptions does not apply.** XA has no auto-renewable or non-renewing subscriptions. 3.1.3 (other purchase methods) also does not apply. Related rules that still do:

- [3.2.2(x)](https://developer.apple.com/app-store/review/guidelines/#3.2.2): never gate features on rating or reviewing.
- [5.6.1](https://developer.apple.com/app-store/review/guidelines/#5.6.1): only Apple's review prompt API, no custom review prompts.

---

## 4. Design and hardware rules for a camera app

| Rule | Status for XA |
|---|---|
| [4.1](https://developer.apple.com/app-store/review/guidelines/#4.1) Copycats. 4.1(c): "You cannot use another developer's icon, brand, or product name in your app's icon or name, without approval." | Don't imitate competitors' UI or icons. "XA" as a former Olympus product name is covered in section 7. |
| [4.2](https://developer.apple.com/app-store/review/guidelines/#4.2) Minimum functionality | Clearly met. |
| [4.3(b)](https://developer.apple.com/app-store/review/guidelines/#4.3) Spam / saturated categories | Retro filter cameras are a crowded genre, though not on Apple's named list. Review notes should show what is original: physically modelled film, five distinct cameras, manual PRO, Lock Screen and Camera Control integration, open source. |
| [2.4.1](https://developer.apple.com/app-store/review/guidelines/#2.4.1) "iPhone apps should run on iPad whenever possible" | iPhone-only apps install on iPad in compatibility mode, and Review can test there. **Test the camera, Photos flow and roll on an iPad before submitting.** |
| Mac (Apple silicon) and Apple Vision Pro availability | iPhone apps are offered on these by default. **Recommend opting out** under Pricing and Availability: a rear-camera app gives a poor experience there. |
| [2.5.1](https://developer.apple.com/app-store/review/guidelines/#2.5.1) Public APIs used for their purpose, and described in the description | Uses LockedCameraCapture (`Capture/XACapture.swift`), AVCaptureControl for Camera Control (`CameraModel.swift:636+`) and AVCaptureEventInteraction for the volume buttons (`XA/UI/PreviewView.swift:115`). The description mentions all three. |
| [2.5.9](https://developer.apple.com/app-store/review/guidelines/#2.5.9) Don't alter the volume buttons' function | OK: the shutter uses Apple's sanctioned capture-event API, not a volume-observer hack. |
| [2.5.14](https://developer.apple.com/app-store/review/guidelines/#2.5.14) Consent and indication when recording | System permission prompts plus the system camera/mic indicators. OK. |
| [2.5.16](https://developer.apple.com/app-store/review/guidelines/#2.5.16) Extensions related to the app | The Lock Screen camera and Control are core features. OK. The Lock Screen camera opens the unlocked app for the roll, so no library is shown while locked. |
| [2.1](https://developer.apple.com/app-store/review/guidelines/#2.1) Completeness | No login needed. The review notes already say to test on a device. |

---

## 5. Privacy

### 5.1 Permission strings and denied-permission handling ([5.1.1](https://developer.apple.com/app-store/review/guidelines/#5.1.1), [HIG Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy))

| Permission | String (`project.yml`, app and capture extension) | When requested | If denied | Verdict |
|---|---|---|---|---|
| Camera | "XA is a camera. It needs the camera to take pictures." | At launch (this is the core function) | `CameraDeniedNote` (`CameraView.swift:921`) explains it and has an Open Settings button; the Lock Screen version shows the Settings path. | OK |
| Microphone | "XA records sound with your videos." | Only when entering VIDEO (`CameraModel.swift:1078`) | VIDEO records without sound. | OK: photos never need the mic, which is exactly 5.1.1(iv)'s example. Nice-to-have: a small "no sound" indicator when the mic is denied. |
| Photos (add only) | "XA saves the pictures and videos you take to Photos." | First save | XA holds pictures and explains this in the roll (`ContactSheet.swift:33`), with Open Settings. | OK |
| Photos (read/write) | "XA files your pictures in an XA album and shows them as its roll." | Roll / album | Handles limited access, add-only access and denial. | OK. Justified under 5.1.1(iii) because the roll reads its own album. |
| Location, Contacts, ATT | none | none | none | OK |

HIG checks: purpose strings should be a "brief, complete sentence", in sentence case, with a period; these pass. Don't show a custom pre-permission screen that mimics the system alert or uses "Allow"; none is used. The rules also require respecting the user's choice and never forcing consent ([5.1.1(iv)](https://developer.apple.com/app-store/review/guidelines/#5.1.1), [5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#5.1.2)).

### 5.2 App Privacy label: "Data Not Collected"

- "Collect" means sending data off the device and keeping it readable beyond servicing the request. "Data that is processed only on device is not 'collected'". And: "You are not responsible for disclosing data collected by Apple." ([App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/))
- XA has no server, no SDKs and no analytics. StoreKit tips are processed by Apple, and the developer receives only Apple's reports. **"Data Not Collected" is accurate with the tip jar.**
- Revisit the label if any of these are added: server-side receipt validation that stores data, a crash or analytics SDK, or an email form.
- The privacy manifests (`XA/PrivacyInfo.xcprivacy`, plus `Capture/` and `Control/`) declare no tracking and no collected types, and give reasons for UserDefaults (CA92.1) and disk space (85F4.1). This is consistent.
- Keep "no tracking, nothing collected" in the description; the label supports it.

---

## 6. Age rating: the 2025 questionnaire

Apple added the 13+, 16+ and 18+ ratings (4+ and 9+ remain) and new required questions about in-app controls, capabilities, medical or wellness topics and violent themes. Existing apps had until **January 31, 2026** to answer; a new app answers everything on its first submission ([9to5Mac](https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/), [age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)).

| Section | Question | XA answer | Reason |
|---|---|---|---|
| In-App Controls | Parental controls | No | none |
| | Age assurance | No | No accounts, no age-gated content. |
| Capabilities | Unrestricted web access | **No** | QR links open in the system browser through `openURL` (`CameraView.swift:880`). There is no embedded browser (no WKWebView or SFSafariViewController). Answering Yes would mean 16+. |
| | User-generated content | No | Photos stay on the phone; nothing is distributed. |
| | Social media | No | none |
| | Messaging and chat | No | none |
| | Advertising | No | none |
| Mature themes (profanity, horror, alcohol/tobacco/drugs) | | None | none |
| Medical or wellness | | None | Beauty and skin settings in BOOTH are not medical or wellness content. |
| Sexuality or nudity | | None | none |
| Violence / weapons | | None | none |
| Chance-based (gambling, simulated gambling, contests, loot boxes) | | None | none |
| **Result** | | **4+** | Do **not** choose the Kids category ("For Kids" is reserved; [2.3.8](https://developer.apple.com/app-store/review/guidelines/#2.3.8)). |

---

## 7. Intellectual property ([5.2](https://developer.apple.com/app-store/review/guidelines/#5.2))

5.2.1: "Don't use protected third-party material such as trademarks… without permission, and don't include misleading, false, or copycat representations, names, or metadata." Enforcement usually comes from a rights holder's complaint through Apple's IP dispute form, not from App Review. The realistic downside is a takedown or forced rename after launch.

| Item | Facts | Risk | What to do |
|---|---|---|---|
| **App name "XA" / "XA Camera" vs the Olympus XA** | The Olympus XA was a 35 mm pocket rangefinder made 1979–1985 ([Wikipedia](https://en.wikipedia.org/wiki/Olympus_XA)). US records show Olympus Optical's word mark **"XA"** for photographic cameras (serial 73317334), registered 11 May 1982 and **cancelled 18 March 2016** (Section 8, not maintained) ([Justia](https://trademarks.justia.com/733/17/xa-73317334.html)). "OLYMPUS XA" (reg. 1240016) was cancelled in 1989 ([Justia](https://trademarks.justia.com/733/17/olympus-xa-73317335.html)). Olympus's camera business has been OM Digital Solutions since 2021, selling as "OM SYSTEM" ([Wikipedia](https://en.wikipedia.org/wiki/OM_Digital_Solutions), [PetaPixel](https://petapixel.com/2022/10/31/the-olympus-brand-will-be-removed-from-all-om-digital-camera-gear)), and it has reused heritage model names such as OM-1. Two-letter marks are crowded: Fujifilm filed "X-A" in the EU in 2017, Sony sold Xperia XA phones, and several unrelated live US "XA" filings exist in other classes. **I did not check Japan (JPO/J-PlatPat) or the EU (EUIPO/TMview) for a live "XA" in Class 9, cameras and downloadable software.** | **Low to moderate.** No live US registration for cameras was found. The risk grows when XA explicitly ties itself to Olympus. | Keep the name, but (1) remove "Olympus" from the app (B3) and never use it in metadata, screenshots, the website or press. (2) Run a proper clearance search in USPTO, EUIPO and JPO for Classes 9 and 42 before launch. (3) Consider filing "XA Camera" yourself; it also helps against confusing forks (see 8). (4) Have a fallback name ready. |
| **Alternate icon "LensCover"** (`AppIcon-LensCover.appiconset`) | The lens ring reads "XA 1:2.8 f=35mm" with an "ASA 25 … 800" scale. That closely echoes the original XA's lens and film-speed markings, with no Olympus wordmark (it says "Gi-OS" / "G. LUPO"). | Low (it is an alternate icon, not the store icon). | Keep the dot-matrix primary icon as the store icon. Consider changing the ring text away from the exact XA specs. |
| **FILM finder modelled on a classic rangefinder** (bright frame, speed scale with meter needle, rangefinder patch; `XAFinder.swift`, `XAFinderView.swift`) | These are generic, functional finder elements shared across rangefinders. No logos are drawn. | Low | Describe it generically: "a 1970s pocket rangefinder's finder". Never "Olympus XA finder". |
| **Film stock and sim names** | Invented: Bowery, Coney, Chelsea, Prospect, Canal, Orchard, Ludlow, Bleecker, Delancey, Essex; XAcolor Nocturne 800T, Visage 800, Prima X 400, Amethyst 400; XA Instant Sunday; XApan Onyx 3200. Real stock names appear only in code comments and in the NOTICE.md disclaimer. | Low | Copy may use generic descriptors ("tungsten 800T cinema stock", "portrait stock", "consumer 400", "instant film"). Never "Portra-like", "Kodak look", "CineStill 800T", "Superia", "Tri-X". Check that the film-box art doesn't copy brand trade dress (see `sims` in 2.5). |
| **Instant-print shapes** | The square "INSTANT" frame (thick bottom border) is the shape Polaroid claims as its "Classic Border Logo". Polaroid's suit against Fujifilm over Instax was cleared for trial in 2025, and I found no verdict ([PetaPixel](https://petapixel.com/2017/11/17/fujifilm-polaroid-demanding-millions-per-year-white-border-instax), [Bloomberg Law](https://news.bloomberglaw.com/ip-law/fujifilm-must-face-trial-over-polaroids-logo-trademark-claims)). On-screen names are generic (INSTANT / MINI / WIDE). | Low for the feature; avoid making it the brand image. | Never say "Polaroid" or "Instax". Don't use the rainbow stripe. Don't make the square instant the hero of `shapes` or of ads. |
| **POCKET / POCKET COLOR / POCKET 3D** (Game Boy Camera and 3DS looks) | Generic names; Nintendo appears only in code comments. | Low | Never "Game Boy look" or "3DS" in copy. |
| **VHS, SUPER 8, CCTV tape names** | Format names used descriptively. The VHS logo is JVC's. | Low | Use the words only, no logos. |
| **BOOTH** | "プリクラ" (purikura) and "Print Club" are registered trademarks of Sega Holdings in Japan ([Sega Retro](https://segaretro.org/Print_Club); confirm on J-PlatPat). They appear only in code comments. | Low if kept out of copy | Keep them out of all metadata, especially the Japanese listing. |
| **Apple marks** (iPhone, Camera Control, Lock Screen, Control Center) | Referring to compatibility is fine. Follow the typesetting rules ([marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/)). Don't imply Apple endorses XA ([5.2.4](https://developer.apple.com/app-store/review/guidelines/#5.2.4)) or look like an Apple app ([5.2.5](https://developer.apple.com/app-store/review/guidelines/#5.2.5)). | Low | "iPhone" is never written in all caps. |
| **Fonts** | SIL OFL 1.1 and Apache 2.0 faces, with licenses shipped in the app (`NOTICE.md`). | None | Keep the license texts bundled. |

---

## 8. Open source and GPL on the App Store

- **Apple's guidelines say nothing about GPL or open source.** The issue is only license compatibility. The GPL forbids adding restrictions, while App Store terms and DRM add them. That conflict is how VLC was pulled in 2011 after one of its own copyright holders complained ([The Next Web](https://thenextweb.com/news/apple-officially-pulls-vlc-from-the-app-store)).
- **XA's fix is correct for code Giovanni owns.** `/Users/giovannilupo/gi-os/XA/EXCEPTION.md` grants a GPLv3 §7 additional permission to convey through the App Store and TestFlight, on condition that the complete Corresponding Source is public. Since he is the sole copyright holder of XA's own code, this is enough.
- **Check third-party pieces:**
  - **spektrafilm** (Andrea Volpato, GPLv3 code; CC BY-SA 4.0 profiles and LUTs). The Python code is not shipped. The baked tables ship as bundle resources, with attribution in the app (`CustomizeView.swift:181`), which is good. Some Swift effects are "fitted against" spektrafilm and use its parameter names. Parameters and ideas are not copyrightable, but translated code would be. **Confirm no spektrafilm source was ported into Swift, or get Volpato's written App Store permission** (the same wording as EXCEPTION.md). It is the one way the VLC scenario could apply.
  - CC BY-SA 4.0 forbids extra terms or DRM on the licensed material. The tables are plain resource files (FairPlay encrypts the executable, not resources), and the attribution and license are visible. My assessment: low risk. Keep the tables and their license in the public repo.
  - Fonts (OFL/Apache): fine.
- **Launch hygiene:**
  - Tag the exact source of each App Store build in git (e.g. `v1.0`) so the Corresponding Source matches the shipped binary.
  - Keep the repo public on launch day.
  - Add Source code and Licenses links in the in-app About screen (also helps B2).
- **Forks:** the GPL lets anyone fork and submit XA. Apple's [4.1](https://developer.apple.com/app-store/review/guidelines/#4.1) and [4.3](https://developer.apple.com/app-store/review/guidelines/#4.3) cover impersonating clones, and a registered trademark on the name is the strongest tool against forks reusing it.
- App Store Connect also lets you set a custom license agreement. That isn't needed here, because the §7 permission covers Apple's standard EULA.

---

## 9. Other App Store Connect items

- [ ] **DSA trader status** (Business > Agreements > Compliance). The guidance lists In-App Purchases as a trader factor. As a trader, Apple shows your address or P.O. box, phone and email on EU product pages, and you must verify the email and phone ([DSA page](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)). Decide before submitting; using a P.O. box is allowed.
- [ ] **Paid Apps Agreement, banking and tax** (needed for tips).
- [ ] **Export compliance:** `ITSAppUsesNonExemptEncryption = false` is already in `XA/Info.plist`. OK.
- [ ] **Content rights:** `ci/app.env` has `THIRD_PARTY_CONTENT="false"`, but the app bundles third-party OFL fonts and CC BY-SA tables. Answering **"Yes, and I have the rights"** is more accurate; the Fastfile already sends `has_rights: true`.
- [ ] **Availability:** opt out of Mac and Vision Pro (section 4). For **China mainland**, App Store Connect may require an MIIT ICP filing number, which needs a local entity or publisher. Either exclude China at launch or plan for it ([App Store Connect help](https://developer.apple.com/help/app-store-connect/reference/app-information/)). Whether an offline app needs one is not settled by Apple's page; verify.
- [ ] **Release:** the Fastfile uses `automatic_release: false`, which allows a manual launch-day release. Good.
- [ ] **Developer identity** ([5.6.2](https://developer.apple.com/app-store/review/guidelines/#5.6.2)): the seller name must match the developer account; contact info must be accurate.

---

## 10. Sources (read 14 Oct 2026)

**Apple: rules and specs**
- App Review Guidelines (last updated June 8, 2026): https://developer.apple.com/app-store/review/guidelines/
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- App preview specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications
- Product page: https://developer.apple.com/app-store/product-page/
- Asset best practices: https://developer.apple.com/app-store/asset-best-practices/
- Marketing and identity guidelines: https://developer.apple.com/app-store/marketing/guidelines/
- Platform version information: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information

**Apple: In-App Purchases, privacy, age rating, compliance**
- Submit an In-App Purchase: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase
- In-App Purchase information: https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information
- App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Age ratings values and definitions: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- EU DSA trader requirements: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements
- HIG Privacy: https://developer.apple.com/design/human-interface-guidelines/privacy

**Third-party sources**
- Age rating change: https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/
- US external links ruling: https://median.co/blog/epic-v-apple-payment-links-ruling-explained
- Trademarks: https://trademarks.justia.com/733/17/xa-73317334.html, https://trademarks.justia.com/733/17/olympus-xa-73317335.html
- Olympus XA and OM Digital Solutions: https://en.wikipedia.org/wiki/Olympus_XA, https://en.wikipedia.org/wiki/OM_Digital_Solutions, https://petapixel.com/2022/10/31/the-olympus-brand-will-be-removed-from-all-om-digital-camera-gear
- Polaroid vs Fujifilm: https://petapixel.com/2017/11/17/fujifilm-polaroid-demanding-millions-per-year-white-border-instax, https://news.bloomberglaw.com/ip-law/fujifilm-must-face-trial-over-polaroids-logo-trademark-claims
- Purikura / Print Club: https://segaretro.org/Print_Club
- VLC on the App Store: https://thenextweb.com/news/apple-officially-pulls-vlc-from-the-app-store

**Repo files referenced** (all under `/Users/giovannilupo/gi-os/XA/`)
- `fastlane/metadata/en-US/*.txt`, `fastlane/review_notes.txt`, `fastlane/Fastfile`, `ci/app.env`
- `docs/privacy.html`, `project.yml`, `XA/Info.plist`, `XA/PrivacyInfo.xcprivacy`
- `XA/UI/CustomizeView.swift` (lines 130, 163, 181), `XA/UI/CameraView.swift` (857–880, 921–945), `XA/UI/ContactSheet.swift`, `XA/UI/PreviewView.swift`
- `XA/Camera/CameraModel.swift`, `XA/Camera/Settings.swift`, `XA/Film/FilmRoll.swift` (uncommitted drum-scan change), `XA/Film/FilmLab.swift`, `XA/Film/Shapes.swift`, `XA/Film/DateBack.swift`
- `Capture/XACapture.swift`, `EXCEPTION.md`, `NOTICE.md`
- `XA/Resources/Assets.xcassets/AppIcon-LensCover.appiconset/icon.png`
