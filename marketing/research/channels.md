# XA launch channel plan

**Prepared:** 2026-10-14
**Inputs:** the repo (README, `fastlane/metadata/en-US/*.txt`, `review_notes.txt`, `docs/index.html`, Swift sources for mode, look, tape, stock and date-back names) and web research done today. Every external claim has a URL next to it. Anything marked "third-party" or "unverified" needs checking before it goes into copy.

---

## 0. Summary

1. **Lead with what competitors can't say.** XA is free, has no subscription, no ads, no account, collects nothing, and is open source (GPLv3). The retro camera category is crowded and runs on subscriptions:
   - Dazz Cam: $19.99/yr or $49.99 one-time
   - NOMO PRO: $24.99/yr
   - 1998 Cam: up to $29.99/yr
   - Hipstamatic Camera Club: up to $29.99

   The biggest iPhone camera Show HN of 2026 (Photosynthesis, 329 points) drew a lot of complaints about its subscription. That backlash is XA's opening.
2. **The channels that matter most** are the Apple featuring nomination, Hacker News (Show HN), short-form social (TikTok carousels, Reels, Threads) and a short list of press tip inboxes.
3. **Product Hunt is low return for this category.** Recent retro camera apps placed #135 to #157 with 3 to 5 upvotes and none were featured. Do it on a weekend for the backlink, and don't put a big effort into it.
4. **Many Reddit communities ban XA outright:**
   - r/photography bans apps entirely.
   - r/analog bans images that are digital in origin.
   - r/AppHookup bans apps that are always free.
   - r/digicam and r/DigitalCamera are for real cameras.

   Where it is allowed, the rules are strict: r/apple only on Sundays with prior participation, r/iphone only after messaging the mods, r/iOSapps one post per 30 days with tiers.
5. **Proposed dates:** US launch **Tue Nov 17, 2026**. Submit the Apple featuring nomination **by Oct 27** (Apple's help page asks for at least 3 weeks), and sooner if possible. Then a holiday wave (New Year's Eve "party digicam", new iPhones at Christmas) and a Japan/Korea wave tied to graduation season (Feb to Mar), once the store listing is localized.
6. **Fix FILM resolution before launch.** This is the request you sent alongside this task; this research task did not change any code. Today FILM photos are low resolution (details in section 1). Photo press will look at the full-size files, and the planner's brief says "saves full resolution HEIC", which isn't true yet.

---

## 1. Launch blockers and copy guardrails (from the repo)

| # | Item | Evidence | What to do |
|---|---|---|---|
| 1 | **FILM photos are low resolution** (your request) | By default FILM saves at a "lab scan" size of **3088 px on the long edge**, about 6 to 7 MP at 35mm 3:2 and less for half frame or 110 (`/Users/giovannilupo/gi-os/XA/XA/Film/FilmRoll.swift`: `FilmScan.lab`, `var scan: FilmScan = .lab`). Even the "full" scan reads the sensor at **12.6 MP at most**, because every non-PRO mode is capped (`/Users/giovannilupo/gi-os/XA/XA/Camera/Mode.swift` line 31 `maxSensorPixels`; `/Users/giovannilupo/gi-os/XA/XA/Camera/CameraModel.swift` `shotDims`). The Lock Screen extension also scales FILM to 3088 (CameraModel.swift line 1389). | Raise this before sending press samples. Until it ships, **copy must not claim "full resolution" for FILM.** The current store description doesn't (only PRO is "full quality"), but the brief's facts do. |
| 2 | Date backs: **8 in code, 7 in copy** | `/Users/giovannilupo/gi-os/XA/XA/Film/DateBack.swift` has quartz, dots, camcorder, lcd, stamp, marker, edge and **digicam** ("2005 pocket digicam, red pixels"). All are selectable through `DateStyle.allCases`. | Add the eighth style to the copy, or hide it in the app. |
| 3 | **The tip jar isn't built** | There is no StoreKit code in the repo. | Don't announce it at launch until it ships. Apple guideline 3.1.1 allows tipping only through in-app purchase ([guidelines](https://developer.apple.com/app-store/review/guidelines/)). |
| 4 | No screenshots yet | `fastlane/screenshots/` doesn't exist. | Capture the 10 agreed screenshots (section 7 maps them to channels). |
| 5 | GitHub repo has 0 stars and was created Sept 28, 2026 | GitHub API. | Before HN, put hero images or GIFs, full-size sample photos (after fix #1) and the App Store badge at the top of the README. |
| 6 | No Terms of Service page | Only `docs/privacy.html` exists. | Add `docs/terms.html`. r/iOSapps requires a privacy policy **and** terms for its "Transparency" posting tier (section 5). |
| 7 | Questions HN will ask about licensing | GPLv3 plus the section 7 App Store permission in `EXCEPTION.md`. spektrafilm *code* is GPLv3 by Andrea Volpato; its LUTs and profiles are CC BY-SA 4.0 (`NOTICE.md`). | Prepare a two-line answer. **Confirm** that the shipped app contains only the baked CC BY-SA tables and none of spektrafilm's GPL code; if it does contain code, App Store distribution needs the author's permission. |
| 8 | App Store metadata rules | Guideline 2.3.7: no trademarked terms, popular app names or **pricing** stuffed into the name or keywords. Guideline 2.3.10: no names of other mobile platforms ([guidelines](https://developer.apple.com/app-store/review/guidelines/)). | Keep "free" out of the name, subtitle and keywords (fine in the description). No "Light Phone", "Android", "Olympus", "Portra", "Polaroid" or "Instax" in metadata. The app already uses invented stock names (Bowery, Coney, Canal 500T and others) and generic "Instant" print names. Never write "iXA"; write "XA for iPhone". Photo press will connect "XA" with the Olympus XA, so imply no affiliation. |

---

## 2. Timeline (proposed)

Dates assume the build is approved by late October. If FILM resolution or approval slips, move everything to **Tue Jan 12, 2027** (after CES and the holiday review slowdown).

| When | Action |
|---|---|
| **Now to Oct 23** | Fix FILM resolution. Add the README images and the terms page. Capture screenshots and record a 15 to 30 s app preview. Submit the build. Consider **pre-order** (2 to 180 days, [Apple](https://developer.apple.com/app-store/promote/)) so press gets a live App Store URL early. |
| **By Tue Oct 27** (sooner if possible) | Submit the **App Store Connect featuring nomination**, type "App Launch" (section 3). Apple's help page asks for at least 3 weeks; its featuring page says at least 2 weeks and up to 3 months for wider consideration. |
| Oct 15 to Nov 16 | Pre-launch participation: build genuine comment history on r/apple (5 or more non-XA posts or comments in the past month are required) and r/iOSProgramming (about 20 karma in 6 months). Message the r/iphone mods for developer flair. Start the TikTok, Instagram and Threads accounts. **Oct 31:** Halloween posts with the VHS and CCTV tapes. |
| Late Oct to early Nov | Optional public TestFlight feedback post on r/iphoneography. Mood.camera did exactly this before TechCrunch covered it ([TechCrunch](https://techcrunch.com/2024/04/22/mood-camera-is-an-ios-app-that-feels-like-using-a-retro-analog-camera/)). |
| **Tue Nov 10** | Press pitches go out with the pre-order or TestFlight link and "available Nov 17" (section 6). |
| **Tue Nov 17, launch** | App goes live. **Show HN about 7 to 9 am PT**, and stay in the thread all day. Send launch-day notes to the tip inboxes that didn't reply. Add XA to dkhamsing/open-source-ios-apps and AlternativeTo. |
| Wed Nov 18 to Fri Nov 20 | Stagger Reddit: r/iOSapps, r/SwiftUI, r/opensource, r/SideProject, r/apps. One per day so you can answer every comment. |
| **Sat Nov 21** | r/iOSProgramming "App Saturday". **Product Hunt at 12:01 am PT** (Saturday or Sunday). |
| **Sun Nov 22** | r/apple Self-Promotion Sunday. |
| Nov 24 to 28 | US Thanksgiving week (Nov 26). In 2025 Apple warned reviews could be slower **Nov 24 to 28 and Dec 23 to 27** ([GoodBarber summary](https://www.goodbarber.com/blog/app-store-connect-remains-open-during-the-holiday-season-a1124/)); check Apple's 2026 notice. Avoid launches and pitches. |
| **By about Nov 27** | Second nomination, type "App Enhancement" (for example the FILM high-res update, or holiday content), aimed at mid-December. |
| Dec 18 to Jan 2 | **Holiday wave.** New Year's Eve "party digicam" flash photo dumps, and "Set up Camera Control on your new iPhone" content for Christmas gifts. |
| Jan to Mar 2027 | **Japan and Korea wave.** Localize the ja and ko listings and screenshot captions, submit a nomination with localizations, and build BOOTH and DIGI content around graduation season (Korea in February, Japan in March). |

---

## 3. Apple channels

### 3a. Featuring nomination (App Store Connect)
- **Where:** App Store Connect, the app, Featuring, Nominations, "+", Create Nomination. Types are New Content, App Enhancements and **App Launch (or pre-order)**. Roles: Account Holder, Admin, App Manager or Marketing ([help page](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/)).
- **Lead time:** "minimum lead time of 3 weeks" (help page). The [Getting Featured](https://developer.apple.com/app-store/getting-featured/) page says 2 weeks minimum and up to 3 months for wider consideration.
- **Fields:** name, a detailed description (purpose and priority), publish date or range, platforms, countries, localizations, attached In-App Events, **up to 5 supplemental URLs**, and "Helpful Details" (accessibility, inclusivity, what makes it unique).
- **What editors weigh** ([Getting Featured](https://developer.apple.com/app-store/getting-featured/)): user experience, UI design, **innovation (new technologies)**, uniqueness, accessibility, **localization** and the product page (screenshots, previews, ratings).
- **What to put in it:**
  - Platform tech editors like: the Lock Screen camera (LockedCameraCapture) and Camera Control (the AVCaptureControl sliders through sims and looks).
  - Five cameras in one app, all live in the viewfinder.
  - Film physically modelled from published datasheets.
  - No data collected, no account, free with no feature gates.
  - Accessibility work, if any. List it honestly; if there is none, consider a VoiceOver pass first.
  - Supplemental URLs: the GitHub repo, a full-resolution sample gallery, the preview video, the support site.

### 3b. Product page tools
- **Custom product pages:** up to **70**, each with its own screenshots, promo text and previews, a **unique URL**, optional **keywords**, and localization. They need review but not an app update. Apple says sending people to a custom page lifts conversion by 2.5 points on average ([Apple](https://developer.apple.com/app-store/custom-product-pages/)). Build at least **BOOTH**, **DIGI**, **FILM** and **PRO** pages and link the matching one from each social post or bio.
- **Creative assets (new, announced Oct 5, 2026):** images and video for the **product page header and search results**, managed in a new Asset Library, submitted separately from builds, with a preview tool ([Apple news](https://developer.apple.com/news/?id=ljpl7kyn), [specs](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/)). Third-party note: assets must suit a 4+ audience ([Adapty](https://adapty.io/blog/app-store-creative-assets/)).
- **In-App Events:** types are challenge, competition, live event, major update, new season, premiere and special event. Up to 31 days, reviewed, attachable to nominations ([MobileAction guide](https://www.mobileaction.co/guide/in-app-events-promotional-content-guide)). Good later candidates: a "major update" (new tapes or stocks) or a seasonal "special event" such as Halloween tapes.
- **Marketing assets in App Store Connect:** generates share-ready launch images, and **notifies you if you're App of the Day** ([Promote page](https://developer.apple.com/app-store/promote/)).
- **App Store Marketing Tools** ([toolbox.marketingtools.apple.com](https://toolbox.marketingtools.apple.com/app-store/)): short links, QR codes, badges and embed code.
- **Smart App Banner** on gi-os.github.io/XA ([Promote page](https://developer.apple.com/app-store/promote/)).
- **Apple Ads** offers a $100 credit to eligible developers. Optional: a small test on "digicam" and "film camera" search terms.
- **Measuring results:** XA has no analytics, so use App Store campaign links (a `ct=` token per channel: hn, ph, rdt-iosapps, tiktok and so on). App Analytics reports them as aggregates, which keeps the "nothing collected" promise.

### 3c. Badge and Apple artwork rules ([Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/))
- Use the **black "Download on the App Store" badge**. White is allowed only when it's the only badge. Switch from "Pre-order on the" to "Download on the" at release.
- Minimum height **40 px on screen, 10 mm in print**. Clear space **one quarter of the badge height** (one tenth in very tight layouts).
- **One badge per layout or video**, in a subordinate position. Don't modify, angle or animate it. "App Store" always stays in English; the "Download on the" part has official translations.
- Apple product images: at least 200 px on screen or 25 mm in print, unmodified, no 3D renders, copy beside the device and never on top of it.
- Trademark usage: "iPhone" (lower-case i, even at the start of a sentence) and "XA for iPhone", never "iPhone XA".

---

## 4. Hacker News (Show HN)

**Rules** ([Show HN](https://news.ycombinator.com/showhn.html), [guidelines](https://news.ycombinator.com/newsguidelines.html), [FAQ](https://news.ycombinator.com/newsfaq.html)):
- It must be something people can try, with no sign-up wall. Landing pages and waitlists don't qualify. The title starts with "Show HN:".
- You must be the maker and be around to answer.
- **No asking for upvotes or comments**, from anyone. No uppercase, exclamation marks or hype in the title.
- Reposts are OK "if a story has not had significant attention" (a small number).

**Precedents:**
- *Photosynthesis*: iPhone app fusing two lenses, **329 points and 305 comments, Aug 2026**. Commenters liked the technical achievement and objected to a subscription for a local-only app ([thread](https://news.ycombinator.com/item?id=49226623)).
- *Black Hole Vision*: 316 points ([thread](https://news.ycombinator.com/item?id=42185668)).
- *Canvify*: 255 points ([thread](https://news.ycombinator.com/item?id=29059454)).
- *Glitchy camera*: a circuit-bent camera simulator, 173 points, Feb 2026 ([thread](https://news.ycombinator.com/item?id=47033954)).
- *DigicamFinder*: 177 points ([thread](https://news.ycombinator.com/item?id=35394758)).
- *C is for Camera*: 103 points ([thread](https://news.ycombinator.com/item?id=26356496)).
- *spektrafilm* itself got 15 points ([thread](https://news.ycombinator.com/item?id=47761280)); the repo has 997 GitHub stars.

The pattern: HN rewards technical depth ("physically accurate", a simulator of a real process) and dislikes subscriptions.

**How to run it:**
- **Link:** the GitHub repo, with a README hero, sample images and the App Store badge, so people without an iPhone can still see it. A direct App Store link has also worked (Black Hole Vision, Canvify).
- **Title** (80 characters maximum), for example: `Show HN: XA – an open-source iPhone camera with a 2003 digicam and film stocks`
- **First comment from the maker, posted right away:**
  - Who you are (author of Roll for the Light Phone III).
  - The 5 modes in one line each.
  - The technical part: film tables baked from spektrafilm's spectral datasheet model; the deliberately cheap 2003 pipeline (highlight clipping, sharpening halo, chroma noise, hard JPEG); the Lock Screen capture extension and Camera Control.
  - The business model: free, nothing gated, no data collected, GPLv3 plus the App Store exception.
  - Honest limits: iPhone only, iOS 18+, English UI, plus anything else not yet fixed.
  - Ask for feedback.
- **Timing:** the usual advice is Tuesday to Thursday, 7 to 10 am PT ([Pristren guide](https://pristren.com/blog/hacker-news-show-hn-guide), third-party). Plan on launch day, Tue Nov 17.
- **Prepare answers for:** "GPL on the App Store?", "Why not Android?", "Is this just LUTs?", "Why are FILM files ~7 MP?" (fix it first), "Why is it called XA?" (Olympus), and spektrafilm attribution. Credit Andrea Volpato visibly; asking him to share it is your call.

---

## 5. Reddit: rule by rule

Reddit blocks direct fetches, so rules were read through a Redlib mirror on 2026-10-14. Check each sidebar again the day before you post.

| Subreddit | Size | Allowed? | Key rules | What to post | When |
|---|---|---|---|---|---|
| **r/iOSapps** | — | **Yes, tiered** | One promo post per **30 days** (megathread comments count). **Tier 1:** 20+ App Store ratings, 100+ GitHub stars, or recognized flair. **Tier 2:** real identity and contact details **plus a website with a Privacy Policy and Terms of Service**. Otherwise megathread only, in **"ABC" format**: A = problem solved, B = **competitor comparison**, C = pricing and link. Email-verified account; a first interaction that is promotional gets auto-removed. ([mirror](https://redlib.groet-infra.nl/r/iosapps)) | Tier 2 post once terms.html exists. Use the comparison table in section 8. | Wed Nov 18 |
| **r/apple** | — | **Sundays only** | Self-post, not just a link. **At least 5 non-app posts or comments in r/apple in the past month**, self-promo at most 10%. No tweets. Abuse means an immediate ban. ([wiki](https://redlib.groet-infra.nl/r/apple/wiki/rules)) | Text post with the story, the 5 modes and the free/open-source angle. | Sun Nov 22 |
| **r/iphone** | — | **Only after messaging the mods** | "Message us first"; approved developers get a subreddit-wide **developer flair** and can promote or run an AMA ([guidelines](https://redlib.groet-infra.nl/r/iphone/wiki/guidelines)). | AMA: "I built a free, open-source camera with a Lock Screen camera and Camera Control". | After approval |
| **r/iphoneography** | 200k+ | **Careful** | Self-posts must encourage discussion; no spam. Photos first. Mood.camera's beta started here ([TechCrunch](https://techcrunch.com/2024/04/22/mood-camera-is-an-ios-app-that-feels-like-using-a-retro-analog-camera/)). There is a "Top Photo Fridays" thread. ([mirror](https://redlib.groet-infra.nl/r/iphoneography)) | Pre-launch: a TestFlight feedback request with real sample shots, disclosed. Later: photo posts that say they were shot in XA. | Late Oct beta; Fridays |
| **r/SwiftUI** | 64k | **Yes, any day, if source is provided** | Rule 2: apps may be promoted only with source code; open-source promotion is allowed daily ([mirror](https://redlib.groet-infra.nl/r/SwiftUI)). | Code walkthrough: the viewfinder darkroom and the Camera Control pickers. XA has 25 SwiftUI files. | Thu Nov 19 |
| **r/iOSProgramming** | — | **App Saturday only** | One app, **once per year**; include the tech stack; at least 20 subreddit karma in the last 6 months (proposed); describe a technical problem you solved ([summary](https://redlib.hbubli.cc/r/iOSProgramming)). | The LockedCameraCapture memory budget (the 12 MP cap in the extension) and the Core Image pipeline. | Sat Nov 21 |
| **r/opensource** | 389k | Yes | "Promotional" flair, self-promo under 10%, no drive-by posting ([mirror](https://redlib.groet-infra.nl/r/opensource)). | GPLv3 plus the App Store exception, credit to spektrafilm and Roll. | Fri Nov 20 |
| **r/SideProject** | 870k | Yes | Title format `[Project name] - [Short description]`; rewards transparency ([mirror](https://redlib.groet-infra.nl/r/SideProject)). | Build story. | Fri Nov 20 |
| **r/apps** | 124k | Yes, from an established account | "Do not make an account to advertise your app here"; disclose ([mirror](https://redlib.groet-infra.nl/r/apps)). | Short post with disclosure. | Week 2 |
| r/AppHookup | — | **No** | "Always free" apps are banned; deals must be real price cuts, minimum 500 codes ([mirror](https://redlib.groet-infra.nl/r/AppHookup)). | Skip. | — |
| r/photography | 5.7M | **No** | "Any web-development projects or apps are prohibited" ([mirror](https://redlib.groet-infra.nl/r/photography)). | Skip. | — |
| r/analog | 2.7M | **No** | Rule 7: no digital-origin photos; links only in the self-promo thread ([mirror](https://redlib.groet-infra.nl/r/analog)). | Skip. | — |
| r/AnalogCommunity | 470k | **Effectively no** | Rule 9: app posts must be free or open source **and** come from established active members; off-topic is banned ([mirror](https://redlib.groet-infra.nl/r/AnalogCommunity)). A film emulator is likely to get a hostile reception. | Skip unless you're an established member. | — |
| r/digicam, r/DigitalCamera | 5k, 15k | **No** | Help hub and photos from cameras 10 or more years old ([digicam](https://redlib.groet-infra.nl/r/digicam), [DigitalCamera](https://redlib.groet-infra.nl/r/DigitalCamera)). | Skip. Use them as trend research only. | — |
| r/y2kaesthetic | 114k | Off-topic | Focused on Y2K futurism and cybercore, not generic 2000s ([mirror](https://redlib.groet-infra.nl/r/y2kaesthetic)). | Skip. | — |
| r/camcorders | 42k | Off-topic | Real camcorders ([mirror](https://redlib.groet-infra.nl/r/camcorders)). | Skip. | — |

General rules: one account (yours, real identity), disclose that you made it, answer every comment, and never cross-post the same text on the same day.

---

## 6. Press and lists (official tip channels only)

| Outlet | Fit | Channel | Angle |
|---|---|---|---|
| **9to5Mac** | High | tips@9to5mac.com, or the anonymous form at [9to5mac.com/contact](https://9to5mac.com/contact/). Submitting grants permission to publish. | Lock Screen camera and Camera Control in a free, open-source app |
| **TechCrunch** | High (covers indie camera apps) | tips@techcrunch.com for press releases and pitches ([got-a-tip](https://techcrunch.com/got-a-tip/)) | Digicam revival vs. subscription filter apps |
| **Cult of Mac** | Med-high | news@cultofmac.com; app reviews are listed as an opportunity ([source](https://www.cultofmac.com/?p=31514)) | Same as above |
| **AppleInsider** | Med | news@appleinsider.com ([source](https://appleinsider.com/articles/02/10/21/slaptech_acquires_appleinsider)) | Same as above |
| **MacRumors** | Low-med (mostly news) | [macrumors.com/share.php](https://www.macrumors.com/share.php) or tips@macrumors.com | Camera Control angle |
| **The Verge** | Med | tips@theverge.com or [theverge.com/contact](https://www.theverge.com/contact). **Installer** newsletter (app picks): installer@theverge.com ([source](https://www.prismnews.com/news/the-verges-installer-newsletter-spotlights-best-new-apps)) | BOOTH and the video tapes for Installer |
| **Lifehacker** | Med | tips@lifehacker.com (from search; the site blocked fetches, so check it) | "Free alternative to $20/yr retro cam apps" |
| **TidBITS** | Med | Email only, following their [2026 pitch guide](https://tidbits.com/2026/07/23/how-to-pitch-apps-to-tidbits-in-the-ai-era/): subject `PITCH: XA – iPhone camera with digicam, film and booth modes`, no adjectives, plain text, include version, OS, price, links, a press kit and one screenshot. One follow-up after a week, only with news. They warn against AI-sounding phrasing. | General audience, open source |
| **MacStories** | — | **No public tips inbox**; [/about](https://www.macstories.net/about/) lists only editors' personal addresses, which the brief excludes. They write only about apps they have tested themselves. | Don't cold-pitch; let HN and social coverage reach them |
| **iMore** | None | Stopped publishing Sept 30, 2024; the brand is now "iMore Labs" ([TidBITS](https://tidbits.com/2024/09/26/imore-shuts-down-archives-to-remain/)) | Skip |
| **The Sweet Setup** | None | Couldn't verify the site is active (403); its camera pick dates from 2018 ([source](https://www.loopinsight.com/2018/07/10/the-best-third-party-camera-app-for-iphone-halide/)) | Skip |
| **PetaPixel** | High (photo) | tips@petapixel.com (per [Wikipedia](https://en.wikipedia.org/wiki/PetaPixel); the site's [/about](https://petapixel.com/about/) blocked fetches, so check it) | Film modelled from datasheets via spektrafilm; real 2003 digicam artefacts. **Send full-resolution samples, after the FILM fix.** |
| **Fstoppers** | Med | [fstoppers.com/contact](https://fstoppers.com/contact), then "Article Suggestions" | Same as PetaPixel |
| **Gadget Hacks** | Med | Request inclusion in their "[always-updated list of apps that support Camera Control](https://ios.gadgethacks.com/how-to/always-updated-list-apps-support-camera-control-button-iphone-16-series-models-0385633/)" via the site contact | Camera Control |
| **iOS Dev Weekly** | Med (developers) | [suggest.iosdevweekly.com](https://suggest.iosdevweekly.com). Better: write a technical blog post listed in the iOS Dev Directory. | LockedCameraCapture and the Core Image film pipeline |
| **open-source-ios-apps** (GitHub) | Med (lasting) | Pull request adding XA to `contents.json` with the App Store link ([CONTRIBUTING](https://github.com/dkhamsing/open-source-ios-apps/blob/master/.github/CONTRIBUTING.md)) | On launch day |
| **AlternativeTo** | Med (search) | List XA as a free, open-source alternative to Dazz Cam, Huji, NOMO and 1998 Cam ([example page](https://alternativeto.net/software/nomo-cam/about)) | On launch day |

**Press kit** (on gi-os.github.io/XA): a one-paragraph fact sheet (price free, iOS 18+, iPhone only, English UI, GPLv3, no data collected), the 10 screenshots, the icon, a 30 s video, **full-resolution samples** from each mode, App Store and GitHub links, and the support email gio@gi-os.com from `review_notes.txt`.

---

## 7. Social: TikTok, Instagram, Threads

**The trend:**
- Digicams went mainstream through TikTok and Instagram (Bella Hadid, Dua Lipa) ([Back Market](https://backmarket.com/en-us/c/photo-and-video/digicam-trend-nostalgia-social-media)).
- NPR (Jul 18, 2026): Canon PowerShot sales rose nearly sevenfold from 2022 to 2025, and Camp Snap sales more than doubled in a year. People like the "blinding flash", grain and red/orange date stamps, and say it feels more genuine ([Michigan Public/NPR](https://www.michiganpublic.org/2026-07-18/the-2000s-called-they-want-their-digital-camera-back)).
- Japan: the "Heisei retro" boom among Gen Z and purikura used as social content ([galture](https://galture.com/en/trend/purikura-pose-reiwa.html), [Melbourne Asia Review](https://melbourneasiareview.edu.au/the-visual-language-of-japanese-youths-self-expression-and-self-promotion-on-tiktok/)).
- Korea: four-cut photo booths since Life4Cut in 2017 ([SNU Quill](https://snuquill.com/article/108)).

**How the platforms behave:**
- **TikTok Photo Mode carousels** hold 4 to 35 images. Per TikTok data cited by third parties, carousels get 1.9x the likes, 2.9x the comments and 2.6x the shares of video. Slideshows have driven several indie app growth stories ([Kowatek](https://blog.kowatek.com/?p=10590), [PostEverywhere](https://posteverywhere.ai/blog/how-to-make-tiktok-slideshows); third-party).
- **Instagram Trial Reels** show a Reel to non-followers first, but need a public account with **1,000+ followers**, so they won't be available at launch ([Planoly](https://api.planoly.com/blog/instagram-trial-reels), [Tubefilter](https://www.tubefilter.com/2025/01/23/instagram-trial-reels-growth-hacking-creator-economy/)).
- **Threads** has about 500M monthly users ([Gigazine](https://gigazine.net/gsc_news/en/20260617-threads-500-million-mau/)), Communities including **"Photographers of Threads"** ([9to5Mac](https://9to5mac.com/2025/10/02/threads-announces-topic-based-communities/)), and **one topic tag per post** ([Engadget](https://www.engadget.com/threads-introduces-tags-to-help-users-categorize-posts-092650879.html)).

**Content ideas, mapped to the agreed screenshot ids.** Cadence is a planning guess, not researched: about one TikTok a day for 3 to 4 weeks around launch, and 3 Reels a week. End every post the same way: *Free. No subscription. No ads. No account.* Link the matching custom product page.

| Format | Screenshot id | Post idea |
|---|---|---|
| TikTok carousel / IG carousel | **digi**, **dates** | "Party photo dump, but it's an iPhone": flash, clipped highlights, orange quartz date. Also the New Year's Eve push. |
| Side-by-side video | **digi** | A real 2003 PowerShot next to XA DIGI at the same scene, "guess which is which". Expect engaged argument in comments. Show the camera honestly; keep camera brand names out of the App Store. |
| Screen-capture reel | **digi** (live on-screen display) | "POV: your iPhone thinks it's 2003", with the 1/2/3/5 MP switcher. |
| Booth reel / carousel | **booth** | "No photo booth nearby? Four shots, big eyes, sticker sheet." Friends and couples. Strongest for Japan and Korea. |
| Tape montage | **video** | VHS and CCTV for Halloween ("security footage of my cat"); slit-scan and datamosh as weird art. Slit-scan is the effect behind 2020's time-warp-scan craze; don't name that filter in metadata. |
| Finder ASMR | **film** | Rangefinder bright frame, focus patch, advance and shutter sound. Load a stock, pick 110 or half frame, "develop". |
| Recipe carousel | **sims**, **shapes** | "My film sim recipe": the color, curve, split tone and grain values. Post it to Threads Photographers. |
| Feature demo | **lock** | Click Camera Control from the Lock Screen and shoot. Aimed at new iPhone owners at Christmas. |
| Pro shooter short | **pro** | Live histogram, shutter priority, the biggest photo the sensor makes. For r/iphoneography and Threads. |
| Roll reveal | **roll** | Pull down for the contact sheet. Good last slide. |
| Build in public (Threads, Bluesky/Mastodon dev circles) | — | The open-source story, spektrafilm credit, a weekly changelog. |

Ground rules:
- Real photos only, labelled "shot on iPhone in XA".
- If creators get anything of value, they must disclose it.
- Never compare against competitors in App Store metadata; it's fine in social posts and the r/iOSapps comparison block when the facts are accurate.

---

## 8. Competitors (checked on the US App Store today)

| App | Model |
|---|---|
| Dazz Cam ([store](https://apps.apple.com/us/app/dazz-cam-old-film-vhs-cam/id1502071279)) | Pro $2.99/wk, $4.99/mo, $19.99/yr, $49.99 one-time |
| NOMO CAM ([store](https://apps.apple.com/us/app/nomo-cam-point-and-shoot/id1362548649)) | NOMO PRO $24.99/yr, plus $0.99 to $1.99 camera packs |
| 1998 Cam ([store](https://apps.apple.com/us/app/1998-cam-vintage-camera/id1450480287)) | $1.99 to $5.99/mo, $15.99 to $29.99/yr, $39.99 lifetime |
| Hipstamatic ([store](https://apps.apple.com/us/app/hipstamatic-x-analog-camera/id1450672436)) | Camera Club $7.99, $19.99 or $29.99 |
| Huji Cam ([store](https://apps.apple.com/us/app/id781383622)) | $0.99 "Extra Options"; small brand ads |
| KD Pro ([search summary](https://apps.apple.com/app/kd-pro-disposable-camera/id1291297394)) | Free; the premium upgrade removes ads (price not confirmed) |
| Mood.camera ([TechCrunch](https://techcrunch.com/2024/04/22/mood-camera-is-an-ios-app-that-feels-like-using-a-retro-analog-camera/)) | $1.99/mo or $14.99 one-time (2024) |
| **XA** | **Free, every feature, no subscription, no ads, open source** |

The category is crowded in 2026 (Retro Cam Neo, Retrocam, Hay Cam, Y2K Cam and others). Five cameras in one app plus open source is the clearest way to stand apart.

---

## 9. Product Hunt (low priority)

**Official guidance:**
- Launch at 12:01 am PT. Tagline at most 60 characters. Gallery images 1270x760 (at least 2). Thumbnail 240x240. Video via YouTube; 53% of Product of the Day winners since 2021 had one.
- **70% of Day, Week or Month winners had a first comment from the maker.**
- Weekend launches get 15% more "Visit" clicks, and smaller projects do better on weekends.
- You can schedule up to a month ahead. There's "no discernible advantage" to a third-party hunter.
- Don't ask for upvotes; ask people to visit and comment.
- Sources: [launch guide](https://www.producthunt.com/launch), [preparing](https://www.producthunt.com/launch/preparing-for-launch).

**Reality (third-party):** only about 10% of launches get featured, and accounts are weighted by age ([Awesome Directories](https://awesome-directories.com/blog/product-hunt-launch-guide-2025-algorithm-changes)). Recent retro camera apps:
- Y2K Cam: 4 upvotes ([PH](https://www.producthunt.com/products/y2k-cam-retro-digicam-film))
- NiCam: #135, 3 upvotes ([hunted.space](https://www.hunted.space/product/nicam))
- Phocus: #157 ([hunted.space](https://www.hunted.space/product/phocus-2))
- Golden Hour: #151 ([hunted.space](https://www.hunted.space/product/golden-hour-3))

**Plan:** hunt it yourself on Sat Nov 21 or Sun Nov 22. Example tagline (54 characters): *"A free, open-source iPhone camera: digicam, film, booth."* Post the maker comment immediately. Expect a backlink, not downloads.

---

## 10. Japan and Korea

The app interface is English only. Localize the **store listing and screenshot captions** and say "App in English". Apple's featuring criteria give extra weight to in-app localization.

**Japan:**
- **Hooks:** "Heisei retro", old compact digicams, purikura (BOOTH, with the Mochiy Pop One deco).
- **Press:**
  - **Digital Camera Watch:** dc-watch@impress.co.jp for releases ([source](https://dc.watch.impress.co.jp/docs/common/contact.html))
  - **iPhone Mania:** contact and press-release forms via [iphone-mania.jp/contact/](https://iphone-mania.jp/contact/)
  - **AppBank:** app-review request form; historically about a month of backlog ([source](https://www.appbank.net/?p=142715))
  - Gizmodo Japan: no general tips form found
  - Appllio, which has reviewed Huji Cam ([source](https://appllio.com/app-hujicam)): contact not checked
- **Community:** X with #個人開発 and #iPhoneアプリ, plus a Zenn or Qiita technical article. PR TIMES eligibility is unverified.

**Korea:**
- **Hook:** the 인생네컷 four-cut booth culture fits BOOTH; 디카 감성 fits DIGI.
- **Clien:** in the 개발한당 developer group, a promotional first post from an inactive member gets deleted, while active members may share their own apps with commentary ([Clien](https://www.clien.net/service/board/cm_app/15199283)). There is also a 직접홍보 (direct promotion) board ([rules](https://www.clien.net/service/board/rule/10707403)).
- **ZDNet Korea:** editorial contacts at [zdnet.co.kr/corporation/sub3.html](https://zdnet.co.kr/corporation/sub3.html). Other Korean outlets weren't checked.

**Timing:** a nomination with the ja and ko localizations, aimed at graduation season (Korea in February, Japan in March).

---

## 11. What success looks like

**Track:**
- App Store Connect campaign tokens for each channel
- Product page conversion on each custom page
- HN rank and comments
- GitHub stars (100 unlocks r/iOSapps Tier 1)
- 20 ratings (the other route to r/iOSapps Tier 1)
- Whether Apple's "App of the Day" notification ever fires

**Avoid:**
- Vote rings or asking friends to upvote (HN, PH and Reddit all penalize it)
- Posting the same text everywhere on the same day
- Launching or pitching during Thanksgiving week or Dec 23 to 27
- Any "full resolution" FILM claim before the fix ships
- Mentioning the tip jar before it's in the build
