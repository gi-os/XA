#!/usr/bin/env python3
"""Raw App Store screenshots from the simulator, through XA's demo feed.

The simulator has no camera. A debug build reads XA_DEMO_PHOTO and feeds that picture through
the real viewfinder and develop (see CameraModel's demo extension), so every screenshot is XA's
own rendering of a real photo. Each scene below sets the app's saved settings, launches it on
the picture and takes a screenshot.

    python3 tools/screenshots/capture.py <XA.app> <photos dir> <out dir> [scene ...]

Build the app first (Debug, iPhone simulator). Use a 6.9-inch simulator (iPhone 17 Pro Max:
1320 x 2868) for the App Store's required size. Swap the photos for your own and run it again.
"""
import json, os, subprocess, sys, time

DEVICE = os.environ.get("XA_SIM", "iPhone 17 Pro Max")
BUNDLE = "com.gios.xa"


def stack(sim, look=0, shape=0, push=None):
    s = {"simID": sim, "look": look, "shape": shape}
    if push:
        s["pushStops"] = push
    return s


# name: photo file, mode, saved settings. Data values (dicts) are written as JSON data, like the app saves them.
SCENES = {
    "digi": {"photo": "ferris-wheel-1.jpg", "mode": "digi", "set": {"stack": stack("nocturne"), "digiOSD": True}},
    "film": {"photo": "beach-sunset-1.jpg", "mode": "film", "set": {"filmStack": stack("bowery400")}},
    "sims": {"photo": "palms-1.jpg", "mode": "digi", "set": {"stack": stack("prima"), "digiOSD": False}},
    "video": {"photo": "road-trip-1.jpg", "mode": "video", "set": {"videoLook": 4, "stack": stack("neutral")}},  # 4 = VHS
    "booth": {"photo": "dog-1.jpg", "mode": "booth", "set": {}},
    "pro": {"photo": "mountain-lake-1.jpg", "mode": "pro", "set": {}},
    "dates": {"photo": "snow-street-1.jpg", "mode": "digi",
              "set": {"stack": stack("visage"), "digiOSD": False,
                      "dateConfig": {"style": "dots", "placement": "corner", "format": "own", "time": False}}},
    "shapes": {"photo": "flowers-1.jpg", "mode": "digi", "set": {"stack": stack("prima", shape=2), "digiOSD": False}},  # 2 = Porthole
    "night": {"photo": "concert-1.jpg", "mode": "film", "set": {"filmStack": stack("canal500t")}},
    "diner": {"photo": "diner-1.jpg", "mode": "digi", "set": {"stack": stack("nocturne", look=1), "digiOSD": True}},
}


def sh(*a, check=True):
    return subprocess.run(a, check=check, capture_output=True, text=True)


PREFS = None  # the app's own preferences file: an app reads its defaults from its container


def prefs():
    global PREFS
    if PREFS is None:
        c = sh("xcrun", "simctl", "get_app_container", DEVICE, BUNDLE, "data").stdout.strip()
        PREFS = os.path.join(c, "Library", "Preferences", BUNDLE)
    return PREFS


def write_default(key, value):
    if isinstance(value, bool):
        args = ["-bool", "true" if value else "false"]
    elif isinstance(value, int):
        args = ["-int", str(value)]
    elif isinstance(value, dict):
        args = ["-data", json.dumps(value, separators=(",", ":")).encode().hex()]
    else:
        args = ["-string", str(value)]
    sh("xcrun", "simctl", "spawn", DEVICE, "defaults", "write", prefs(), key, *args)


def capture(app, photos, out, name):
    s = SCENES[name]
    # FILM's finder develops through the whole lab for its first seconds: slow on the simulator
    wait = 16.0 if s["mode"] == "film" else 9.0
    sh("xcrun", "simctl", "terminate", DEVICE, BUNDLE, check=False)
    write_default("openIn", "last")
    write_default("mode", s["mode"])
    for k, v in s["set"].items():
        write_default(k, v)
    env = dict(os.environ, SIMCTL_CHILD_XA_DEMO_PHOTO=os.path.join(photos, s["photo"]))
    subprocess.run(["xcrun", "simctl", "launch", DEVICE, BUNDLE], env=env, check=True, capture_output=True)
    time.sleep(wait)
    path = os.path.join(out, f"raw-{name}.png")
    sh("xcrun", "simctl", "io", DEVICE, "screenshot", "--type=png", path)
    print(path)


# Pictures for the roll: each is shot once, through the real develop, into Photos.
ROLL = [("beach-sunset-1.jpg", "film", {"filmStack": stack("bowery400")}),
        ("palms-1.jpg", "digi", {"stack": stack("prima")}),
        ("ferris-wheel-1.jpg", "digi", {"stack": stack("nocturne")}),
        ("flowers-1.jpg", "digi", {"stack": stack("sunday")}),
        ("dog-1.jpg", "booth", {}),
        ("mountain-lake-1.jpg", "film", {"filmStack": stack("chelsea100")}),
        ("diner-1.jpg", "digi", {"stack": stack("nocturne", look=1)}),
        ("snow-street-1.jpg", "film", {"filmStack": stack("ludlow1600")}),
        ("road-trip-1.jpg", "digi", {"stack": stack("amethyst")}),
        ("skyline-dusk-1.jpg", "film", {"filmStack": stack("canal500t")}),
        ("palms-2.jpg", "digi", {"stack": stack("visage", shape=1)}),
        ("beach-sunset-2.jpg", "digi", {"stack": stack("onyx")})]


def fill_roll(photos):
    for photo, mode, settings in ROLL:
        sh("xcrun", "simctl", "terminate", DEVICE, BUNDLE, check=False)
        write_default("mode", mode)
        write_default("digiOSD", False)
        for k, v in settings.items():
            write_default(k, v)
        env = dict(os.environ, SIMCTL_CHILD_XA_DEMO_PHOTO=os.path.join(photos, photo), SIMCTL_CHILD_XA_DEMO_SHOOT="1")
        subprocess.run(["xcrun", "simctl", "launch", DEVICE, BUNDLE], env=env, check=True, capture_output=True)
        # BOOTH shoots four with a countdown; FILM's drum develop takes a few seconds on the simulator
        time.sleep(30 if mode == "booth" else 22 if mode == "film" else 14)
        print("shot", photo, mode)


if __name__ == "__main__":
    if sys.argv[1] == "--roll":
        sh("xcrun", "simctl", "privacy", DEVICE, "grant", "photos", BUNDLE, check=False)
        fill_roll(sys.argv[2])
        sys.exit(0)
    app, photos, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    sh("xcrun", "simctl", "install", DEVICE, app)
    sh("xcrun", "simctl", "privacy", DEVICE, "grant", "photos", BUNDLE, check=False)
    for name in (sys.argv[4:] or list(SCENES)):
        capture(app, photos, out, name)
