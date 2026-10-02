# Gio's box faces (StockBoxes HTML, Oct 2026). {ei} and {fit} are filled per speed; the tape and DX
# strip are drawn by the app. Each entry: id, rated, svg body, number fit (x, y, size, maxw, adv, extra).
ARCH = {0: .702, 1: .663, 2: .701, 3: .704, 4: .7, 5: .704, 6: .705, 7: .674, 8: .711, 9: .705}
MARC = {0: .8062, 1: .2949, 2: .5322, 3: .5039, 4: .5732, 5: .4658, 6: .5581, 7: .4888, 8: .5381, 9: .5542}
METAL = '<linearGradient id="{p}-metal" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f6f6f4"/><stop offset=".48" stop-color="#b4b8bd"/><stop offset=".56" stop-color="#8a8f95"/><stop offset="1" stop-color="#e4e6e8"/></linearGradient>'
GRAIN = '<filter id="g" x="0" y="0" width="1" height="1"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" stitchTiles="stitch" result="n"/><feColorMatrix in="n" type="matrix" values=".33 .33 .33 0 0 .33 .33 .33 0 0 .33 .33 .33 0 0 0 0 0 0 1"/></filter>'
def AR(w=100, wt=800, style=''):
    return f"font-family: Archivo; font-weight: {wt}; font-stretch: {w}%;{style}"

FACES = {}

def bowery(id_, rated, band0, band1, ink, sub, num, line, iso, tag):
    return f'''<defs><linearGradient id="band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{band0}"/><stop offset="1" stop-color="{band1}"/></linearGradient>{GRAIN}</defs>
<rect width="640" height="400" fill="{"#f3f2ee" if rated == 400 else "#f3f1f2"}"/>
<rect x="0" y="356" width="640" height="44" fill="{ink}"/>
<text x="236" y="384" font-size="15" fill="#fff" style="{AR(62,600,' letter-spacing: 1px;')}">PROFESSIONAL COLOR NEGATIVE · 135-36 · ISO {iso} · C-41</text>
<path d="M0 0H232L192 400H0Z" fill="url(#band)"/>
<path d="M240 0H246L206 400H200Z" fill="{ink}"/>
<text x="22" y="44" font-size="20" fill="#fff" style="{AR(100,700,' letter-spacing: 2px;')}">135-36</text>
<text transform="translate(58 378) rotate(-90)" font-size="20" fill="#fff" fill-opacity=".92" style="{AR(112,600,' letter-spacing: 7px;')}">PROFESSIONAL</text>
<path d="M272 52L280.4 22H330.4L322 52Z" fill="{ink}"/>
<text x="301.2" y="44.9" text-anchor="middle" font-size="23.4" fill="#fff" style="{AR(110,800,' font-style: italic;')}">XA</text>
<text x="332" y="44.9" font-size="23.4" fill="{ink}" style="{AR(100,700)}">COLOR PRO</text>
<rect x="520" y="24" width="20" height="20" fill="#f1cfb8"/><rect x="544" y="24" width="20" height="20" fill="#dca684"/>
<rect x="568" y="24" width="20" height="20" fill="#b07656"/><rect x="592" y="24" width="20" height="20" fill="#734632"/>
<text x="272" y="126" font-size="64" fill="{ink}" style="font-family: Marcellus; letter-spacing: 10px;">BOWERY</text>
<rect x="272" y="146" width="344" height="2" fill="{ink}"/>
<text x="272" y="170" font-size="17" fill="{sub}" style="font-family: Tinos; font-style: italic;">{tag}</text>
<g transform="{{fit}}"><text x="272" y="330" font-size="160" fill="{num}" style="{AR(112,800)}">{{ei}}</text></g>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".07" style="mix-blend-mode: overlay;"/>'''

FACES['bowery400'] = (400, bowery('bowery400', 400, '#14328f', '#3f7fe0', '#0b1d4d', '#2a4fb8', '#1d4ed8', 0, '400/27°', 'fine grain portrait film'), (272, 330, 160, 342, ARCH, 0, 0), 4)
FACES['bowery800'] = (800, bowery('bowery800', 800, '#3a0f73', '#b03fa8', '#2a0b4f', '#8a2f9c', '#6a2bc4', 0, '800/30°', 'high speed portrait film'), (272, 330, 160, 342, ARCH, 0, 0), 4)

FACES['coney200'] = (200, f'''<defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffc23a"/><stop offset="1" stop-color="#ffa21f"/></linearGradient>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4a2a78"/><stop offset=".45" stop-color="#c8476e"/><stop offset=".85" stop-color="#f59a4a"/><stop offset="1" stop-color="#ffc87a"/></linearGradient>
<linearGradient id="sea" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5a4f86"/><stop offset="1" stop-color="#262a55"/></linearGradient>
{GRAIN}<filter id="blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
<clipPath id="win"><rect x="426" y="44" width="180" height="128"/></clipPath></defs>
<rect width="640" height="400" fill="url(#bg)"/>
<path d="M28 52L37 20H91L82 52Z" fill="#3b1a6b"/>
<text x="59.5" y="44.5" text-anchor="middle" font-size="25" fill="#ffc23a" style="{AR(110,800,' font-style: italic;')}">XA</text>
<text x="91" y="44.5" font-size="25" fill="#3b1a6b" style="{AR(100,700)}">COLOR</text>
<text x="24" y="138" font-size="104" fill="#c8174f" style="font-family: Tinos; font-weight: 700; font-style: italic;">CONEY</text>
<text x="28" y="174" font-size="26" fill="#3b1a6b" style="font-family: Tinos; font-style: italic;">boardwalk color</text>
<rect x="420" y="38" width="192" height="140" fill="#fbf6ea"/>
<g clip-path="url(#win)">
<rect x="426" y="44" width="180" height="128" fill="url(#sky)"/>
<circle cx="520" cy="138" r="36" fill="#ffd89a" opacity=".55" filter="url(#blur)"/>
<circle cx="520" cy="138" r="20" fill="#ffe7b5"/>
<rect x="426" y="140" width="180" height="32" fill="url(#sea)"/>
<rect x="490" y="144" width="60" height="2" fill="#ffd89a" opacity=".7"/><rect x="502" y="151" width="36" height="1.6" fill="#ffd89a" opacity=".55"/><rect x="510" y="158" width="20" height="1.4" fill="#ffd89a" opacity=".4"/>
<text x="598" y="166" text-anchor="end" font-size="12" fill="#ff8a2a" style="{AR(70,600,' letter-spacing: 1px;')}">’97 7 14</text>
</g>
<rect x="0" y="188" width="640" height="6" fill="#c8174f"/><rect x="0" y="197" width="640" height="6" fill="#ff5a1f"/><rect x="0" y="206" width="640" height="6" fill="#3b1a6b"/>
<g transform="{{fit}}"><text x="24" y="338" font-size="160" fill="#3b1a6b" style="{AR(112,800)}">{{ei}}</text></g>
<rect x="520" y="240" width="96" height="56" fill="#3b1a6b"/>
<text x="560" y="279" text-anchor="middle" font-size="32" fill="#ffc23a" style="{AR(112,800)}">24</text>
<text x="597" y="279" text-anchor="middle" font-size="11" fill="#ffc23a" style="{AR(100,700,' letter-spacing: 1px;')}">EXP</text>
<rect x="0" y="352" width="640" height="48" fill="#3b1a6b"/>
<g transform="translate(32 377)" fill="#ffc23a" stroke="#ffc23a" stroke-width="2.2" stroke-linecap="round"><circle r="5.2" stroke="none"/><path d="M0 -11.5V-8.3M0 8.3V11.5M-11.5 0H-8.3M8.3 0H11.5M-8.1 -8.1L-5.9 -5.9M5.9 5.9L8.1 8.1M-8.1 8.1L-5.9 5.9M5.9 -5.9L8.1 -8.1" fill="none"/></g>
<path transform="translate(60 380)" d="M-10 6h19.5a4.6 4.6 0 0 0 .4-9.2a7.2 7.2 0 0 0-13.6-1.6A5.4 5.4 0 0 0-10 6z" fill="#ffc23a"/>
<path transform="translate(86 377)" d="M2.5-12L-7 2h6.5L-3 12 7.5-3H1L3.5-12z" fill="#ffc23a"/>
<text x="112" y="383" font-size="17" fill="#fff" style="{AR(62,600,' letter-spacing: 1px;')}">COLOR PRINT FILM · 135-24 · ISO 200/24° · C-41</text>
<g transform="translate(524 361)"><rect x="0" y="-2" width="92" height="28" rx="2" fill="#fff"/><path d="M4 0h2v22h-2ZM8.5 0h2v22h-2ZM12 0h1v22h-1ZM15.5 0h3v22h-3ZM20 0h1v22h-1ZM23.5 0h1.5v22h-1.5ZM26.5 0h1v22h-1ZM28.5 0h2.5v22h-2.5ZM33.5 0h2v22h-2ZM37 0h2.5v22h-2.5ZM40.5 0h2.5v22h-2.5ZM44 0h1v22h-1ZM46 0h1v22h-1ZM48.5 0h2.5v22h-2.5ZM52 0h2v22h-2ZM56 0h2v22h-2ZM59.5 0h2.5v22h-2.5ZM63.5 0h3v22h-3ZM68.5 0h2v22h-2ZM71.5 0h3v22h-3ZM75.5 0h2v22h-2ZM79.5 0h2v22h-2Z" fill="#141414"/></g>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".08" style="mix-blend-mode: overlay;"/>''', (24, 338, 160, 480, ARCH, 0, 0), 4)

FACES['chelsea100'] = (100, f'''<defs>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f6dd92"/><stop offset=".55" stop-color="#d9a940"/><stop offset="1" stop-color="#b07e26"/></linearGradient>
<linearGradient id="silver" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4f5f7"/><stop offset="1" stop-color="#b9bec6"/></linearGradient>{GRAIN}</defs>
<rect width="640" height="400" fill="#141416"/>
<path d="M0 286L640 136V158L0 308Z" fill="#d93a26"/><path d="M0 312L640 162V184L0 334Z" fill="#ec8a22"/><path d="M0 338L640 188V210L0 360Z" fill="#f2c230"/>
<path d="M24 54L33 22H87L78 54Z" fill="#ecebe6"/>
<text x="55.5" y="46.5" text-anchor="middle" font-size="25" fill="#141416" style="{AR(110,800,' font-style: italic;')}">XA</text>
<text x="90" y="46.5" font-size="25" fill="#ecebe6" style="{AR(100,700)}">COLOR</text>
<text x="616" y="100" text-anchor="end" font-size="72" fill="url(#gold)" style="font-family: Marcellus; letter-spacing: 6px;">CHELSEA</text>
<rect x="320" y="116" width="296" height="1.5" fill="#d9a940"/>
<text x="616" y="138" text-anchor="end" font-size="17" fill="#d9a940" style="font-family: Tinos; font-style: italic;">ultra fine grain</text>
<g transform="{{fit}}"><text x="22" y="304" font-size="188" fill="url(#silver)" style="{AR(112,800)}">{{ei}}</text></g>
<rect x="0" y="352" width="640" height="48" fill="#0b0b0d"/><rect x="0" y="352" width="640" height="1.5" fill="#d9a940"/>
<g transform="translate(30 377)" fill="#d9a940" stroke="#d9a940" stroke-width="2.2" stroke-linecap="round"><circle r="5.2" stroke="none"/><path d="M0 -11.5V-8.3M0 8.3V11.5M-11.5 0H-8.3M8.3 0H11.5M-8.1 -8.1L-5.9 -5.9M5.9 5.9L8.1 8.1M-8.1 8.1L-5.9 5.9M5.9 -5.9L8.1 -8.1" fill="none"/></g>
<path transform="translate(58 380)" d="M-10 6h19.5a4.6 4.6 0 0 0 .4-9.2a7.2 7.2 0 0 0-13.6-1.6A5.4 5.4 0 0 0-10 6z" fill="#d9a940"/>
<text x="84" y="383" font-size="17" fill="#dfe3ea" style="{AR(62,600,' letter-spacing: 1px;')}">ULTRA VIVID COLOR · 135-36 · ISO 100/21° · C-41</text>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".1" style="mix-blend-mode: overlay;"/>''', (22, 304, 188, 400, ARCH, 0, 0), 4)

FACES['prospect200'] = (200, f'''<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7cc1ec"/><stop offset="1" stop-color="#d8eef8"/></linearGradient>{GRAIN}</defs>
<rect width="640" height="268" fill="url(#sky)"/>
<circle cx="548" cy="104" r="40" fill="#f4c443"/>
<path d="M0 226C150 196 300 210 420 228S580 210 640 218V268H0Z" fill="#7cb85a"/>
<path d="M0 250C160 232 320 244 460 256S600 242 640 248V268H0Z" fill="#3f8a3c"/>
<rect x="0" y="268" width="640" height="132" fill="#16307f"/><rect x="0" y="268" width="640" height="4" fill="#f2c230"/>
<path d="M24 52L33 20H87L78 52Z" fill="#16307f"/>
<text x="55.5" y="44.5" text-anchor="middle" font-size="25" fill="#f2c230" style="{AR(110,800,' font-style: italic;')}">XA</text>
<text x="90" y="44.5" font-size="25" fill="#16307f" style="{AR(100,700)}">COLOR</text>
<g transform="{{fit}}"><text x="22" y="214" font-size="170" fill="#16307f" style="{AR(112,800)}">{{ei}}</text></g>
<text x="22" y="342" font-size="78" fill="#fff" style="font-family: Tinos; font-weight: 700; font-style: italic;">PROSPECT</text>
<text x="24" y="382" font-size="16" fill="#cfdcff" style="{AR(62,600,' letter-spacing: 1px;')}">COLOR PRINT FILM · 135-36 · ISO 200/24° · C-41</text>
<rect x="524" y="292" width="92" height="52" fill="#f2c230"/>
<text x="562" y="329" text-anchor="middle" font-size="32" fill="#16307f" style="{AR(112,800)}">36</text>
<text x="600" y="329" text-anchor="middle" font-size="12" fill="#16307f" style="{AR(100,700,' letter-spacing: 1px;')}">EXP</text>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".08" style="mix-blend-mode: overlay;"/>''', (22, 214, 170, 440, ARCH, 0, 0), 4)

SPROCK = ''.join(f'M{8+24*i} 5h12v8h-12Z' for i in range(27))
FACES['canal500t'] = (500, f'''<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0b1030"/><stop offset="1" stop-color="#22134c"/></linearGradient>{GRAIN}</defs>
<rect width="640" height="400" fill="url(#sky)"/>
<path d="M388 268h46v84h-46ZM430 234h38v118h-38ZM466 258h54v94h-54ZM518 210h32v142h-32ZM548 248h52v104h-52ZM598 226h46v126h-46Z" fill="#2b2462"/>
<rect x="0" y="0" width="640" height="18" fill="#120904"/>
<path d="{SPROCK}" fill="#e9a23b"/>
<rect x="0" y="18" width="640" height="44" fill="#e9a23b"/>
<path d="M24 55L32.4 25H82.4L74 55Z" fill="#2a1205"/>
<text x="53.2" y="47.9" text-anchor="middle" font-size="23.4" fill="#e9a23b" style="{AR(110,800,' font-style: italic;')}">XA</text>
<text x="84" y="47.9" font-size="23.4" fill="#2a1205" style="{AR(100,700)}">CINE</text>
<text x="420" y="49" font-size="28" fill="#2a1205" style="font-family: Tinos; font-style: italic;">Tungsten</text>
<text x="616" y="49" text-anchor="end" font-size="22" fill="#2a1205" style="{AR(112,800)}">3200K</text>
<text x="24" y="156" font-size="78" fill="#f1e7d3" style="font-family: Marcellus; letter-spacing: 10px;">CANAL</text>
<rect x="24" y="174" width="316" height="2" fill="#e8455f"/><rect x="24" y="180" width="316" height="1" fill="#57d6dc"/>
<text x="24" y="206" font-size="15" fill="#a7a3c9" style="{AR(100,600,' letter-spacing: 3px;')}">COLOR NEGATIVE · MOTION PICTURE</text>
<g transform="{{fit}}"><text x="24" y="334" font-size="146" fill="#f1e7d3" style="{AR(112,800)}">{{ei}}<tspan font-size="88" dx="4" fill="#e8455f">T</tspan></text></g>
<rect x="0" y="352" width="640" height="48" fill="#07081a"/>
<g transform="translate(30 376)"><path d="M0-11a7 7 0 0 1 4.3 12.5V4.6h-8.6V1.5A7 7 0 0 1 0-11z" fill="#e9a23b"/><path d="M-3.8 7.4h7.6M-2.8 10.4h5.6" stroke="#e9a23b" stroke-width="1.9" stroke-linecap="round"/></g>
<path transform="translate(57 376)" d="M0.13 -10A10 10 0 1 0 9.63 2.68A8 8 0 1 1 0.13 -10Z" fill="#a7a3c9"/>
<text x="84" y="383" font-size="17" fill="#d9d4ea" style="{AR(62,600,' letter-spacing: 1px;')}">MOTION PICTURE · 135-36 · ISO 500/28° · ECN-2</text>
<rect x="548" y="362" width="68" height="28" fill="none" stroke="#a7a3c9" stroke-width="1.5"/>
<text x="582" y="382" text-anchor="middle" font-size="16" fill="#d9d4ea" style="{AR(100,700)}">135·36</text>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".1" style="mix-blend-mode: overlay;"/>''', (24, 334, 146, 384, ARCH, 71, 0), 4)

PERF = ''.join(f'M{-12+18*i} 3h8v5h-8Z' for i in range(38)) + ''.join(f'M{-12+18*i} 28h8v5h-8Z' for i in range(38))
FACES['orchard400'] = (400, f'''<defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#147a84"/><stop offset="1" stop-color="#0e5d68"/></linearGradient>
<linearGradient id="spec" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#e8336f"/><stop offset=".42" stop-color="#f4833a"/><stop offset=".78" stop-color="#f7c843"/><stop offset="1" stop-color="#9fdcc6"/></linearGradient>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fbe7a6"/><stop offset=".55" stop-color="#e2b34e"/><stop offset="1" stop-color="#b98428"/></linearGradient>{GRAIN}</defs>
<rect width="640" height="400" fill="url(#bg)"/>
<path d="M0 262L640 182V352H0Z" fill="url(#spec)"/>
<g transform="translate(0 228) rotate(-7.125)">
<rect x="-20" y="0" width="700" height="36" fill="#0b2633"/>
<path d="{PERF}" fill="#cfe3e0" opacity=".85"/>
<text x="24" y="22" font-size="11" fill="#e2b34e" style="{AR(100,600,' letter-spacing: 3px;')}">XACOLOR ORCHARD 400 · ALL DAY COLOR · XACOLOR ORCHARD 400 · ALL DAY COLOR · XACOLOR ORCHARD 400</text>
</g>
<path d="M24 52L33 20H87L78 52Z" fill="#f2c94c"/>
<text x="55.5" y="44.5" text-anchor="middle" font-size="25" fill="#0b2633" style="{AR(110,800,' font-style: italic;')}">XA</text>
<text x="90" y="44.5" font-size="25" fill="#fff" style="{AR(100,700)}">COLOR</text>
<text x="26" y="96" font-size="30" fill="#f6dc8e" style="font-family: Tinos; font-style: italic;">all day</text>
<text x="22" y="156" font-size="70" fill="url(#gold)" style="font-family: Marcellus; letter-spacing: 6px;">ORCHARD</text>
<rect x="24" y="170" width="380" height="1.5" fill="#e2b34e" opacity=".8"/>
<rect x="524" y="82" width="92" height="52" rx="3" fill="#d7262e" stroke="#e2b34e" stroke-width="2"/>
<text x="562" y="119" text-anchor="middle" font-size="32" fill="#fff" style="{AR(112,800)}">36</text>
<text x="600" y="119" text-anchor="middle" font-size="12" fill="#fff" style="{AR(100,700,' letter-spacing: 1px;')}">EXP</text>
<g transform="{{fit}}"><text x="616" y="338" text-anchor="end" font-size="140" fill="#0b2633" style="{AR(112,800)}">{{ei}}</text></g>
<rect x="0" y="352" width="640" height="48" fill="#0b2633"/>
<text x="26" y="383" font-size="17" fill="#fff" style="{AR(62,600,' letter-spacing: 1px;')}">ALL-DAY COLOR · 135-36 · ISO 400/27° · C-41</text>
<g transform="translate(524 361)"><rect x="0" y="-2" width="92" height="28" rx="2" fill="#fff"/><path d="M4 0h1.5v22h-1.5ZM6.5 0h1v22h-1ZM9.5 0h2v22h-2ZM14 0h2.5v22h-2.5ZM18.5 0h1v22h-1ZM21 0h1.5v22h-1.5ZM25 0h1v22h-1ZM27.5 0h2.5v22h-2.5ZM32.5 0h1v22h-1ZM34.5 0h1v22h-1ZM38 0h2v22h-2ZM41 0h2.5v22h-2.5ZM46 0h1.5v22h-1.5ZM48.5 0h1v22h-1ZM50.5 0h2.5v22h-2.5ZM55 0h3v22h-3ZM59.5 0h2.5v22h-2.5ZM63.5 0h3v22h-3ZM68.5 0h2.5v22h-2.5ZM73 0h2.5v22h-2.5ZM77.5 0h3v22h-3Z" fill="#141414"/></g>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".08" style="mix-blend-mode: overlay;"/>''', (616, 338, 140, 300, ARCH, 0, 0), 4)

TICKS = ''.join(f'M{426+12*i} 299h5v3h-5Z' for i in range(12)) + ''.join(f'M{426+12*i} 332h5v3h-5Z' for i in range(12))
FACES['ludlow1600'] = (1600, f'''<defs>
<linearGradient id="holo" x1="0" y1="-40" x2="640" y2="150" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#a8dccd"/><stop offset=".2" stop-color="#c3b7ea"/><stop offset=".4" stop-color="#f0b9d3"/><stop offset=".58" stop-color="#f5e3a4"/><stop offset=".76" stop-color="#b6e5c6"/><stop offset="1" stop-color="#a6d2ea"/></linearGradient>
<linearGradient id="bronze" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b7a07a"/><stop offset=".55" stop-color="#8c7552"/><stop offset="1" stop-color="#6b573a"/></linearGradient>{GRAIN}</defs>
<rect width="640" height="400" fill="#f7f5f0"/>
<path d="M0 0H640V126C500 126 380 30 0 26Z" fill="url(#holo)"/>
<text x="26" y="106" font-size="26" fill="#1f8a4c" style="font-family: Marcellus; letter-spacing: 7px;">XACOLOR</text>
<text x="22" y="190" font-size="86" fill="url(#bronze)" style="font-family: Marcellus; letter-spacing: 4px;">LUDLOW</text>
<g transform="{{fit}}"><text x="26" y="276" font-size="96" fill="url(#bronze)" style="font-family: Marcellus; letter-spacing: 2px;">{{ei}}</text></g>
<text x="26" y="338" font-size="46" fill="#1d1d1b" style="font-family: Tinos; font-weight: 700;">36</text>
<text x="80" y="338" font-size="19" fill="#1d1d1b" style="font-family: Tinos;">exposures</text>
<text x="26" y="376" font-size="13" fill="#8c877d" style="{AR(62,600,' letter-spacing: 1.5px;')}">COLOR NEGATIVE FILM · 135-36 · ISO 1600/33° · C-41 · FOR NATURAL LIGHT</text>
<rect x="420" y="296" width="156" height="42" fill="#1f8a4c"/>
<path d="{TICKS}" fill="#f7f5f0"/>
<text x="498" y="323" text-anchor="middle" font-size="19" fill="#f7f5f0" style="{AR(100,600)}">Color Film</text>
<text x="412" y="350" text-anchor="end" font-size="15" fill="#1f8a4c" style="{AR(100,700)}">135</text>
<rect x="586" y="292" width="26" height="50" rx="2" fill="none" stroke="#1f8a4c" stroke-width="2.5"/>
<rect x="593" y="284" width="12" height="8" fill="none" stroke="#1f8a4c" stroke-width="2.5"/>
<path d="M592 300V334" stroke="#1f8a4c" stroke-width="1.5"/>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".06" style="mix-blend-mode: overlay;"/>''', (26, 276, 96, 360, MARC, 0, 2), 4)
