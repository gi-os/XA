# XA launch kit

Drafted for the App Store launch. Honest, no invented numbers or quotes: check every line before you post it.

## Timeline

- **Wed Oct 14 – Mon Oct 19: fixes in the build**: Remove 'Olympus' from the in-app string at XA/UI/CustomizeView.swift:131 and describe the finder generically. Add an About group to Customize with the privacy policy, support email, source code and licenses (guidelines 5.1.1(i) and 1.5). Check the drum scan on a real 48 MP iPhone and a 12 MP iPhone, then keep or soften the resolution copy. Confirm that no spektrafilm source code was ported into Swift (only the baked tables ship); the Show HN post says so. Decide the store version number (project.yml says 0.15.3). Tag the exact source of the submitted build in git.
- **Wed Oct 14 – Mon Oct 19: web and text**: Add docs/terms.html (needed for the r/iOSapps Tier 2 post). Add a tips paragraph and a retention line to docs/privacy.html. Change 'pull down for the roll' to 'swipe up under the viewfinder, or tap the roll button' in review_notes.txt, docs/index.html and README.md. Change 'iPhone 16 and later' to 'an iPhone with Camera Control' everywhere. Rewrite the README (five cameras, 1 to 12 MP, screenshots, App Store badge) and point marketing_url.txt to https://gi-os.github.io/XA/. Build the landing page from this kit.
- **Wed Oct 14 – Wed Oct 21: App Store Connect**: Create the three tip consumables (com.gios.xa.tip.small, .medium, .large) with display names of 30 characters or fewer, descriptions of 45 or fewer and a review screenshot of the tip screen; without them the tip jar stays hidden and the tip lines are untrue. Set App Privacy to Data Not Collected. Answer the age rating questions (expected 4+, Unrestricted Web Access: No). Declare EU DSA trader status. Complete the Paid Apps Agreement, banking and tax. Turn off Mac and Apple Vision Pro availability and China mainland. Answer content rights 'yes, I have the rights'.
- **Thu Oct 15 – Wed Oct 21: store assets**: Capture the 10 screenshots on a real iPhone (digi, film, video, booth, sims, pro, dates, shapes, lock, roll) at 1320×2868 and 1206×2622, with the final captions. Get releases for every face. Record one or two 15 to 30 second app previews (886×1920, screen captures only). Add the en-GB and other planned localizations from the keyword research.
- **Thu Oct 22 (target)**: Submit the app version and all three tips in the same submission, with manual release. Review notes must say where the tips are and that they unlock nothing.
- **By Tue Oct 27**: Submit the App Launch featuring nomination for Nov 17 (Apple asks for at least three weeks). Use the text in this kit; add accessibility facts after a VoiceOver pass.
- **Oct 15 – Nov 16: groundwork**: Build genuine comment history on r/apple (5+ non-app posts or comments in the month before Nov 22) and r/iOSProgramming (about 20 karma). Message the r/iphone mods for developer flair. Start the X, Threads, Instagram and Bluesky accounts. Build the press kit page (fact sheet, screenshots, icon, 30 s video, full-size samples from each mode). Prepare honest answers for Hacker News: GPL on the App Store, 'is this just LUTs', file sizes, and why it's called XA.
- **Sat Oct 31**: Halloween teaser on social: a VHS and CCTV tape clip with 'Out Nov 17'. No App Store link yet.
- **After approval (late Oct to early Nov)**: Optionally set up a pre-order so press gets a live App Store link. Create custom product pages with keywords: DIGI, FILM, BOOTH and VIDEO. Make an App Store campaign link (ct= token) for each channel: hn, ph, rdt-iosapps, rdt-apple, tiktok, ig, threads, bsky, press. Add the Smart App Banner to the website.
- **Tue Nov 10**: Send the press pitch to the outlets in this kit, with the TestFlight or pre-order link and the press kit. No pitches go to personal addresses.
- **Mon Nov 16**: Final check: re-read the rules of each subreddit, check every link, make sure the sample gallery and press kit are live, and draft the HN post.
- **Tue Nov 17: launch day**: Release the app manually in the morning. Post Show HN at about 7 to 9 am PT and stay in the thread all day; don't ask anyone for upvotes. Post the launch posts on X, Threads, Instagram and Bluesky. Send a short launch-day note to the outlets that didn't reply. Open the pull request to open-source-ios-apps, list XA on AlternativeTo, and ask Gadget Hacks to add XA to their Camera Control list.
- **Wed Nov 18**: r/iOSapps post (Tier 2 if terms.html is live, otherwise the megathread), in the ABC format.
- **Thu Nov 19**: r/SwiftUI code walkthrough post.
- **Fri Nov 20**: r/opensource post with the Promotional flair.
- **Sat Nov 21**: r/iOSProgramming App Saturday post. Launch on Product Hunt at 12:01 am PT and post the maker comment right away. Expect a backlink, not many downloads.
- **Sun Nov 22**: r/apple Self-Promotion Sunday post.
- **Mon Nov 23**: r/SideProject post. Reply to App Store reviews and GitHub issues, and keep doing so every day.
- **Tue Nov 24 – Fri Nov 27: US Thanksgiving week**: No pitches or launches. Review may be slower, so submit an urgent bug fix early in the week or wait. By Fri Nov 27, submit a second featuring nomination (App Enhancement or holiday content) aimed at mid-December.
- **Mon Nov 30**: r/apps post from your established account, with disclosure. Post the r/iphone AMA on the date the mods agreed.
- **Tue Dec 1: two weeks after release**: Review the results: campaign-link counts per channel, product page conversion per custom page, ratings (20 opens r/iOSapps Tier 1), GitHub stars (100 opens Tier 1), Hacker News outcome and crash reports in App Store Connect. Create $0 Apple Ads draft campaigns to read search popularity for the main keywords. Plan version 1.1 and its What's New text. Plan the holiday social wave (Dec 18 – Jan 2) and the Japan and Korea wave (Jan to Mar 2027).

## App Store featuring nomination

App Store Connect › Featuring Nominations.

App Store Connect › XA › Featuring › Nominations › + › Create Nomination

TYPE: App Launch

NOMINATION NAME: XA: five cameras for iPhone, nothing to unlock

PUBLISH DATE: November 17, 2026

PLATFORM: iOS (iPhone)

COUNTRIES OR REGIONS: [Every storefront where XA is available. China mainland is off at launch.]

LOCALIZATIONS: [The store listings that are live by Nov 17. The app's interface is English.]

DESCRIPTION:
XA is a camera app for iPhone with five cameras in one app. Every mode except PRO shows its look live in the viewfinder.

- DIGI is a 2003 point-and-shoot: 1 to 12 megapixels, with clipped highlights, a sharpening halo, color noise and a hard JPEG, plus editable film sims, nine looks, shapes and eight date backs.
- FILM loads one of eleven film stocks in 110, half frame, 35mm or 120. It has a rangefinder-style finder with a bright frame and focusing patch, flash, light leaks, a mist filter and lab printing (auto-correction, warmth, tint, preflash). By default it saves a drum-scan-sized HEIC file.
- VIDEO has twelve tapes, from VHS and an 8mm home movie to CCTV, slit-scan and datamosh.
- BOOTH is a Japanese-style photo-sticker booth: four shots with the front camera, big eyes and a sticker sheet.
- PRO is the iPhone at full quality: the biggest photo the sensor makes, as HEIF or JPEG, with a live histogram, manual white balance, exposure, shutter, ISO and focus, and shutter and ISO priority.

Every feature is in the free download. There is no subscription, no advertising, no account and no watermark. Optional tips unlock nothing. XA collects no data; its privacy label is Data Not Collected. Pictures are saved to Photos in an XA album. XA is open source under the GNU GPL version 3.

HELPFUL DETAILS:
- What makes it different: five distinct cameras in one app, with nothing locked. The film is modeled from published datasheets: color stocks are developed through tables made with spektrafilm (an open-source spectral film simulation), and grain and halation are sized in microns on the negative, so they change with the format.
- Apple technologies: a Lock Screen camera built on LockedCameraCapture, which opens with the app's own settings passed in the capture intent; a Control Center and Lock Screen control (WidgetKit and App Intents) that also makes XA a Launch Camera choice for Camera Control and can go on the Action button; Camera Control through AVCaptureControl, with pickers for sims and looks in DIGI, stocks in FILM and tapes in VIDEO, and sliders for exposure and zoom in PRO; the volume buttons as a shutter through AVCaptureEventInteraction; a Metal viewfinder that renders Core Image frames on the camera's queue; StoreKit 2 for the tips.
- Privacy: no account, no server, no analytics, no tracking.
- Accessibility: [Fill in after a VoiceOver pass. Today, VoiceOver labels exist on the main camera controls, the roll and the PRO dials. Don't claim more than that.]
- Localization: [List the store localizations. The interface is English.]
- Timing: new iPhone owners setting up Camera Control over the holidays, and party photos for New Year's Eve.

SUPPLEMENTAL URLS (up to 5):
1. https://github.com/gi-os/XA
2. https://gi-os.github.io/XA/
3. [Sample gallery with full-size photos from each mode]
4. [App preview video]
5. https://gi-os.github.io/XA/privacy.html

## Product Hunt

**Tagline:** An open-source iPhone camera: digicam, film, VHS, booth

**Topics:** Photography, iOS, Open Source, Video

**Description**

XA is an iPhone camera with five modes: a 2003 digicam, a film camera you load and print, twelve video tapes, a photo-sticker booth and a manual PRO camera. Every feature included. No subscription, no ads, no account, no tracking. Open source.

**First comment**

Hi Product Hunt, I'm Giovanni, and I made XA.

[One or two lines on why you built it, in your own words.]

XA is five cameras in one iPhone app:
• DIGI: a 2003 point-and-shoot. 1 to 12 MP, clipped highlights, a sharpening halo, color noise, a hard JPEG and an orange date in the corner.
• FILM: eleven stocks in 110, half frame, 35mm or 120, with a rangefinder-style finder, light leaks, a mist filter and lab printing.
• VIDEO: twelve tapes, from VHS and an 8mm home movie to CCTV, slit-scan and datamosh.
• BOOTH: a photo-sticker booth. Four shots, big eyes, a sticker sheet.
• PRO: the biggest photo the sensor makes, a live histogram and manual dials.

A few things that matter to me:
• Everything is in the free download. There's no subscription, no ads, no account and no watermark. The optional tips unlock nothing.
• Nothing is collected. XA has no server and no analytics.
• It's open source under GPLv3: github.com/gi-os/XA
• It works with the iPhone's buttons: a Lock Screen camera, Control Center, Camera Control (slides through looks, stocks and tapes) and the volume buttons.

Limits: iPhone only, iOS 18 or later, English interface.

I'd like to hear which mode you use most, and what breaks. Bug reports go to github.com/gi-os/XA/issues.

## Show HN

**Title:** Show HN: XA – open-source iPhone camera with a 2003 digicam and modelled film

Hi HN. XA is an iPhone camera app I've been building. The source is on GitHub under GPLv3, and the App Store build is free with nothing gated: no subscription, no ads, no account, no analytics. There's an optional tip jar that unlocks nothing.

It has five modes:

- DIGI: a 2003 point-and-shoot. The sensor is read at 12 MP and shrunk to the 1–12 MP you pick, then put through the faults a cheap camera's processor had, in roughly its order: a CCD color cube (cyan skies, hot reds, an S-curve that clips hard), flash falloff, noise reduction that smears detail and leaves chroma blotches, a slightly bad zoom lens (barrel, soft corners, lateral color), an unsharp mask with a halo, and one pass through a low-quality JPEG before the real save.

- FILM: eleven made-up stocks in 110, half frame, 35mm and 120, with a rangefinder-style finder, flash, light leaks, a mist filter and lab printing (auto-correction, warmth, tint, preflash).

- PRO: the iPhone without the costume. The biggest photo the sensor makes, HEIF or JPEG, a live histogram, manual WB/EV/shutter/ISO/focus, shutter and ISO priority.

- VIDEO: twelve "tapes" (VHS, 8mm, CCTV, slit-scan, datamosh and others).

- BOOTH: a Japanese-style photo-sticker booth. Front camera, four shots, big eyes, a sticker sheet.

Some parts that might be interesting:

Film. For the color stocks I use spektrafilm (Andrea Volpato's spectral film simulation built from published datasheets) to bake two tables per stock: scene light to negative density, and negative density to print. Everything that depends on neighbouring pixels runs on the phone in Core Image around those tables: scatter and halation, the first table, couplers as local contrast, dye blur, grain, the print table, then scan sharpening. The effect strengths were fitted against spektrafilm's full simulation. On one stock and two test photos, the tables alone came within a mean ΔE2000 of 0.10 of its per-pixel model, and the whole phone path was at a mean ΔE of about 1.6–1.7 with grain off. The scripts are in tools/filmsim. Grain is three layers (the blue one coarser), each a fast coarse emulsion under a slow fine one, and all sizes are in microns on the negative, so a 110 frame is grittier than a 120 frame at the same output size. The three black-and-white stocks use my own tables, shaped like published curves.

Scanning. By default FILM scans the negative at 4.5 µm per pixel (about 5600 dpi), capped at 48 MP, so a 35mm frame comes out near 8000×5333. To be clear about what that means: on a 48 MP iPhone it starts from the sensor's full photo; on a 12 MP one the frame is enlarged first and the grain is generated at scan size, so zooming in shows grain instead of interpolation mush. It isn't more captured detail. A 3088 px lab scan is still an option. Getting there meant working around Core Image: asked to render a 40 MP frame in one go for metering, it wanted about 860 MB, refused, and the photo came out black. Now the metering, the levels proxy and the glare read a small copy drawn in bands, and the encoder writes anything past 16 MP in tiles.

Viewfinder. Developed Core Image frames are drawn straight into a Metal layer on the camera's frame queue, so the preview keeps moving while SwiftUI is busy. Sims, looks, shapes and date backs show live; DIGI's lens, noise, sharpening and JPEG faults are applied only to the saved photo.

Lock Screen and buttons. The Lock Screen camera is a LockedCameraCapture extension. It can't read the app's settings, so the app passes the recipes, loaded films and date backs in the capture intent's app context, which is limited to 4 KB. The extension opens the camera at once and keeps the viewfinder dark until the settings arrive, so it doesn't open in one mode and then switch. In the extension, FILM saves the lab scan and capture stays at 12 MP. Camera Control uses AVCaptureIndexPicker for sims and looks in DIGI, stocks in FILM and tapes in VIDEO, and sliders for exposure and zoom in PRO. The volume buttons go through AVCaptureEventInteraction.

Smaller things: the AF motor and shutter sounds are synthesized at launch by a tiny offline synth. The POCKET 3D tape records a 480×240 band at 20 fps (10 in the dark) with 16 kHz 4-bit ADPCM mono sound.

Licensing: GPLv3 with a section 7 additional permission (EXCEPTION.md) that allows App Store and TestFlight distribution as long as the complete source is public. The app ships spektrafilm's baked tables (CC BY-SA 4.0, credited in the app), not its code.

XA started as an iOS port of Roll, a camera I wrote for the Light Phone III.

Limits: iPhone only, iOS 18+, English-only interface. No RAW output: PRO saves HEIF or JPEG, though FILM can develop from RAW on iPhones that shoot it.

I'd like feedback on the film rendering, especially from people who shoot and scan real film, and on anything that breaks. Issues: https://github.com/gi-os/XA/issues

App Store: [App Store link]

## Reddit

### r/iOSapps

_Rules:_ One promo post per 30 days, and megathread comments count toward it. A standalone post needs Tier 1 (20+ App Store ratings, 100+ GitHub stars, or recognized flair) or Tier 2 (real identity and contact details plus a website with a Privacy Policy AND Terms of Service). XA has no terms page yet: add docs/terms.html first, or post this as a megathread comment. The post must use the ABC format (A = problem solved, B = competitor comparison, C = pricing and link). The account must be email-verified, and a first interaction that is promotional is auto-removed, so comment normally first. Re-read the sidebar the day before. Planned: Wed Nov 18.

**[Dev] XA: five cameras in one iPhone app (2003 digicam, film, VHS tapes, sticker booth, PRO), nothing to unlock**

I'm the developer. In the sub's ABC format:

**A) What it does**

XA is five cameras in one iPhone app:

- **DIGI:** a 2003 point-and-shoot. 1 to 12 MP, clipped highlights, a sharpening halo, color noise, a hard JPEG and eight date backs.
- **FILM:** 11 stocks in 110, half frame, 35mm or 120, a rangefinder-style finder, light leaks, a mist filter and lab printing.
- **VIDEO:** 12 tapes (VHS, 8mm, CCTV, slit-scan, datamosh and more).
- **BOOTH:** a photo-sticker booth. Four shots, big eyes, a sticker sheet.
- **PRO:** the biggest photo the sensor makes, a live histogram and manual dials.

It also works as a Lock Screen camera, from Control Center and from the Camera Control button.

**B) Compared with similar apps**

I checked these on the US App Store on 14 Oct 2026. Dazz Cam, NOMO CAM, 1998 Cam and OldRoll sell paid plans or camera packs for their full set of cameras, and 1998 Cam and Huji Cam show ads. XA has everything in the free download, with no ads, no account and no watermark. Its privacy label is Data Not Collected, and the code is open source (GPLv3).

Where they're ahead: Dazz Cam has many more camera presets and a long update history. XA is iPhone only, and its interface is English only.

**C) Price and link**

Free. Optional tips in Customize unlock nothing. iPhone with iOS 18 or later.

- App Store: [App Store link]
- Source: https://github.com/gi-os/XA
- Privacy policy and terms: https://gi-os.github.io/XA/

### r/apple

_Rules:_ Self-promotion is allowed only on Sundays, as a self-post (text, not a bare link). You need at least 5 non-app posts or comments in r/apple in the past month, and self-promotion must stay under 10% of your activity. No tweets. Abuse means an immediate ban. Start commenting normally now. Planned: Sun Nov 22.

**I made XA, a free and open-source camera app with five cameras, a Lock Screen camera and Camera Control support**

Hi r/apple. I'm Giovanni, and I made XA, a camera app for iPhone. It's free with every feature included: no subscription, no ads, no account, and it collects no data. The source is on GitHub under GPLv3.

It's five cameras in one app:

- **DIGI:** a 2003 point-and-shoot. 1 to 12 MP, clipped highlights, CCD color, a hard JPEG and an orange date in the corner.
- **FILM:** load one of eleven stocks, shoot 110 to 120, and time the print like a lab.
- **VIDEO:** twelve tapes, from VHS to datamosh.
- **BOOTH:** a photo-sticker booth with four shots and a sticker sheet.
- **PRO:** the biggest photo the sensor makes, with a live histogram and manual dials.

The parts that use iOS features:

- A Lock Screen camera (LockedCameraCapture). It opens with the app's settings, so it's the same camera you left.
- A Control Center control, which can also go on the Lock Screen or the Action button.
- On an iPhone with Camera Control, XA can be the button's camera (Settings › Camera › Camera Control › Launch Camera). The button slides through sims and looks in DIGI, stocks in FILM, tapes in VIDEO, and exposure and zoom in PRO.
- The volume buttons shoot, and QR codes open from the viewfinder.
- Everything saves to Photos in an XA album, so iCloud Photos backs it up.

Limits: iPhone only, iOS 18 or later, English interface.

App Store: [App Store link]
Source: https://github.com/gi-os/XA

Feedback is welcome, especially on Camera Control and the Lock Screen camera.

### r/SwiftUI

_Rules:_ Rule 2: an app may be promoted only if its source code is provided. Open-source promotion is allowed on any day. Lead with the code, not the store link. Planned: Thu Nov 19.

**XA: an open-source SwiftUI camera app (Metal viewfinder, keylined digicam display, Camera Control)**

XA is an open-source iPhone camera app (GPLv3). The UI is SwiftUI, capture is AVFoundation, and every picture is developed in Core Image. A few parts that might help if you're building camera UI:

- **Viewfinder** (`XA/UI/PreviewView.swift`): an MTKView in a UIViewRepresentable. Developed Core Image frames are drawn straight into it on the camera's frame queue, not the main thread, so the preview keeps moving while SwiftUI is busy with a mode switch or a sheet. The same representable turns the volume buttons and a Camera Control click into the shutter.
- **Digicam display** (`XA/UI/DigicamOSD.swift`): DIGI's screen copies a 2005 digicam's LCD type. The hard black keyline all round is eight offset copies of the text under the white one, not a shadow. It's laid out on a 390-point-wide finder and scaled.
- **Rangefinder markings** (`XA/UI/XAFinderView.swift`): an Equatable view, so the markings are drawn once per size and format instead of every frame.
- **Mode ribbon** (`XA/UI/Collar.swift`): works like the system camera's. Swipe the deck sideways or tap a name.
- **Roll** (`XA/UI/RollTable.swift`): shots laid out as prints on a table, with photos taken close together clipped into piles.

Source: https://github.com/gi-os/XA
App Store (free, nothing to unlock): [App Store link]

Code review is welcome, especially on the representable and how the preview talks to SwiftUI.

### r/iOSProgramming

_Rules:_ App Saturday only. One app, once per year. Include the tech stack and describe a technical problem you solved. Needs about 20 subreddit karma in the last 6 months, so participate before then. Planned: Sat Nov 21.

**App Saturday: XA, an open-source camera app (LockedCameraCapture, Camera Control, a Core Image film pipeline)**

XA is five cameras in one iPhone app: a 2003 digicam, film stocks, video tapes, a photo-sticker booth and a manual PRO camera. Free, nothing gated, GPLv3.

**Tech stack:** Swift, SwiftUI, AVFoundation, Core Image with a Metal-backed viewfinder (MTKView), LockedCameraCapture for the Lock Screen camera, WidgetKit controls and App Intents for Control Center and the Camera Control launch, AVCaptureControl for the Camera Control pickers, AVCaptureEventInteraction for the volume buttons, StoreKit 2 for optional tips, XcodeGen and fastlane for builds.

**Two problems I had to solve:**

1. **Large Core Image renders.** FILM now saves a drum-scan-sized file, up to 48 MP. Asked to render a 40 MP frame in one go for the lab's metering, Core Image wanted about 860 MB, refused, and the photo came out black. The fix: everything that reads the whole frame (metering, the scanner's levels, glare) reads a small copy drawn in bands, and the encoder writes images past 16 MP in tiles.

2. **Settings in the Lock Screen camera.** The capture extension can't read the app's settings. So the app puts what shapes a picture (the DIGI and FILM recipes, date backs, loaded films, flash, sounds) in the capture intent's app context, which is limited to 4 KB. The extension opens the camera at once and keeps the viewfinder dark until those settings arrive, so it never opens in one mode and switches. In the extension, FILM saves the smaller lab scan and capture stays at 12 MP, to stay inside its memory budget.

Source: https://github.com/gi-os/XA
App Store: [App Store link]

Happy to answer questions on any of it.

### r/opensource

_Rules:_ Use the Promotional flair. Keep self-promotion under 10% of your activity, and no drive-by posting: stay and answer. Planned: Fri Nov 20.

**XA: a GPLv3 iPhone camera app, with a section 7 permission so it can ship on the App Store**

XA is an iPhone camera app I've released under the GNU GPL version 3. It has five modes: a 2003 digicam, film stocks, video tapes, a photo-sticker booth and a manual PRO camera.

The App Store and the GPL don't mix on their own: the store's terms add restrictions the GPL doesn't allow, which is how VLC was pulled in 2011. As the only copyright holder of XA's own code, I added a section 7 additional permission (`EXCEPTION.md`): anyone may convey XA through the App Store or TestFlight, as long as the complete corresponding source is public under the GPL and the same permission. Code from other projects keeps its own license.

Credits:

- Film modeling is powered by spektrafilm, Andrea Volpato's GPLv3 spectral film simulation. XA ships tables baked with it (CC BY-SA 4.0, credited in the app). The scripts that bake them and fit the effects are in `tools/filmsim`.
- XA started as an iOS port of Roll (MIT), my camera for the Light Phone III.
- The fonts are OFL 1.1 and Apache 2.0, with the license texts shipped in the app.

The app is free with nothing gated, no ads and no analytics.

Repo: https://github.com/gi-os/XA
App Store: [App Store link]

I'd like feedback on the permission's wording from anyone who has shipped GPL code on the App Store.

### r/SideProject

_Rules:_ The title must follow the format [Project name] - [Short description]. The sub rewards transparency: say what it is, what it cost you to build, and how it's funded. Post on a different day from r/opensource. Planned: Mon Nov 23.

**XA - a free, open-source iPhone camera with five cameras in one app**

XA started as an iOS port of Roll, a camera I made for the Light Phone III. It grew into five modes:

- **DIGI:** a 2003 point-and-shoot. 1 to 12 MP, clipped highlights, a sharpening halo, color noise and an orange date.
- **FILM:** eleven stocks in 110, half frame, 35mm or 120, a rangefinder-style finder and lab printing.
- **VIDEO:** twelve tapes, from VHS to datamosh.
- **BOOTH:** a photo-sticker booth. Four shots, big eyes, a sticker sheet.
- **PRO:** the biggest photo the sensor makes, with manual dials.

What it took:

- Film tables baked with spektrafilm, an open film simulation, and effects fitted against it on a laptop before they were rewritten for Core Image.
- A Lock Screen camera extension that gets the app's settings through a 4 KB hand-off.
- A drum-scan mode that needed banded and tiled rendering so 40 MP frames don't come out black.

How it's funded: it isn't, really. Every feature is free, with no ads, no account and nothing collected. There are optional tips that unlock nothing. The code is GPLv3.

[One or two lines on why you built it, in your own words.]

App Store: [App Store link]
Code: https://github.com/gi-os/XA

Feedback is welcome, especially from people who've used old digicams or shot film.

### r/iphone

_Rules:_ Developers must message the mods first. Approved developers get a subreddit-wide developer flair and may promote or run an AMA. Do not post until the mods approve. Send the request now; post on the date they agree to.

**AMA: I built XA, a free, open-source camera that works from the Lock Screen and Camera Control**

Hi r/iphone. I'm Giovanni, the developer of XA (the mods approved this AMA).

XA is five cameras in one app: a 2003 digicam (DIGI), film stocks you load and print (FILM), twelve video tapes (VIDEO), a photo-sticker booth (BOOTH) and the iPhone at full quality with manual dials (PRO).

You can make it the iPhone's camera:

- On an iPhone with Camera Control: Settings › Camera › Camera Control › Launch Camera › XA. The button then slides through sims and looks, stocks, tapes, or exposure and zoom, depending on the mode.
- On the Lock Screen and in Control Center, as a control.
- The volume buttons shoot.

It's free with every feature included, with no ads, no account and no tracking. Photos go to the Photos app in an XA album. It's open source: https://github.com/gi-os/XA

App Store: [App Store link]

Ask me anything about how it works or what's coming.

### r/apps

_Rules:_ Post only from an established account: the rules say not to make an account to advertise an app. Disclose that you're the developer. Planned: Mon Nov 30.

**XA – a free iPhone camera with a 2003 digicam, film, VHS tapes and a photo-sticker booth (I'm the developer)**

I made XA, a camera app for iPhone with five modes:

- **DIGI:** a 2003 point-and-shoot, 1 to 12 MP, with clipped highlights, color noise and an orange date.
- **FILM:** eleven film stocks, 110 to 120, with lab printing.
- **VIDEO:** twelve tapes, from VHS to datamosh.
- **BOOTH:** four shots on a sticker sheet.
- **PRO:** full-size photos with manual controls.

Everything is in the free download: no subscription, no ads, no account, no watermark. It's open source (GPLv3). iPhone with iOS 18 or later; the interface is in English.

App Store: [App Store link]

I'd like to hear what you think.

### r/iphoneography

_Rules:_ Photos come first. Self-posts must encourage discussion, and spam is removed. Post real photos shot in XA, disclose that you made the app, and keep the link in a comment if the sidebar asks. Don't repeat the post; use the Top Photo Fridays thread for later photos.

**One street, five cameras in one app: digicam, film, VHS frame, booth and PRO (I made the app, feedback welcome)**

These are all from the same walk, shot on iPhone in XA, an app I made. Each photo is a different mode:

1. DIGI: the 2003 point-and-shoot at 3 MP with the flash on.
2. FILM: a 400 color stock on half frame.
3. VIDEO: a still frame from the VHS tape.
4. BOOTH: a sticker sheet.
5. PRO: the full-size photo with the manual dials.

[Update the list to match the photos you post.]

I'd like to hear which ones work for you and which don't, especially from anyone who shoots film. The app is free with nothing to unlock and the code is open source; the link is in the comments.

## Social

### X

XA is out for iPhone: five cameras in one app. A 2003 digicam, a film camera you load and print, twelve video tapes, a photo-sticker booth and a manual PRO camera.

Free, every feature included. No subscription, no ads, no account, no tracking. Open source.

[App Store link]

### X (thread, 4 posts)

1/4 How XA's film works. Each color stock is two tables baked with spektrafilm, an open spectral film simulation built from published datasheets: scene light to negative density, and negative to print. Everything between them runs on the phone in Core Image.

2/4 Before the first table: scatter and halation. Between the tables: couplers as local contrast, dye blur and grain. Grain comes in three layers, the blue one coarser, sized in microns on the negative. So a 110 frame is grittier than a 120 frame at the same output size.

3/4 The default FILM file is a drum scan: 4.5 µm of negative per pixel, about 5600 dpi, up to 48 MP. On a 12 MP iPhone the frame is enlarged first and the grain is made at scan size. Zooming in shows grain, not mush. It is not extra captured detail.

4/4 The code, the film tables and the scripts that fitted the effects against spektrafilm's full simulation are on GitHub under GPLv3: github.com/gi-os/XA

Film modeling powered by spektrafilm, by Andrea Volpato.

### X

On an iPhone with Camera Control, XA can be the button's camera. Slide through sims and looks in DIGI, stocks in FILM, tapes in VIDEO, and exposure and zoom in PRO. Click to shoot, from the Lock Screen too.

Settings › Camera › Camera Control › Launch Camera › XA

### X

DIGI in XA is a 2003 point-and-shoot on your iPhone: 1 to 12 megapixels, clipped highlights, a sharpening halo, color noise, a hard JPEG and an orange date in the corner. Turn each flaw up, down or off.

Free, nothing to unlock. [App Store link]

### Threads

XA is out for iPhone, and it's five cameras in one app.

DIGI: a 2003 point-and-shoot. Clipped highlights, CCD color, an orange date in the corner.
FILM: load a stock, shoot 110 to 120, time the print.
VIDEO: twelve tapes, from VHS to datamosh.
BOOTH: four shots, big eyes, one sticker sheet.
PRO: the whole sensor, with manual dials.

Free, every feature included. No subscription, no ads, no account. Open source.

[App Store link]

(One topic tag: iPhone Photography)

### Threads (Photographers of Threads community)

Sim recipe thread. In XA's DIGI mode you can open any film sim and change its color, tone curve, split tone, grain, halation and vignette, then save it as your own.

Mine for night streets: [your values: color, curve, split tone, grain, halation, vignette].

Post yours with a photo and I'll try them.

(One topic tag: Film Photography)

### Threads

No sticker booth nearby? XA's BOOTH mode uses the front camera: four shots on a countdown, big eyes and glowing skin (Glow, Doll or Alien), a new backdrop and neon doodles on every shot, then one sticker sheet, grid or strip.

It's in the free download with everything else. [App Store link]

### Instagram (carousel caption, slides: digi, film, video, booth, pro, roll)

Five cameras, one iPhone app.

1. DIGI, a 2003 digicam
2. FILM, eleven stocks from 110 to 120
3. VIDEO, twelve tapes
4. BOOTH, a photo-sticker booth
5. PRO, manual dials and a live histogram
6. The roll, saved to Photos

XA is free with every feature included. No subscription, no ads, no account, no watermark. Link in bio.

Shot on iPhone in XA.

#digicam #filmphotography #y2kaesthetic #photobooth #vhs #iphonephotography #opensource

### Instagram (Reel caption, DIGI)

POV: your iPhone thinks it's 2003.

DIGI mode in XA: 1 to 12 megapixels, clipped highlights, a sharpening halo, color noise and the orange date. Every flaw turns up, down or off.

Free, nothing to unlock. Link in bio.

#digicam #y2kaesthetic #partyphotos #iphonephotography

### Instagram (Reel caption, BOOTH)

Four shots. One sticker sheet.

BOOTH mode in XA: a countdown on the front camera, big eyes (Glow, Doll or Alien), a new backdrop and neon doodles on every shot. Print it as a sheet, a grid or a strip.

Free in XA for iPhone. Link in bio.

#photobooth #stickerphoto #bff #iphonephotography

### Bluesky

XA is out: an open-source camera for iPhone with five modes. A 2003 digicam, a film camera you load and print, twelve video tapes, a photo-sticker booth and a manual PRO camera.

Free with every feature. No subscription, ads, account or tracking. GPLv3.

[App Store link]

### Bluesky

XA's Lock Screen camera is a LockedCameraCapture extension. It can't read the app's settings, so the app sends the recipe, loaded films and date backs in the capture intent's app context, which has a 4 KB limit. The viewfinder stays dark until they arrive.

github.com/gi-os/XA

## Short video ideas

1. POV: your iPhone thinks it's 2003 (digi). Screen-record DIGI at a dinner or party: switch from 12 MP down to 1 MP, pop the flash, take three shots, then show the saved photos with the orange quartz date. On-screen text: 'DIGI · 1 to 12 MP · flaws on purpose'. End card: 'Free. No subscription. No ads.' Link the DIGI custom product page.
2. One scene, five cameras (digi, film, video, booth, pro). Same spot, one shot in each mode, cut on XA's own shutter sound. Hold each result for one second with the mode name on screen. This is the lead video for every platform.
3. 110 vs 120 (film). Load one stock and shoot the same subject in 110, half frame, 35mm and 120. Then zoom into each saved file to show the grain getting finer as the format grows. Add a short coda: swipe the box up to push a stop, down to pull, before and after. Text: 'grain sized in microns on the negative'.
4. Build a sim from Neutral (sims). Screen-record the editor: start from Neutral, bend the tone curve, add a split tone, grain, halation and vignette, then save it under your own name and shoot with it. End on the finished photo next to the plain one. Invite people to post their recipes.
5. Twelve tapes in twelve seconds (video). One scene, the Camera Control button sliding through every tape for about a second each, with the tape name on screen: VHS, 8mm, CCTV, the pocket tapes, trails, motion, stop motion, slit-scan, datamosh, clean. On an iPhone without Camera Control, use the tape picker. Say '8mm', not the brand name.
6. Booth with a friend (booth). Real-time capture of the countdown and four shots, then the sticker sheet reveal. Repeat quickly with Glow, Doll and Alien. Get a signed release from everyone on camera and keep it suitable for all ages. This is also the lead clip for the Japan and Korea wave.
7. Eight dates (dates). One photo, cycling through all eight date backs, ending on the orange quartz: quartz, dot matrix, camcorder, LCD, red-pixel digicam, red ink stamp, marker on tape, film edge print. Show the name of each one on screen.
8. Out of the rectangle (shapes). Porthole, Capsule, Crush and Nova, with the date following the Porthole's edge, then the round and wide instant prints. Keep the square instant print out of the opening frame. Text: 'portholes, capsules and instant prints'.
9. Lock Screen to roll (lock, roll). Locked phone, press Camera Control, slide through sims, shoot three frames, then unlock and swipe up for the contact sheet. Use your own wallpaper and turn notifications off. Post in December for people setting up new iPhones.
10. Dusk in PRO (pro). Shutter priority at dusk: the live histogram moves as you turn the shutter and ISO dials. Then show the saved full-size photo and zoom in. Put the settings on screen. Good for Threads and r/iphoneography; don't describe the Lock Screen camera as full size.

## Press pitch

**Subject:** PITCH: XA – free, open-source iPhone camera with digicam, film, video and booth modes (out Nov 17)

Hi [name or team],

I'm Giovanni Lupo, an independent developer. On Tuesday, November 17, I'm releasing XA, an iPhone camera app with five modes:

- DIGI: a 2003 point-and-shoot. 1 to 12 megapixels, clipped highlights, a sharpening halo, color noise, a hard JPEG and eight date backs.
- FILM: eleven film stocks in 110, half frame, 35mm or 120, a rangefinder-style finder, light leaks, a mist filter and lab printing controls.
- VIDEO: twelve tapes, including VHS, an 8mm home movie, CCTV, slit-scan and datamosh.
- BOOTH: a Japanese-style photo-sticker booth. Four shots, big eyes, a sticker sheet.
- PRO: the biggest photo the sensor makes, with a live histogram and manual white balance, exposure, shutter, ISO and focus.

Why it may interest your readers:

- Everything is in the free download. There's no subscription, no ads, no account and no watermark. Optional tips unlock nothing. Most apps in this category sell subscriptions or camera packs.
- It collects nothing. XA has no server and no analytics; the App Store privacy label is Data Not Collected.
- The film is modeled from published datasheets, using spektrafilm, Andrea Volpato's open-source film simulation. Grain and halation are sized in microns on the negative, so they change with the format.
- It works as the iPhone's camera: a Lock Screen camera, a Control Center control, and Camera Control, which slides through looks, stocks and tapes.
- It's open source under the GNU GPL version 3.

Facts:
- Version: [version]
- Price: free, every feature included
- Requires: iPhone with iOS 18 or later
- Interface: English
- Release: Tuesday, November 17, 2026

Links:
- TestFlight (until release): [TestFlight link]
- App Store: [App Store or pre-order link]
- Press kit with screenshots, a 30-second video and full-size samples from each mode: [press kit link]
- Source: https://github.com/gi-os/XA

I can answer questions or send more samples.

Thanks,
Giovanni Lupo
gio@gi-os.com

### Where to send it

- **9to5Mac**: Use the tip form on 9to5mac.com/contact, which also lists their tips inbox. Submitting a tip gives them permission to publish it. Angle: a Lock Screen camera and Camera Control support in a free, open-source app. Send Tue Nov 10, with a short launch-day note on Nov 17 if there's no reply.
- **TechCrunch**: Use the address for press releases and pitches published on techcrunch.com/got-a-tip. Angle: the digicam revival against subscription filter apps. They covered an indie retro camera app (mood.camera) in 2024, so the beat exists.
- **The Verge (and the Installer newsletter)**: News tips through theverge.com/contact. For Installer's app picks, use the address the newsletter publishes in each issue. Angle: BOOTH and the video tapes, with a short screen recording.
- **TidBITS**: Follow their 2026 pitch guide (tidbits.com/2026/07/23/how-to-pitch-apps-to-tidbits-in-the-ai-era/). Plain-text email, subject starting with PITCH:, no adjectives. Include version, OS, price, links, the press kit and one screenshot. One follow-up after a week, and only with news. Trim the pitch above to facts only.
- **Cult of Mac**: Use the news tip address on cultofmac.com's contact page; app reviews are one of the things they list. Same angle as 9to5Mac.
- **AppleInsider**: Use the news tip address or form on appleinsider.com's contact page. Angle: Camera Control and the Lock Screen camera.
- **MacRumors**: Use the tip form at macrumors.com/share.php. They are mostly news, so keep it short and lead with Camera Control. Low priority.
- **PetaPixel**: Use the tips address on petapixel.com's about or contact page (check it there; the page blocked automated reading during research). Angle: film modeled from datasheets and real 2003 digicam faults. Attach full-size samples from every mode, taken after the drum scan has been checked on a device.
- **Fstoppers**: Use the form at fstoppers.com/contact and pick Article Suggestions. Same angle and samples as PetaPixel.
- **Lifehacker**: Use the tips address on lifehacker.com's contact page (check it there; it couldn't be verified during research). Angle: a retro camera app with nothing to pay for.
- **Gadget Hacks**: Ask through the site's contact page to be added to their always-updated list of apps that support the Camera Control button (ios.gadgethacks.com). Give the exact setup path: Settings › Camera › Camera Control › Launch Camera › XA.
- **iOS Dev Weekly**: Suggest a link at suggest.iosdevweekly.com. Better: write a technical blog post (the LockedCameraCapture settings hand-off, or tiled Core Image rendering for 40 MP frames) and suggest that instead of the app.
- **MacStories**: There's no public tips inbox, and they write only about apps they've tested. Don't cold-pitch; let Hacker News and social coverage reach them.
- **Digital Camera Watch (Japan)**: Send a press release through the contact page at dc.watch.impress.co.jp/docs/common/contact.html, in Japanese, once the Japanese store listing exists (the Jan to Mar 2027 wave).
- **iPhone Mania (Japan)**: Use the press release form at iphone-mania.jp/contact/, in Japanese, with the Japanese listing live.
- **AppBank (Japan)**: Use their app review request form. Expect about a month of backlog, so send it early in the Japan wave.
- **open-source-ios-apps (GitHub list)**: Open a pull request adding XA to contents.json with the App Store link, following the repo's CONTRIBUTING guide. Launch day.
- **AlternativeTo**: List XA yourself as a free, open-source alternative on the pages of the retro camera apps it replaces. Launch day.

## Press release

FOR RELEASE ON TUESDAY, NOVEMBER 17, 2026

XA, a free and open-source camera for iPhone, puts five cameras in one app

A 2003 digicam, a film camera, twelve video tapes, a photo-sticker booth and a manual camera, with nothing to unlock and no data collected

[CITY], November 17, 2026. Giovanni Lupo, an independent developer, today released XA on the App Store. XA is a camera app for iPhone with five modes: DIGI, FILM, VIDEO, BOOTH and PRO. Every feature is in the free download. There is no subscription, no advertising, no account and no watermark, and the app collects no data.

THE FIVE CAMERAS
- DIGI is a 2003 point-and-shoot. It saves 1 to 12 megapixels and copies a cheap camera's processing on purpose: clipped highlights, a sharpening halo, color noise and a hard JPEG. Users stack a film sim, a look, a shape and one of eight date backs, and see them live in the viewfinder.
- FILM loads one of eleven film stocks, in 110, half frame, 35mm or 120. It has a rangefinder-style finder with a bright frame and a focusing patch, flash, light leaks, a mist filter and lab printing controls. By default it saves a drum-scan-sized HEIC file, at about 5600 dpi and up to 48 megapixels.
- VIDEO has twelve tapes, including VHS, an 8mm home movie, CCTV, slit-scan and datamosh.
- BOOTH is a Japanese-style photo-sticker booth: four shots with the front camera, big eyes and a sticker sheet.
- PRO saves the biggest photo the iPhone's sensor makes, as HEIF or JPEG. It has a live histogram, manual white balance, exposure, shutter, ISO and focus, and shutter and ISO priority.

FILM MODELED FROM PUBLISHED DATASHEETS
XA's color stocks are developed through tables made with spektrafilm, Andrea Volpato's open-source spectral simulation of film from published datasheets. The effects that depend on neighboring pixels, such as halation, local contrast and grain, run on the iPhone in Core Image. Grain and halation are sized in microns on the negative, so they change with the film format.

BUILT FOR THE IPHONE'S BUTTONS
XA includes a Lock Screen camera and a Control Center control. On an iPhone with Camera Control, XA can be the button's camera, and the button slides through sims, looks, stocks and tapes. The volume buttons also take pictures, and XA opens QR codes from the viewfinder.

FREE AND OPEN SOURCE
Most retro camera apps on the App Store sell subscriptions or camera packs. XA includes every camera, stock, sim, look, shape, date back and tape in the free download. Optional tips in the app support development and unlock nothing. XA has no server and no analytics, and its App Store privacy label is Data Not Collected. Pictures are saved to the Photos library, in an XA album. The source code is public on GitHub under the GNU GPL version 3.

[Optional: one or two sentences from Giovanni Lupo, in his own words. Leave this paragraph out rather than use a line written for him.]

AVAILABILITY
XA is available now as a free download on the App Store, for iPhone with iOS 18 or later. The app's interface is in English. [Confirm the list of countries before sending.]

LINKS
App Store: [App Store link]
Website: https://gi-os.github.io/XA/
Source code: https://github.com/gi-os/XA
Press kit with screenshots, video and full-size samples from each mode: [press kit link]

ABOUT XA
XA is made by Giovanni Lupo, an independent developer. XA is not affiliated with or endorsed by any camera or film maker. The film stock and sim names in the app are invented.

PRESS CONTACT
Giovanni Lupo, gio@gi-os.com

###
