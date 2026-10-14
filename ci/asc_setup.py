#!/usr/bin/env python3
"""App Store Connect setup that `deliver` doesn't do, through the App Store Connect API:

- the tips: three consumable in-app purchases, each with its name, price, availability and
  App Review screenshot (fastlane/iap/tips_review.png); SUBMIT_TIPS=true also submits them
- the age rating: XA answers no / none to every content question
- the price (free) and availability in every territory, if not set yet
- the content rights declaration (no third-party content)

Run from GitHub Actions (asc-setup.yml) with the ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8
secrets. Anything already there is left as it is, so it can be run again.
"""
import base64, hashlib, os, sys, time

import jwt
import requests

API = "https://api.appstoreconnect.apple.com"
BUNDLE = os.environ.get("BUNDLE_ID", "com.gios.xa")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCREENSHOT = os.path.join(ROOT, "fastlane", "iap", "tips_review.png")

# product id, reference name, display name (30 max), description (45 max), US price
TIPS = [
    ("com.gios.xa.tip.small", "Tip small", "A roll of film", "A small tip for XA. Unlocks nothing.", "1.99"),
    ("com.gios.xa.tip.medium", "Tip medium", "Develop a roll", "A tip for XA. Unlocks nothing.", "4.99"),
    ("com.gios.xa.tip.large", "Tip large", "A brick of film", "A big tip for XA. Unlocks nothing.", "9.99"),
]
REVIEW_NOTE = ("A tip to the developer. It unlocks nothing: every feature of XA is free for everyone. "
               "Customize (the sliders button left of the flash) > Support XA, at the end.")

FREQUENCY = {  # content questions answered NONE
    "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
    "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation",
    "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity",
    "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic",
}
NO = {  # yes/no questions answered no
    "advertising", "ageAssurance", "gambling", "healthOrWellnessTopics", "lootBox",
    "messagingAndChat", "parentalControls", "unrestrictedWebAccess", "userGeneratedContent",
}

_token = {"value": None, "at": 0}
failures = []


def token():
    if not _token["value"] or time.time() - _token["at"] > 900:
        key = os.environ["ASC_KEY_P8"]
        if "BEGIN" not in key:
            key = base64.b64decode(key).decode()
        now = int(time.time())
        _token["value"] = jwt.encode(
            {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
            key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})
        _token["at"] = now
    return _token["value"]


class Fail(Exception):
    pass


def call(method, path, body=None, params=None, missing_ok=False):
    url = path if path.startswith("http") else API + path
    r = requests.request(method, url, json=body, params=params, timeout=120,
                         headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    if missing_ok and r.status_code == 404:
        return None
    if r.status_code >= 400:
        raise Fail(f"{method} {path} -> {r.status_code}: {r.text[:1500]}")
    return r.json() if r.text else {}


def all_pages(path, params=None):
    out, url, p = [], path, dict(params or {})
    while url:
        page = call("GET", url, params=p)
        out += page.get("data", [])
        url, p = (page.get("links") or {}).get("next"), None
    return out


def step(name):
    def wrap(f):
        def run(*a):
            print(f"\n== {name}")
            try:
                return f(*a)
            except Fail as e:
                print(f"!! {e}")
                failures.append(name)
        return run
    return wrap


def territories():
    return [t["id"] for t in all_pages("/v1/territories", {"limit": 200})]


# ---- the tips ----

def tip(app, terr, pid, ref, name, desc, price):
    existing = [i for i in all_pages(f"/v1/apps/{app}/inAppPurchasesV2", {"limit": 200, "filter[productId]": pid})]
    if existing:
        iap = existing[0]["id"]
        print(f"{pid}: exists ({existing[0]['attributes'].get('state')})")
    else:
        iap = call("POST", "/v2/inAppPurchases", {"data": {
            "type": "inAppPurchases",
            "attributes": {"name": ref, "productId": pid, "inAppPurchaseType": "CONSUMABLE", "reviewNote": REVIEW_NOTE},
            "relationships": {"app": {"data": {"type": "apps", "id": app}}}}})["data"]["id"]
        print(f"{pid}: created")

    locs = all_pages(f"/v2/inAppPurchases/{iap}/inAppPurchaseLocalizations")
    if not any(l["attributes"].get("locale") == "en-US" for l in locs):
        call("POST", "/v1/inAppPurchaseLocalizations", {"data": {
            "type": "inAppPurchaseLocalizations",
            "attributes": {"locale": "en-US", "name": name, "description": desc},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}}}})
        print(f"{pid}: name and description")

    sched = call("GET", f"/v2/inAppPurchases/{iap}/iapPriceSchedule", missing_ok=True)
    has_price = False
    if sched and sched.get("data"):
        has_price = bool(all_pages(f"/v1/inAppPurchasePriceSchedules/{sched['data']['id']}/manualPrices"))
    if not has_price:
        points = all_pages(f"/v2/inAppPurchases/{iap}/pricePoints", {"filter[territory]": "USA", "limit": 200})
        point = next((p for p in points if float(p["attributes"]["customerPrice"]) == float(price)), None)
        if not point:
            raise Fail(f"{pid}: no US price point at {price}")
        call("POST", "/v1/inAppPurchasePriceSchedules", {
            "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]}}},
            "included": [{"type": "inAppPurchasePrices", "id": "${price}", "attributes": {"startDate": None},
                          "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}},
                                            "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point["id"]}}}}]})
        print(f"{pid}: price {price} (US base, the App Store's equivalents elsewhere)")

    av = call("GET", f"/v2/inAppPurchases/{iap}/inAppPurchaseAvailability", missing_ok=True)
    if not (av and av.get("data")):
        call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
            "type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": True},
            "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap}},
                              "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
        print(f"{pid}: available in {len(terr)} territories")

    shot = call("GET", f"/v2/inAppPurchases/{iap}/appStoreReviewScreenshot", missing_ok=True)
    if not (shot and shot.get("data")):
        data = open(SCREENSHOT, "rb").read()
        res = call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots",
            "attributes": {"fileName": "tips_review.png", "fileSize": len(data)},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}}}})["data"]
        for op in res["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            r = requests.request(op["method"], op["url"], data=chunk, headers=headers, timeout=120)
            if r.status_code >= 400:
                raise Fail(f"{pid}: screenshot upload -> {r.status_code}: {r.text[:500]}")
        call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{res['id']}", {"data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots", "id": res["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(f"{pid}: review screenshot")

    state = call("GET", f"/v2/inAppPurchases/{iap}")["data"]["attributes"].get("state")
    print(f"{pid}: state {state}")
    if os.environ.get("SUBMIT_TIPS") == "true" and state == "READY_TO_SUBMIT":
        call("POST", "/v1/inAppPurchaseSubmissions", {"data": {
            "type": "inAppPurchaseSubmissions",
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap}}}}})
        print(f"{pid}: submitted for review")


# ---- the app ----

@step("age rating")
def age_rating(app):
    infos = all_pages(f"/v1/apps/{app}/appInfos")
    editable = [i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState"))
                not in ("READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "REPLACED_WITH_NEW_INFO")] or infos
    decl = call("GET", f"/v1/appInfos/{editable[0]['id']}/ageRatingDeclaration")["data"]
    attrs = {}
    for k, v in decl["attributes"].items():
        if k in FREQUENCY and v != "NONE":
            attrs[k] = "NONE"
        elif k in NO and v is not False:
            attrs[k] = False
    left = [k for k, v in decl["attributes"].items() if v is None and k not in FREQUENCY | NO]
    if attrs:
        call("PATCH", f"/v1/ageRatingDeclarations/{decl['id']}", {"data": {
            "type": "ageRatingDeclarations", "id": decl["id"], "attributes": attrs}})
    print(f"set {len(attrs)} answers; not answered here (optional): {left}")


@step("price: free")
def price(app):
    sched = call("GET", f"/v1/apps/{app}/appPriceSchedule", missing_ok=True)
    if sched and sched.get("data") and all_pages(f"/v1/appPriceSchedules/{sched['data']['id']}/manualPrices"):
        print("already set")
        return
    points = all_pages(f"/v1/apps/{app}/appPricePoints", {"filter[territory]": "USA", "limit": 200})
    free = next(p for p in points if float(p["attributes"]["customerPrice"]) == 0)
    call("POST", "/v1/appPriceSchedules", {
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": app}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
        "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]})
    print("free")


@step("availability: every territory")
def availability(app, terr):
    if call("GET", f"/v1/apps/{app}/appAvailabilityV2", missing_ok=True):
        print("already set")
        return
    ids = [f"${{t{i}}}" for i in range(len(terr))]
    call("POST", "/v2/appAvailabilities", {
        "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True},
                 "relationships": {"app": {"data": {"type": "apps", "id": app}},
                                   "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": i} for i in ids]}}},
        "included": [{"type": "territoryAvailabilities", "id": i, "attributes": {"available": True},
                      "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for i, t in zip(ids, terr)]})
    print(f"{len(terr)} territories")


@step("content rights")
def content_rights(app, current):
    if current:
        print(f"already {current}")
        return
    call("PATCH", f"/v1/apps/{app}", {"data": {"type": "apps", "id": app,
                                               "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
    print("no third-party content")


def main():
    apps = call("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE})["data"]
    if not apps:
        sys.exit(f"No App Store Connect app for {BUNDLE}")
    app = apps[0]["id"]
    print(f"{BUNDLE}: app {app}")
    terr = territories()
    for t in TIPS:
        step(f"tip {t[0]}")(tip)(app, terr, *t)
    age_rating(app)
    price(app)
    availability(app, terr)
    content_rights(app, apps[0]["attributes"].get("contentRightsDeclaration"))
    if failures:
        sys.exit(f"\nNot done: {', '.join(failures)} (see above)")
    print("\nAll set.")


if __name__ == "__main__":
    main()
