#!/usr/bin/env python3
"""App Store screenshots from the raw ones: a headline and a line under it over the phone.

    python3 tools/screenshots/frame.py spec.json

spec.json: {"out": dir, "fonts": {"headline": ttf or PostScript name, "subline": ...} (optional),
            "upper": true (Latin headlines in capitals), "quality": 92,
            "shots": [{"raw": png, "headline": str, "subline": str, "file": "01_digi.jpg"}, ...]}

1320 x 2868 (6.9-inch iPhone), black like the app, the headline in XA orange. The text is drawn
by caption.swift (Core Text: any system font, e.g. HiraginoSans-W8, PingFangSC-Semibold), the
rest with ImageMagick.
"""
import json, os, subprocess, sys

W, H = 1320, 2868
HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "..", "XA", "Resources", "Fonts")
ORANGE, DIM = "#FF8A2B", "#B8B8BC"
PHONE_W = 1056                      # the screen, 80% of the width
PHONE_TOP = 560
RADIUS = 96                         # the screen's corners at this size
BEZEL = 16


def run(*a):
    subprocess.run(a, check=True)


CAPTION = os.environ.get("XA_CAPTION") or os.path.join(os.environ.get("TMPDIR", "/tmp"), "xa-caption")


def caption_tool():
    if not os.path.exists(CAPTION):
        run("swiftc", "-O", os.path.join(HERE, "caption.swift"), "-o", CAPTION)
    return CAPTION


def frame(shot, out, fonts):
    tmp = out + ".tmp"
    os.makedirs(tmp, exist_ok=True)
    screen = os.path.join(tmp, "screen.png")
    ph = round(PHONE_W * H / W)
    # the screen, rounded
    run("magick", shot["raw"], "-resize", f"{PHONE_W}x{ph}!",
        "(", "+clone", "-alpha", "extract", "-fill", "black", "-colorize", "100",
        "-fill", "white", "-draw", f"roundrectangle 0,0 {PHONE_W - 1},{ph - 1} {RADIUS},{RADIUS}", ")",
        "-alpha", "off", "-compose", "CopyOpacity", "-composite", screen)
    # the phone: a dark bezel round the screen, and a soft shadow under it
    bw, bh = PHONE_W + 2 * BEZEL, ph + 2 * BEZEL
    phone = os.path.join(tmp, "phone.png")
    run("magick", "-size", f"{bw}x{bh}", "xc:none", "-fill", "#1C1C1E",
        "-draw", f"roundrectangle 0,0 {bw - 1},{bh - 1} {RADIUS + BEZEL},{RADIUS + BEZEL}",
        "-fill", "none", "-stroke", "#3A3A3C", "-strokewidth", "3",
        "-draw", f"roundrectangle 2,2 {bw - 3},{bh - 3} {RADIUS + BEZEL - 2},{RADIUS + BEZEL - 2}",
        screen, "-geometry", f"+{BEZEL}+{BEZEL}", "-compose", "over", "-composite", phone)
    shadow = os.path.join(tmp, "shadow.png")
    run("magick", phone, "-background", "black", "-shadow", "70x40+0+30", shadow)
    # the canvas: black, a warm glow behind the phone
    canvas = os.path.join(tmp, "canvas.png")
    run("magick", "-size", f"{W}x{H}", "xc:#000000",
        "(", "-size", f"{W}x{H}", "radial-gradient:#3A2210-#000000", "-gravity", "south", "-crop", f"{W}x{H}+0+0", ")",
        "-compose", "screen", "-composite", canvas)
    x = (W - bw) // 2
    final = os.path.join(out, shot["file"])
    head = fonts.get("headline", os.path.join(FONTS, "Anton-400.ttf"))
    sub = fonts.get("subline", os.path.join(FONTS, "IBMPlexSansCondensed-700.ttf"))
    upper = fonts.get("upper", True)
    htxt, stxt = os.path.join(tmp, "head.png"), os.path.join(tmp, "sub.png")
    run(caption_tool(), head, "150", str(W - 140), "250", ORANGE, htxt, shot["headline"].upper() if upper else shot["headline"])
    run(caption_tool(), sub, "56", str(W - 200), "130", DIM, stxt, shot["subline"])
    run("magick", canvas,
        shadow, "-geometry", f"+{x - 70}+{PHONE_TOP - BEZEL - 70 + 30}", "-compose", "over", "-composite",
        phone, "-geometry", f"+{x}+{PHONE_TOP - BEZEL}", "-compose", "over", "-composite",
        htxt, "-geometry", "+70+120", "-compose", "over", "-composite",
        stxt, "-geometry", "+100+375", "-compose", "over", "-composite",
        "-alpha", "off", "-strip", "-quality", str(fonts.get("quality", 92)), "-sampling-factor", "4:4:4", final)
    print(final)


if __name__ == "__main__":
    spec = json.load(open(sys.argv[1]))
    os.makedirs(spec["out"], exist_ok=True)
    opts = dict(spec.get("fonts", {}))
    for k in ("upper", "quality"):
        if k in spec:
            opts[k] = spec[k]
    for s in spec["shots"]:
        frame(s, spec["out"], opts)
    tmp = spec["out"].rstrip("/") + ".tmp"
    subprocess.run(["rm", "-rf", tmp])
