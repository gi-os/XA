# XA: App Store keyword research and storefront indexing map

Prepared 14 Oct 2026 for the copywriters and the launch planner. The data was captured live from the App Store on 14 Oct 2026, in 15 storefronts.

---

## 0. Read this first

1. **FILM resolution: do not write "full resolution" yet.** The facts say FILM "saves full resolution HEIC", but the user reports that FILM photos are currently all low resolution and has asked for that to be fixed. When I first read the code, FILM captured at the DIGI megapixel setting: `XA/Camera/CameraModel.swift` `shotDims()` returned `proDims` only for PRO and `digiDims` for everything else (1 to 5 MP, long edge 1152 to 2592 px). While I was working, someone else changed that file to add `filmDims = largest`, so a fix seems to be under way. No copy, subtitle or screenshot caption should say FILM is full or high resolution until a build is checked on a device. The current `description.txt` does not make that claim and is safe.
2. **The current en-US draft wastes the strongest fields.**
   - The name "XA Camera" uses 9 of 30 characters.
   - The subtitle and the keyword field both contain "film" and "digicam", which is a duplicate with no benefit.
   - "point and shoot" is not an autocomplete term in any storefront I checked, and NOMO CAM owns it.
   - Section 5.1 has a replacement.
3. **English (U.K.) is the most valuable second slot.** Apple indexes it in 172 of its 175 storefronts. The only three that don't index it are the US, Canada and Japan. Japan indexes **English (U.S.)** instead.
4. **The US indexes 10 localizations.** These are en-US, es-MX, French, Korean, Portuguese (Brazil), Simplified Chinese, Traditional Chinese, Arabic, Russian and Vietnamese. So the Korean, French, Portuguese and Chinese keyword fields also rank in the US. Vietnamese is indexed only in the US and Vietnam, which makes it the cleanest optional slot for extra US English keywords.
5. **China mainland probably needs an ICP filing number before launch.** In practice a foreign individual developer can't get one. Plan to launch without China mainland, but still write zh-Hans: it is indexed in the US and Singapore.
6. **Free with no subscription is a real gap in the market** (section 4). Apple's guideline 2.3.7 rules out pricing information in metadata, though. Keep "free" and "no subscription" out of the name, subtitle and keyword field, and put them in the description, promotional text and screenshots.

---

## 1. Method and how to read the numbers

Apple Ads Search Popularity (a score from 5 to 100) can't be checked before the app is live. Since the October 2025 API change it is also only returned for keywords scoring 35 or more ([Sonar](https://trysonar.app/blog/apple-search-popularity)), and Apple rescaled most scores on 29 Sep 2025 ([aso.dev](https://aso.dev/blog/apple-ads-popularity-massive-drop/)). So I collected first-party App Store signals per storefront instead:

- **Popularity (AC).** I typed each term into the App Store autocomplete endpoint one character at a time, with that storefront's header (2,299 queries).
  - `AC 4/11 #2` means the term appeared as suggestion #2 after typing 4 of its 11 characters. Fewer characters and a higher position mean more searches.
  - `n/s` means the term was never suggested as a query of its own, or only inside app names. Treat that as low volume.
  - Terms that start with an unusual prefix (y2k, ccd, 35mm) surface early more easily, so read them together with the competition column.
- **Competition (Comp).** This is the median rating count of the top 10 organic results on the web App Store search page for that storefront, using that storefront's rating counts from the iTunes Lookup API. The leader is in brackets.
  - VH means 10k or more, H is 2k to 10k, M is 300 to 2k, and L is under 300.
  - I also note when the results show the term means something else there (wrong intent).
- **Tiers.** Popularity is graded H, M or L from the AC data. Priority is P1 (name or subtitle), P2 (keyword field) or P3 (only if there is room). "Avoid" covers trademarks, competitor names, wrong intent and features XA doesn't have.
- **Gaps.** Apple rate-limited the autocomplete endpoint on 14 Oct, so Brazil has no autocomplete data and Italy is partial. Their lists rest on the search-results data and should be checked in Apple Ads after launch.

---

## 2. Storefront indexing map

This comes from Apple's official table ([App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-store-localizations)), which I checked row by row on 14 Oct 2026. Apple calls the second column "additional supported languages". The ASO industry treats these as the localizations whose metadata is searched in that storefront ([aso.dev](https://aso.dev/metadata/cross-localization/), [AppTweak](https://www.apptweak.com/en/aso-blog/how-to-benefit-from-cross-localization-on-the-app-store)).

| Storefront | Default localization | Also indexed | XA should fill |
|---|---|---|---|
| **United States** | English (U.S.) | Spanish (Mexico), French, Korean, Portuguese (Brazil), Chinese (Simplified), Chinese (Traditional), Arabic, Russian, Vietnamese | en-US, es-MX, fr-FR, ko, pt-BR, zh-Hans, zh-Hant (+ optional vi as an extra English slot) |
| **United Kingdom** | English (U.K.) | none | en-GB |
| **Canada** | English (Canada) | French (Canada) | en-CA, fr-CA (en-US and en-GB are **not** indexed here) |
| **Australia** (NZ the same) | English (Australia) | English (U.K.) | en-AU, en-GB |
| **Japan** | Japanese | **English (U.S.)** | ja, en-US |
| **Korea** | Korean | English (U.K.) | ko, en-GB |
| **China mainland** | Chinese (Simplified) | English (U.K.) | zh-Hans, en-GB (ICP filing needed) |
| **Taiwan** | Chinese (Traditional) | English (U.K.) | zh-Hant, en-GB |
| **Hong Kong** (Macau the same) | Chinese (Traditional) | English (U.K.) | zh-Hant, en-GB (shares zh-Hant with Taiwan) |
| **Germany** (Austria the same) | German | English (U.K.) | de-DE, en-GB |
| **France** | French | English (U.K.) | fr-FR, en-GB |
| **Spain** | Spanish (Spain) | **Catalan**, English (U.K.) | es-ES, ca (optional extra slot), en-GB |
| **Mexico**, plus AR, CO, CL, PE, EC, CR, GT, DO, VE, BO, PY, PA, SV, HN, NI | Spanish (Mexico) | English (U.K.) | es-MX, en-GB (Uruguay is the reverse: en-GB default, es-MX additional) |
| **Italy** | Italian | English (U.K.) | it, en-GB |
| **Brazil** | Portuguese (Brazil) | English (U.K.) | pt-BR, en-GB |
| Switzerland (spillover) | German | English (U.K.), French, Italian | covered by de, fr, it |

Where each XA localization is searched, worked out from the same table (175 storefronts):

- **en-GB: 172 storefronts** (all except USA, CAN, JPN).
- **es-MX: 19** (US plus LatAm).
- **French: 32** (France, US, Switzerland, Belgium, Luxembourg, francophone Africa, and others).
- **pt-BR: 2** (Brazil, US).
- **ko: 2** (Korea, US).
- **zh-Hans: 3** (China, Singapore, US).
- **zh-Hant: 4** (Taiwan, Hong Kong, Macau, US).
- **en-US: 2** (US, Japan).
- **vi: 2** (US, Vietnam).
- **ja: 1** (Japan).

What this means in practice:

- **Don't rely on fallback.** If none of a storefront's languages are filled in, Apple shows the app's primary language (en-US), according to Apple staff ([forum 722177](https://developer.apple.com/forums/thread/722177)). Fill every slot on purpose.
- **Phrases don't form across localizations.** "bus" in en-US and "metro" in es-MX rank separately but not as "metro bus" ([AppTweak](https://www.apptweak.com/en/aso-blog/how-to-benefit-from-cross-localization-on-the-app-store)). Each localization needs its own head noun (camera, cámara, カメラ, and so on).
- **Duplicates across localizations don't double-count.** A word repeated in two slots of the same storefront wastes room unless you need it there to complete a phrase.
- **es-MX is visible copy for Mexico and LatAm**, and for US users whose device is in Spanish. Its name and subtitle must be real Mexican Spanish. Don't fill it with English.
- **Optional extra English slot for the US:** a Vietnamese localization written in English, with its own 30 + 30 + 100 characters. It only spills into Vietnam. Russian (Russia, Ukraine) and Arabic (17 storefronts) also work but spill further. This is a common ASO tactic, not anything Apple endorses.

---

## 3. Name, subtitle and keyword field rules (2025-2026)

| Rule | What to do | Source |
|---|---|---|
| Fields and limits | Name 30, subtitle 30, keyword field 100 characters (hidden). Apple's ranking text match covers "title, subtitle, keywords, and primary category". The description and promotional text are not used for keyword ranking. | [Apple: Search](https://developer.apple.com/app-store/search/) |
| Weight | Name > subtitle ≈ keyword field. In-app purchase display names and in-app event names carry a little weight. | [AppRadar 2026](https://appradar.com/academy/aso-basics/app-store-ranking-factors), [AppTweak KR](https://www.apptweak.com/ko/aso-blog/how-to-optimize-your-ios-keyword-field) |
| Words combine | Within **one localization**, words from the name, subtitle and keyword field combine into phrases. "Film Camera" in the name plus `disposable` in the keyword field ranks for "disposable film camera". Enter single words, not phrases. Keep the main phrase in one piece in the name ("Film Camera"). | [Apple](https://developer.apple.com/app-store/search/), [AppTweak](https://www.apptweak.com/en/aso-blog/how-to-benefit-from-cross-localization-on-the-app-store) |
| No repeats | Apple: "Don't repeat any words included in your app name, subtitle, or category." Repetition gives no boost. "Photo" and "Video" come from the Photo & Video category, so don't spend characters on them except to complete a phrase such as "photo booth". | [Apple](https://developer.apple.com/app-store/search/), [aso.dev](https://aso.dev/metadata/cross-localization/) |
| Formatting | Commas with no spaces. A space after a comma costs a character. | [Apple](https://developer.apple.com/app-store/search/) |
| Plurals | Apple treats plurals as duplicates, so use the singular. In practice iOS results for the singular and plural differ: only 4.4 of the top 10 apps rank for both. Use the form people actually type, as autocomplete shows it (Spanish suggests *filtros*, not *filtro*). If both forms matter, put the second one in another slot. | [Apple](https://developer.apple.com/app-store/search/), [AppTweak](https://www.apptweak.com/en/aso-blog/do-singular-or-plural-keywords-rank-differently-in-aso) |
| Accents | I tested this: "cámara desechable" and "camara desechable" returned the same results in Mexico, and the Brazilian pair was nearly the same. Matching ignores accents. People type without accents (autocomplete suggests *camara*), but correctly accented copy still matches. Never enter both forms. | My test, 14 Oct 2026 |
| 100 characters, not 100 bytes | The limit is 100 **characters** in every language, so each CJK character counts as 1. That makes the CJK fields roughly 3 to 4 times richer. | [iBabbleon](https://www.ibabbleon.com/copywriter-translator/2013/06/apple-finally-allows-100-characters-of-keywords-in-all-languages-of-the-app-store/), [Adalo data check](https://studio.adalo.com/blog/app-store-keywords-field) |
| CJK splitting | Japanese: separate concepts with commas and split compounds ("動画,編集"). Put spaces in the name. Kanji, hiragana, katakana and romaji are indexed separately. Japan, Korea and Taiwan users also type Latin terms (Y2K, CCD, VHS, digicam). Splitting compounds only works if the head word (カメラ, 相机) is present in the same localization. | [AppTweak JP](https://www.apptweak.com/en/aso-blog/how-to-optimize-an-app-in-japanese) |
| Trademarks and competitor names | Prohibited in keywords: trademarked terms, competing app names and irrelevant terms. Guideline 2.3.7 also bans stuffing with trademarks or pricing information. | [Apple](https://developer.apple.com/app-store/search/) |
| WWDC25: App Store Tags | Tags are generated by an LLM from metadata and checked by an Apple editor. They appear in search results and collections. Developers can only remove tags, not add them. A clear description that names each feature is how to influence them. | [AppTweak](https://www.apptweak.com/en/aso-blog/apple-wwdc-2025-recap) |
| WWDC25: custom product pages in organic search | A custom product page can be assigned keywords and then appears in organic search for them, with no review needed. That allows a VHS page, a BOOTH page and a DIGI page. | [Phiture](https://phiture.com/blog/keyword-based-custom-product-pages-cpps-arrive-in-app-store-connect/) |
| Screenshot captions | Appfigures reported in June 2025 that Apple reads caption text. Later testing suggests captions reinforce existing rankings rather than create new ones, and Apple hasn't confirmed it. Put target words in captions anyway, since it costs nothing. | [Appfigures](https://appfigures.com/resources/guides/app-store-algorithm-update-2025), [AppDrift](https://appdrift.co/blog/app-store-screenshot-text-indexing) |

---

## 4. Competitors and pricing (US App Store, 14 Oct 2026)

| App | US ratings | Model (from the in-app purchase list) |
|---|---|---|
| Dazz Cam | 115,955 | Dazz Pro $6.99; one-time $19.99; paid camera packs $0.99 to $2.99 |
| Lapse | ~118k | No in-app purchases listed (social disposable-camera app) |
| NOMO CAM | 48,169 | NOMO PRO $24.99 a year; paid cameras $0.99 to $1.99 |
| 1998 Cam | ~40k | Premium $1.99 to $5.99 a month, $15.99 to $29.99 a year, lifetime $39.99 |
| Huji Cam | 11,974 | Free plus one $0.99 "Extra Options" unlock (**not a subscription**) |
| DAZE CAM | ~12k | $3.99 to $5.99 a month, $19.99 to $34.99 a year |
| 0.3MP Camera | 9,884 | $1.99 membership plus $1.99 themes |
| OldRoll | 5,595 | VIP $4.49 to $4.99 a month, $12.99 to $19.99 a year, forever $17.99 to $19.99 |
| Hipstamatic Analog | 2,814 | Camera Club $7.99, $19.99 or $29.99 |
| ProCCD | 2,188 | $2.99 a week, $5.99 to $8.99 a year, lifetime $13.99 to $17.99 |
| Kapi Cam (Y2K & CCD) | 1,658 | $4.99 a week, $9.99 to $12.99 a month, $69.99 to $89.99 a year, $149 lifetime |
| Kada Cam | ~1k | $1.99 a month, $5.49 a year, $12.99 one-time |

"KD Pro" didn't turn up in US search on 14 Oct. Gudak (Korea, sold for $0.99) also didn't appear in the US.

In China, Dazz has 1.17M ratings and NOMO 1.34M, so it is far more saturated than anywhere else. Prices are from each app's US product page. Never use any of these app names as keywords. In Japan, "dazz" and "huji" are typed into search, but they are still competitor names.

---

## 5. Keyword lists by localization

The suggested fields are starting points for the copywriters. All character counts were checked: every name and subtitle is 30 or fewer, every keyword field 100 or fewer, and no word repeats the name or subtitle.

### 5.1 en-US (US; also indexed in Japan)

| # | Keyword | Pop (AC) | Comp | Use |
|---|---|---|---|---|
| 1 | film camera | H (4/11 #2) | VH 26k (Dazz 115k) | **Name**, long-term head term |
| 2 | digicam | H (5/7 #2) | H 3.9k | **Name** |
| 3 | y2k camera | H (2/10 #5) | **L 9** | **Subtitle**, best opportunity |
| 4 | ccd camera | H (3/10 #2) | **L 72** | **Subtitle** |
| 5 | vhs / vhs cam | H (2/3 #4; "vhs cam" is the top suggestion) | H 5k | **Subtitle** |
| 6 | photo booth | M (7/11 #1) | M 1.5k, weak incumbents | **Subtitle** (TM note in section 6) |
| 7 | 2000s camera | H (3/12 #1) | not measured | KW `2000s` |
| 8 | 35mm | H (2/4 #6) | L 38 | KW |
| 9 | 8mm | H (2/3 #2) | M 333 | KW |
| 10 | camcorder | H (4/9 #1) | H 2.7k | KW |
| 11 | disposable camera | H (4/17 #6) | VH 13.7k | KW |
| 12 | digital camera / old digital camera | H (3/14 #2) / M | VH 25.7k | KW `digital`, `old` |
| 13 | vintage camera / retro camera | H / H | VH 25.7k / VH 10.9k | KW `vintage`, `retro` |
| 14 | film filter | H (4/11 #6) | VH 30k | KW `filter` |
| 15 | film grain | M (6/10 #5) | **L 2** | KW `grain` |
| 16 | date stamp | M (6/10 #9) | **L 0** | KW `date`, `stamp` |
| 17 | analog camera, instant camera | M, L-M | H 2.3k, H 4.1k | KW `analog`, `instant` |
| P3 | half frame (L 0), glitch camera (L 179), datamosh, light leak, super 8, home video, manual camera (H 4.1k), black and white camera | M | mixed | Extra slot (vi) or later |
| Avoid | timestamp camera (proof-of-work apps), point and shoot (not suggested), raw camera (PRO saves HEIF/JPEG, not RAW), cctv (viewer apps), aesthetic camera (VH, no room), purikura, polaroid, kodak, fuji filter, dazz, huji | | | |

Suggested fields:
- **Name:** `XA: Digicam & Film Camera` (25)
- **Subtitle:** `Y2K CCD cam, VHS & photo booth` (30)
- **Keyword field:** `vintage,retro,disposable,digital,camcorder,2000s,old,35mm,8mm,analog,filter,grain,date,stamp,instant` (100)

**Optional extra slot (vi):** an English name and subtitle such as `XA: Retro Video & Half Frame`. Keyword field ideas: `camera,glitch,datamosh,super,leak,light,manual,black,white,home,aesthetic,booth,sticker,cam`. "Camera" has to be repeated here so that phrases can form inside this localization.

### 5.2 en-GB (UK, plus 171 other storefronts)

UK evidence: **disposable camera is #1** at 4 characters. Digital camera is #1. "vhs camera", "y2k camera" and "2000s camera" all surface after 2 to 3 characters. Purikura is #2 and photo booth #2. Half frame, super 8 and 8mm are each #2.

UK competition is low everywhere: film camera 1.6k, disposable 1.6k, digicam 304, vhs 367, camcorder 198, photo booth 210, y2k 75, ccd 117, 35mm 118, date stamp 1.

English terms that are also typed in non-English storefronts (and so belong in en-GB):

- **film camera:** DE #1, FR #3, ES #2, MX #4
- **disposable camera:** DE, FR, ES, MX
- **digicam:** ES #1, MX #1, KR #1, DE #4
- **y2k:** #1 almost everywhere
- **vhs:** KR #1, HK #1, TW #2
- **ccd:** CN, TW, MX, FR
- **photo booth:** DE #1

Suggested fields:
- **Name:** `XA: Film Camera & Digicam` (25)
- **Subtitle:** `Disposable, Y2K, VHS & booth` (28)
- **Keyword field:** `vintage,retro,digital,camcorder,ccd,photo,2000s,old,35mm,8mm,analogue,filter,grain,date,stamp,cam` (97)

Use the British spelling *analogue*; UK suggestions list "analogue camera".

### 5.3 en-AU, en-CA, fr-CA

**en-AU** (Australia and New Zealand; Australia also indexes en-GB):
- Evidence: film filter #1, digicam #1, vhs camera #1, photo booth #1, 35mm #2, disposable camera #2, camcorder #2.
- Competition is low: film camera 748, disposable 479, camcorder 69, photo booth 117.
- Use the **en-US set word for word**. It complements en-GB: en-AU leads with Y2K/CCD/VHS, en-GB with Disposable.

**en-CA:**
- Evidence: digital camera #1, camcorder #1, photo booth #1, 35mm #1.
- Competition: film camera 759, camcorder 147.
- Use the en-US set word for word.

**fr-CA:**
- Search competition is close to zero: *appareil photo jetable* 1, *argentique* 1, *caméscope* 0.
- **Name:** `XA : caméra rétro et digicam` (28)
- **Subtitle:** `Appareil photo jetable, VHS` (27)
- **Keyword field:** `argentique,vintage,pellicule,filtre,caméscope,cabine,numérique,y2k,ccd,grain,date,noir,blanc,35mm` (97)

### 5.4 ja (Japan; Japan also indexes en-US)

| # | Keyword | Gloss | Pop (AC) | Comp | Use |
|---|---|---|---|---|---|
| 1 | フィルムカメラ | film camera | H (2/7 #4) | H 2.9k (Dazz 79k) | **Name** |
| 2 | エモい / エモいカメラ | "emo", nostalgic-moody | H ("エモいカメラ" is #1 under エモい) | H 8.4k | **Name** |
| 3 | デジカメ / デジカメ風 | digicam / digicam-style | H (2/4; 風 3/5 #3) | M 980 | **Name**; KW デジカメ風 |
| 4 | レトロ / レトロカメラ | retro | H (1/3 #2) | H 8k / 1.7k | **Subtitle** |
| 5 | 使い捨てカメラ | disposable camera | H (1/7 #7) | **L 64** | **Subtitle**, best opportunity |
| 6 | Y2K (y2kカメラ) | | H (2/3 #1) | **L 8** | **Subtitle** (en-US also covers it) |
| 7 | VHS | | H (2/3 #4) | M 398 | **Subtitle** |
| 8 | コンデジ | compact digicam | M (3/4 #1) | **L 1** | KW; ties to the Gen Z old-compact boom |
| 9 | オールド(デジカメ) / 平成(レトロ) | old digicam / Heisei retro | L (only in app names) | M 351 / L 4 | KW オールド, 平成 |
| 10 | トイカメラ | toy camera | M (3/5 #4) | L 32 | KW トイ |
| 11 | ハーフカメラ | half-frame camera | M (3/6 #5) | M 1.2k | KW ハーフ (Pentax 17 / Ektar H35 trend) |
| 12 | インスタントカメラ | instant camera | M (5/9 #2) | H 2.9k | KW インスタント |
| 13 | ビデオカメラ / ホームビデオ | camcorder / home video | M (4/6 #1) / L | H 3.3k / VH | KW ビデオ, ホームビデオ |
| 14 | 日付(カメラ) | date stamp | M ("日付カメラ" suggested) | VH for 日付 alone (calendars) | KW 日付 |
| 15 | ドット絵 | pixel art (1-Bit, Pocket looks) | M (2/4 #2) | not measured | KW |
| 16 | フィルム風, 白黒, モノクロ, ノイズ, 粒子, フィルター, アナログ, ビンテージ | film-look, B&W, mono, noise, grain, filter, analog, vintage | M / L | mixed (粒子 results are gambling apps) | KW fill |
| Avoid | プリクラ (SEGA TM; 1/4 #8), 写ルンです (Fujifilm TM; 2/5 #1), チェキ (Fujifilm TM), 無音カメラ (XA isn't a silent camera), 証明写真 (ID photos), 加工/写真加工 (editing intent) | | H | | |

Suggested fields:
- **Name:** `XA エモいフィルムカメラ＆デジカメ` (18; there are 12 characters to spare)
- **Subtitle:** `レトロ・Y2K・VHS・使い捨てカメラ風` (20)
- **Keyword field:** `コンデジ,オールド,平成,ビデオ,ホームビデオ,インスタント,トイ,ハーフ,日付,写真,粒子,ノイズ,白黒,モノクロ,ドット絵,フィルター,8ミリ,ビンテージ,アナログ,フィルム風,デジカメ風` (96)

Trend background: Japanese compact-camera shipments rose 29.6% in 2025, driven by the old-compact (オールドコンデジ) fashion ([Gizmodo JP](https://www.gizmodo.jp/2026/02/compact_camera_growth.html), [GetNavi](https://getnavi.jp/appliances/1034378/)).

### 5.5 ko (Korea, also indexed in the US)

| # | Keyword | Gloss | Pop (AC) | Comp | Use |
|---|---|---|---|---|---|
| 1 | 필름카메라 | film camera | H (1/5 #2) | M 1.3k (NOMO 22k) | **Name** |
| 2 | 감성 / 감성카메라 | "gamseong" (mood, feeling) | H (감성카메라 3/5 #1) | M 701 | **Name**; KW compound |
| 3 | 디카 | digicam | H (2/2 #3) | M 536 | **Name** |
| 4 | 레트로(카메라) | retro | H (2/3 #1) | L 264 | **Subtitle**; KW compound |
| 5 | 빈티지(카메라) | vintage | H (1/3 #3) | 빈티지 alone is fashion resale (3.3k) | **Subtitle**; KW compound |
| 6 | 캠코더 / VHS | camcorder | H (2/3 #2) / H (#1) | L 150 / L 132 | **Subtitle** |
| 7 | 옛날 카메라 | old camera | H (1/6 #3) | not measured | KW 옛날 |
| 8 | 필카 | film-cam slang | H (2/2 #2) | H 2.2k | KW |
| 9 | 디지털카메라 | digital camera | M (3/6 #5) | M 536 | KW |
| 10 | 날짜(카메라) | date (camera) | M (#1 at 3/5) | 날짜 alone is calendars | KW 날짜 |
| 11 | 네컷 / 포토부스 / 스티커사진 | four-cut / photo booth / sticker photo | M | **L 21 / L 31** | KW, the BOOTH angle |
| 12 | 일회용(카메라) | disposable | L (app names only) | L 0 | KW 일회용 |
| 13 | Y2K, CCD, 하프, 흑백, 노이즈, 필터, 즉석, 아날로그 | | M | L | KW fill |
| Avoid | 인생네컷 (Life4Cuts brand), 폴라로이드 (Polaroid TM), 구닥 (Gudak, competitor), 똑딱이 (results are the hospital app 똑닥), 무음카메라 (not a feature) | | | | |

Suggested fields:
- **Name:** `XA 감성 필름카메라 & 디카` (16)
- **Subtitle:** `레트로 빈티지 카메라, VHS 캠코더` (20)
- **Keyword field:** `필카,옛날,디지털카메라,일회용,날짜,네컷,포토부스,스티커사진,흑백,노이즈,필터,y2k,ccd,하프,어플,감성카메라,아날로그,즉석,사진,빈티지카메라,레트로카메라,8mm` (92)

The compounds are repeated in the keyword field on purpose, because Korean users type them without spaces. Trend background: the vintage-digicam revival among Korean MZ users ([TF News](https://news.tf.co.kr/read/ogmeta/2036650.htm), [Herald](https://www.heraldk.com/article/2026051418300062697)).

### 5.6 zh-Hans (China mainland if an ICP filing is obtained; also US and Singapore)

| # | Keyword | Gloss | Pop (AC) | Comp | Use |
|---|---|---|---|---|---|
| 1 | 胶片相机 | film camera | H (1/4 #3) | VH 65k (Dazz 1.17M) | **Name** |
| 2 | 复古相机 | retro camera | H (1/4 #2) | VH 80k | **Name** |
| 3 | CCD相机 / 数码相机 | CCD / digital camera | H (3/5 #1) / M-H | VH 98k / VH 42k | **Name** |
| 4 | 千禧 / Y2K | millennium / Y2K | M (2/2 #2) / M | **L 10 / L 59** | **Subtitle**, best opportunity |
| 5 | 复古DV / DV相机 | retro camcorder | M (3/4 #1) | VH 33k | **Subtitle** |
| 6 | 大头贴(相机) | photo stickers | M (2/3 #7) | **L 119** | **Subtitle**, the BOOTH angle |
| 7 | 胶片滤镜 / 滤镜 | film filter / filter | H (1/4 #4) | VH | KW |
| 8 | 拍立得 | instant camera (generic Chinese word) | H (1/3 #5) | VH 65k | KW (Polaroid association, low risk) |
| 9 | 傻瓜相机 / 卡片机 | point-and-shoot / compact | H (1/4 #7) | not measured | KW |
| 10 | 一次性相机 | disposable camera | L (app names only) | M 482 | KW |
| 11 | 胶卷, 半格 | film roll, half-frame | M (2/2 #2) | VH 33k, M 304 | KW |
| 12 | 日期 / 水印 | date / watermark | M (日期水印 3/4 #2) | VH, dominated by proof-of-work apps (今日水印相机 2M) | KW, low expectations |
| 13 | 录像机, 摄像机, 怀旧, 黑白, 日系, 港风, 氛围感, 像素, 专业, 手动 | VCR, camcorder, nostalgia, B&W, Japanese style, Hong Kong style, "vibe", pixel, pro, manual | M / L | mixed | KW fill |
| Avoid | 富士 (Fujifilm TM), dazz, huji, 水印相机 as the main target (wrong intent), 老照片 (photo restoration) | | | | |

Suggested fields:
- **Name:** `XA 复古胶片相机·CCD数码相机` (17)
- **Subtitle:** `千禧Y2K、复古DV、大头贴` (14)
- **Keyword field:** `胶卷,滤镜,傻瓜,拍立得,一次性,日期,水印,颗粒,半格,黑白,怀旧,日系,港风,氛围感,像素,录像机,摄像机,专业,手动,vhs,35mm,ins,复古滤镜,胶片滤镜,老相机,卡片机` (92)

Trend background: the CCD camera craze on Xiaohongshu, now cooling ([Chinanews](https://www.chinanews.com.cn/cj/2022/11-24/9901055.shtml), [ifanr](https://www.ifanr.com/app/1494141)).

### 5.7 zh-Hant (Taiwan and Hong Kong share one localization; also US and Macau)

| # | Keyword | Market | Pop (AC) | Comp | Use |
|---|---|---|---|---|---|
| 1 | 底片相機 | TW film camera | H (1/4 #1) | M 924 | **Name** |
| 2 | 菲林(相機) | HK film camera (Cantonese) | H in HK (1/4 #2) | M 590 / 1k | **Name** |
| 3 | 復古相機 | both, retro camera | H (1/4 #2 TW, #4 HK) | M 1.7k / 1.1k | **Name** |
| 4 | CCD | both | H (TW 2/3 #2) | M 588 / 440 | **Name** |
| 5 | 數位相機 (TW) / 數碼相機 (HK) | digital camera | L | **L 47 / 117** | **Subtitle** / KW |
| 6 | Y2K / VHS / DV | both | H (#1 to #2) | L | **Subtitle** |
| 7 | 拍貼(機) | TW photo-sticker booth | M (1/2 #6) | M 728 (LINE拍貼) | **Subtitle** |
| 8 | 膠片, 底片濾鏡 | film, film filter | H (1/2 #1, 1/4 #2) | 濾鏡 VH 25k | KW |
| 9 | 拍立得 / 即影即有 | instant (TW / HK) | H / not measured | M 1k / L 201 | KW |
| 10 | 即可拍 | TW disposable camera | L | **L 65** | KW |
| 11 | 大頭貼 / 貼紙相 | photo stickers (TW / HK) | M / not measured | TW results are ID photos | KW only |
| 12 | 懷舊, 日期, 顆粒, 半格, 黑白, 攝影機 (TW results are CCTV), 錄影機, 專業, 手動, 文青 | | M / L | mixed | KW fill |
| Avoid | 富士 (Fujifilm TM), Dazz, Huji | | | | |

Suggested fields:
- **Name:** `XA 復古底片相機・菲林・CCD` (16)
- **Subtitle:** `數位相機、Y2K、復古DV、拍貼機` (17)
- **Keyword field:** `膠片,膠卷,濾鏡,數碼,拍立得,即影即有,即可拍,大頭貼,貼紙相,日期,顆粒,半格,黑白,懷舊,攝影機,錄影機,vhs,專業,手動,35mm,文青,卡片機,傻瓜,老相機,底片濾鏡,復古濾鏡` (94)

### 5.8 de-DE (Germany and Austria)

| # | Keyword | Pop (AC) | Comp | Use |
|---|---|---|---|---|
| 1 | Einwegkamera (disposable camera) | H (4/12 #1) | M 540 | **Subtitle** |
| 2 | Retro Kamera | M (5/12 #9) | H 1.8k | **Name** |
| 3 | Digicam | M (5/7 #4) | M 490 | **Name** |
| 4 | Fotoautomat (photo booth) | M (5/11 #4) | **L 15** | **Subtitle** |
| 5 | Vintage Kamera | M (5/14 #8) | H 3.7k | KW `vintage` |
| 6 | Wegwerfkamera (disposable camera) | M (4/13 #7) | **L 0** | KW |
| 7 | Digitalkamera / Camcorder | M | L 281 / L 298 | KW |
| 8 | Körnung (grain), Datum, Zeitstempel (timestamp) | M (#1 / #1 / #4) | Körnung H 5.7k (editors) | KW |
| 9 | Fotobox, Filter (Retro Filter), analog | M | L 72 / – / M 533 | KW |
| Note | Filmkamera and Analogkamera are not suggested; Germans type **"film camera" in English** (#1), which en-GB covers. **VHS** results are adult-education (Volkshochschule) language apps, so keep VHS in the subtitle to describe the feature, not for traffic. Polaroid: avoid. | | | |

Suggested fields:
- **Name:** `XA: Retro Kamera & Digicam` (26)
- **Subtitle:** `Einwegkamera, VHS, Fotoautomat` (30)
- **Keyword field:** `vintage,analog,wegwerfkamera,digitalkamera,camcorder,fotobox,filter,körnung,datum,zeitstempel,y2k` (97)

### 5.9 fr-FR (France; also US, Switzerland, Belgium, Luxembourg, francophone Africa)

| # | Keyword | Pop (AC) | Comp | Use |
|---|---|---|---|---|
| 1 | appareil photo | H (4/14 #1) | high | **Name** |
| 2 | appareil photo vintage | M (5/22 #7) | H 2.3k | **Name** |
| 3 | appareil photo jetable | M-H (6/22 #7) | M 496 | **Subtitle** `jetable` (*jetable* alone means temp-mail apps) |
| 4 | argentique (film photography) | M (3/10 #10) | M 1k | **Subtitle** |
| 5 | VHS / Y2K | H | L 234 / – | **Subtitle** |
| 6 | filtre argentique | M (8/17 #2) | H 4.4k | KW `filtre` |
| 7 | rétro | H (3/5 #3) | M 891 | KW |
| 8 | digicam, CCD | M | M 568 | KW |
| 9 | caméscope | L | L 202 | KW |
| 10 | noir et blanc, date, grain, numérique, instantané, pellicule (mixed intent: camera-roll cleaners) | M / L | | KW |
| Avoid | **photomaton** (Photomaton trademark; results are ID-photo apps), so use *cabine* (cabine photo, L 116). Polaroid. | | | |

Suggested fields:
- **Name:** `XA – appareil photo vintage` (27)
- **Subtitle:** `Argentique, jetable, VHS, Y2K` (29)
- **Keyword field:** `rétro,filtre,pellicule,caméscope,digicam,numérique,cabine,ccd,grain,date,noir,blanc,instantané,35mm` (99)

### 5.10 es-ES (Spain) and ca (Catalan, the extra slot for Spain)

| # | Keyword | Pop (AC) | Comp | Use |
|---|---|---|---|---|
| 1 | cámara retro / cámara | M (8/12 #2) / H | – | **Name** |
| 2 | digicam | M (5/7 **#1**) | L 255 | **Name** |
| 3 | cámara desechable | L (not suggested; English "disposable camera" is 4/17 #8) | **L 1** | **Subtitle** `Desechable` |
| 4 | carrete (film roll, Spain) | L-M (6/7 #7) | L 6 | **Subtitle** |
| 5 | VHS / Y2K | H | L 117 | **Subtitle** |
| 6 | cámara vintage | M (4/14 #4) | M 1.5k | KW |
| 7 | cámara analógica / antigua / digital | M (#2 / #3 / #8) | M 605 / 577 / 605 | KW |
| 8 | fotomatón | M (6/9 #8) | L 72 | KW (generic in the Spanish dictionary but derived from Photomaton, small risk) |
| 9 | filtros, blanco y negro, videocámara, fecha | M / L | L | KW |
| Skip | película (means movies), polaroid | | | |

Suggested fields:
- **Name:** `XA: Cámara Retro y Digicam` (26)
- **Subtitle:** `Desechable, carrete, VHS, Y2K` (29)
- **Keyword field:** `analogica,vintage,antigua,digital,fotomaton,cabina,fotos,filtros,videocamara,fecha,blanco,negro,ccd` (99)

**ca (optional):** the name and subtitle must be real Catalan, for example `XA: Càmera Retro i Digicam`. Use the keyword field for whatever Spanish terms are left over (grano, rollo, instantánea) plus Catalan (càmera, analògica, rodet).

### 5.11 es-MX (Mexico and 15 LatAm storefronts; also US Spanish speakers)

| # | Keyword | Pop (AC) | Comp | Use |
|---|---|---|---|---|
| 1 | camara vintage | M (8/14 **#1**) | M 952 (Dazz 46k) | **Name** |
| 2 | digicam | M (5/7 **#1**) | M 688 | **Name** |
| 3 | camara retro | M (8/12 **#1**) | M 952 | **Subtitle** |
| 4 | cámara desechable | L | **L 1** | **Subtitle** |
| 5 | VHS / Y2K | H (#4 / #1) | M 441 | **Subtitle** |
| 6 | camara antigua / camara digital | M (**#1 / #1**) | M 1.3k / 799 | KW |
| 7 | cámara analógica | M (8/16 #4) | M 1.3k | KW |
| 8 | cámara de rollo (Mexican term) | L | **L 9** | KW `rollo` |
| 9 | cabina de fotos | M (4/15 #7) | **L 0** | KW `cabina`, `fotos` |
| 10 | película (4/8 #1, likely movie intent), filtros, blanco y negro, fecha, videocámara (M 1.3k) | | | KW |
| Note | "disposable camera" in English is 4/17 #6 in Mexico and en-GB covers it. Polaroid: avoid. | | | |

Suggested fields:
- **Name:** `XA: Cámara Vintage y Digicam` (28)
- **Subtitle:** `Retro, desechable, VHS y Y2K` (28)
- **Keyword field:** `antigua,analogica,digital,rollo,pelicula,filtros,cabina,fotos,fecha,videocamara,ccd,blanco,negro` (96)

### 5.12 it (Italy; autocomplete data is partial)

| # | Keyword | Pop (AC) | Comp | Use |
|---|---|---|---|---|
| 1 | fotocamera / retro | H (3/10 #3) / H (3/5 **#1**) | – / M 596 | **Name** |
| 2 | digicam | suggested | L 135 | **Name** |
| 3 | fotocamera usa e getta | suggested (app names) | **L 1** | **Subtitle** |
| 4 | analogica / fotocamera analogica | suggested | M 1.5k | **Subtitle** |
| 5 | VHS | H (2/3 #6) | L 171 | **Subtitle** |
| 6 | fotocamera vintage | M (5/18 #5) | M 1.1k | KW `vintage` |
| 7 | pellicola / rullino (film / roll) | M (5/9 #2 / 4/7 #5) | **L 4 / L 2** | KW |
| 8 | videocamera, fotocamera digitale | M / suggested | M 664 / M 453 | KW |
| 9 | filtri, istantanea, bianco e nero, data, grana | M / L | | KW |
| Avoid | fototessera and cabina fototessera (ID-photo intent), polaroid | | | |

Suggested fields:
- **Name:** `XA: Fotocamera Retro e Digicam` (30)
- **Subtitle:** `Usa e getta, analogica, VHS` (27)
- **Keyword field:** `vintage,rullino,pellicola,digitale,videocamera,istantanea,filtri,bianco,nero,data,grana,y2k,ccd,35mm` (100)

### 5.13 pt-BR (Brazil and US; no autocomplete data, based on search results only)

| # | Keyword | Comp | Use |
|---|---|---|---|
| 1 | câmera retrô | H 2.6k (Dazz 129k, 1998 Cam 18k) | **Name** |
| 2 | digicam | M 378 | **Name** |
| 3 | câmera descartável | **L 0 to 1** | **Subtitle** |
| 4 | câmera analógica | M 1.3k | **Subtitle** |
| 5 | VHS | M 323 | **Subtitle** |
| 6 | câmera antiga / câmera digital / vintage | H 2.6k / M 590 / H 6.3k | KW |
| 7 | câmera de filme | L 276 | KW `filme` (*filme* alone means movie apps, so it only helps in the phrase) |
| 8 | filmadora (camcorder) | L 182 | KW |
| 9 | cabine de fotos | **L 0** | KW |
| 10 | filtro, preto e branco, granulado, data, Y2K, CCD, 35mm | – | KW |

Suggested fields:
- **Name:** `XA: Câmera Retrô e Digicam` (26)
- **Subtitle:** `Descartável, analógica e VHS` (28)
- **Keyword field:** `vintage,antiga,digital,filme,filmadora,cabine,fotos,filtro,data,granulado,preto,branco,ccd,y2k,35mm` (99)

Check these in Apple Ads (Brazil) in the first week after launch.

---

## 6. Trademark watchlist

| Term | Owner / status | Guidance |
|---|---|---|
| プリクラ / プリント倶楽部 (Purikura) | Registered trademarks of SEGA ([Toyo Keizai](https://toyokeizai.net/articles/-/406794)) | Don't use in ja metadata. "purikura" is #2 in UK autocomplete but still avoid it. Use photo booth, sticker, 大头贴, 拍貼, 네컷 instead. |
| 写ルンです, チェキ, instax, 富士/Fuji/Fujifilm | Fujifilm ([Fujifilm](https://www.fujifilm.com/jp/ja/consumer/films/utsurundesu/standard/accessories)) | Avoid. Use 使い捨てカメラ, インスタントカメラ, 拍立得 instead. |
| Polaroid / 폴라로이드 / 宝丽来 | Polaroid | Avoid. 拍立得 is the generic Chinese word (low risk). |
| 인생네컷 (Life4Cuts) | LK Ventures brand ([Unicorn Factory](https://www.unicornfactory.co.kr/hashtag/인생네컷)); I didn't verify the registration | Avoid. 네컷 and 포토부스 are generic. |
| Photomaton | Registered brand in Europe ([OQLF](https://vitrinelinguistique.oqlf.gouv.qc.ca/fiche-gdt/fiche/18083911/cabine-photographique)) | Avoid in fr. Spanish *fotomatón* is genericized, small risk. |
| PHOTO BOOTH | Apple Inc., US Reg. 3299823, for software ([Justia](https://trademarks.justia.com/788/25/photo-booth-78825435.html)) | Many listings use it descriptively (Pocketbooth Photo Booth and others). Keep it lowercase and descriptive in the subtitle, never as the product name. |
| Kodak, Super 8, Leica, Game Boy (the POCKET look), Handycam, Cyber-shot, Lomography, Hipstamatic | Their owners | Never in metadata. Describe looks generically (pixel, 1-bit, camcorder). |
| Dazz, Huji, NOMO, 1998 Cam, Gudak (구닥), Dispo, Lapse, OldRoll, ProCCD | Competitor app names | Prohibited in keywords. |
| "XA" | The US OLYMPUS XA registration was cancelled in 1989 ([Justia](https://trademarks.justia.com/733/17/olympus-xa-73317335.html)) | Low risk. Never write "Olympus". |
| Camera Control, Lock Screen, iPhone | Apple terms | Fine in the description to describe compatibility. They add nothing in keywords. |

---

## 7. Launch planner notes

1. **Localizations to create at launch:**
   - en-US (primary), en-GB, en-AU, en-CA, fr-CA, ja, ko, zh-Hans, zh-Hant, de-DE, fr-FR, es-ES, es-MX, it, pt-BR.
   - Optional: ca (Spain extra slot) and vi (US extra English slot).
   - Today `fastlane/metadata` has only en-US.
2. **English-only interface.** Each localized description should say plainly that the app's interface is in English. The product page's "Languages" list comes from the app itself, not from the metadata.
3. **China mainland.** Apple says MIIT requires some apps to have an ICP filing number, and Apple has refused new apps without one since 29 Sep 2023 ([AppleInsider](https://appleinsider.com/articles/23/10/03/apple-bows-to-china-starts-enforcing-app-store-rules), [Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/), [forum](https://developer.apple.com/forums/thread/743661)). Getting a filing needs a Chinese entity or local publisher, and the zh-Hans name must match the filing. Recommendation: switch off China mainland availability, keep zh-Hans for the US and Singapore, and revisit later.
4. **Positioning without breaking guideline 2.3.7.** Put "Free, no subscription, no ads, no account, open source" in promotional text, the description and screenshot captions. Every listed competitor except Huji and Lapse sells subscriptions or packs.
5. **Custom product pages linked to keywords (WWDC25).**
   - VHS page: vhs, camcorder, 8mm
   - BOOTH page: photo booth, 네컷, 大头贴, 拍貼, Fotoautomat
   - DIGI page: digicam, y2k, ccd, デジカメ, 디카
6. **Screenshot captions.** Reuse each localization's P1 words (Y2K, CCD, VHS, 使い捨てカメラ風, 필름카메라). Never claim FILM resolution (see section 0).
7. **Tip-jar in-app purchase names are lightly indexed.** Name them in theme, for example "Tip: a roll of film" or "Tip: a VHS tape". They unlock nothing, which is fine.
8. **After launch:** create a $0 Apple Ads draft campaign per storefront and read Search Popularity for every P1 and P2 term (Brazil and Italy first). Re-check the keyword fields after 4 weeks of ranking data.

---

## Sources

**Data I collected (14 Oct 2026):** App Store autocomplete (`search.itunes.apple.com/.../MZSearchHints`) for 15 storefronts; App Store web search results (`apps.apple.com/{cc}/iphone/search`); iTunes Lookup API rating counts; competitor in-app purchase lists from `apps.apple.com/us/app/id…`.

**Apple:**
- [App Store localizations table](https://developer.apple.com/help/app-store-connect/reference/app-store-localizations)
- [App Store search guidance](https://developer.apple.com/app-store/search/)
- [Fallback language (staff answer)](https://developer.apple.com/forums/thread/722177)
- [App information and ICP](https://developer.apple.com/help/app-store-connect/reference/app-information/)
- [ICP forum thread](https://developer.apple.com/forums/thread/743661)

**ASO:**
- [aso.dev cross-localization](https://aso.dev/metadata/cross-localization/)
- [AppTweak cross-localization](https://www.apptweak.com/en/aso-blog/how-to-benefit-from-cross-localization-on-the-app-store)
- [AppTweak Japan](https://www.apptweak.com/en/aso-blog/how-to-optimize-an-app-in-japanese)
- [AppTweak singular vs plural](https://www.apptweak.com/en/aso-blog/do-singular-or-plural-keywords-rank-differently-in-aso)
- [AppTweak WWDC25](https://www.apptweak.com/en/aso-blog/apple-wwdc-2025-recap)
- [Phiture keyword custom product pages](https://phiture.com/blog/keyword-based-custom-product-pages-cpps-arrive-in-app-store-connect/)
- [AppRadar ranking factors 2026](https://appradar.com/academy/aso-basics/app-store-ranking-factors)
- [AppTweak Korean keyword field](https://www.apptweak.com/ko/aso-blog/how-to-optimize-your-ios-keyword-field)
- [iBabbleon 100 characters](https://www.ibabbleon.com/copywriter-translator/2013/06/apple-finally-allows-100-characters-of-keywords-in-all-languages-of-the-app-store/)
- [Adalo keyword field](https://studio.adalo.com/blog/app-store-keywords-field)
- [Appfigures 2025 algorithm update](https://appfigures.com/resources/guides/app-store-algorithm-update-2025)
- [AppDrift on screenshot indexing](https://appdrift.co/blog/app-store-screenshot-text-indexing)
- [aso.dev popularity drop](https://aso.dev/blog/apple-ads-popularity-massive-drop/)
- [Sonar Search Popularity](https://trysonar.app/blog/apple-search-popularity)

**Trends:**
- [SlashGear digicams](https://www.slashgear.com/1588702/old-digital-cameras-dig-cams-tiktok-craze-are-they-worth-it/)
- [Canon UK Gen Z digicams](https://www.canon.co.uk/view/genz-digicams/)
- [Gizmodo JP compact cameras](https://www.gizmodo.jp/2026/02/compact_camera_growth.html)
- [GetNavi オールドコンデジ](https://getnavi.jp/appliances/1034378/)
- [TF News 디카](https://news.tf.co.kr/read/ogmeta/2036650.htm)
- [Herald 빈티지 디카](https://www.heraldk.com/article/2026051418300062697)
- [Chinanews CCD](https://www.chinanews.com.cn/cj/2022/11-24/9901055.shtml)
- [ifanr CCD](https://www.ifanr.com/app/1494141)
- [Digital Camera World half-frame](https://www.digitalcameraworld.com/features/the-history-of-the-half-frame-camera)

**Trademarks:**
- [Toyo Keizai プリクラ](https://toyokeizai.net/articles/-/406794)
- [Fujifilm 写ルンです](https://www.fujifilm.com/jp/ja/consumer/films/utsurundesu/standard/accessories)
- [OQLF cabine photographique](https://vitrinelinguistique.oqlf.gouv.qc.ca/fiche-gdt/fiche/18083911/cabine-photographique)
- [Justia PHOTO BOOTH](https://trademarks.justia.com/788/25/photo-booth-78825435.html)
- [Justia OLYMPUS XA](https://trademarks.justia.com/733/17/olympus-xa-73317335.html)
- [Unicorn Factory 인생네컷](https://www.unicornfactory.co.kr/hashtag/인생네컷)

**Repo files read:** `/Users/giovannilupo/gi-os/XA/README.md`, `/Users/giovannilupo/gi-os/XA/fastlane/metadata/en-US/*.txt`, `/Users/giovannilupo/gi-os/XA/fastlane/review_notes.txt`, `/Users/giovannilupo/gi-os/XA/docs/index.html`, `/Users/giovannilupo/gi-os/XA/XA/Film/{Looks,VideoLooks,Sim,FilmLab,DateBack,Booth,BoothDeco}.swift`, `/Users/giovannilupo/gi-os/XA/XA/Camera/Mode.swift`, `/Users/giovannilupo/gi-os/XA/XA/Camera/CameraModel.swift` (FILM capture size; being edited during this research).
