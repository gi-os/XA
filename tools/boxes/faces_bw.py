GRAIN = lambda o: f'<filter id="g" x="0" y="0" width="1" height="1"><feTurbulence type="fractalNoise" baseFrequency="{o}" numOctaves="2" stitchTiles="stitch" result="n"/><feColorMatrix in="n" type="matrix" values=".33 .33 .33 0 0 .33 .33 .33 0 0 .33 .33 .33 0 0 0 0 0 0 1"/></filter>'
F = {}

# DELANCEY 3200: after-dark street film, gritty and soft (Delta 3200's character)
lights = ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" opacity="{o}" filter="url(#bl)"/><circle cx="{x}" cy="{y}" r="{r*0.28:.1f}" fill="#fff"/>'
                 for x, y, r, o in [(70, 92, 22, .55), (150, 70, 16, .45), (196, 118, 12, .4), (104, 150, 10, .35), (176, 46, 9, .35)])
refl = ''.join(f'<rect x="{x}" y="{y}" width="{w}" height="2" fill="#fff" opacity="{o}"/>'
               for x, y, w, o in [(58, 214, 26, .5), (62, 224, 18, .35), (66, 234, 10, .25), (140, 220, 20, .4), (144, 230, 12, .28), (186, 226, 10, .3)])
F['delancey3200'] = (3200, f'''<defs>{GRAIN(1.1)}<filter id="bl" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="9"/></filter>
<linearGradient id="nite" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2a2a2c"/><stop offset=".62" stop-color="#101011"/><stop offset=".64" stop-color="#3a3a3c"/><stop offset="1" stop-color="#18181a"/></linearGradient>
<clipPath id="w"><rect x="24" y="24" width="200" height="248"/></clipPath></defs>
<rect width="640" height="400" fill="#0c0c0d"/>
<rect x="20" y="20" width="208" height="256" fill="#e9e7e2"/>
<g clip-path="url(#w)"><rect x="24" y="24" width="200" height="248" fill="url(#nite)"/>{lights}{refl}
<rect x="24" y="24" width="200" height="248" fill="#000" filter="url(#g)" opacity=".22" style="mix-blend-mode: screen;"/></g>
<path d="M252 52L260.4 22H310.4L302 52Z" fill="#e9e7e2"/>
<text x="281.2" y="45" text-anchor="middle" font-size="23" fill="#0c0c0d" style="font-family: Archivo; font-weight: 800; font-style: italic;">XA</text>
<text x="314" y="45" font-size="22" fill="#e9e7e2" style="font-family: 'Roboto Condensed'; font-weight: 700; letter-spacing: 3px;">PAN · NIGHT</text>
<text x="250" y="128" font-size="74" fill="#e9e7e2" style="font-family: Anton; letter-spacing: 5px;">DELANCEY</text>
<text x="252" y="162" font-size="22" fill="#9a9894" style="font-family: 'Cormorant Garamond'; font-weight: 700; font-style: italic;">after-dark street film · grain you can hear</text>
<text x="248" y="318" font-size="150" fill="#e9e7e2" style="font-family: Anton; letter-spacing: 2px;">{{ei}}</text>
<rect x="0" y="342" width="640" height="3" fill="#d23a2e"/>
<text x="24" y="378" font-size="15" fill="#9a9894" style="font-family: 'Roboto Condensed'; font-weight: 700; letter-spacing: 2px;">BLACK &amp; WHITE NEGATIVE · 135-36 · EI 3200 · PUSHES TO 6400</text>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".06" style="mix-blend-mode: screen;"/>''')

# ESSEX P3200: crisp, contrasty, technical (T-MAX P3200's character)
wedge = ''.join(f'<rect x="592" y="{30 + i * 30}" width="26" height="30" fill="#{v:02x}{v:02x}{v:02x}"/>' for i, v in enumerate(range(250, -1, -27)))
F['essexp3200'] = (3200, f'''<defs>{GRAIN(.9)}<linearGradient id="si" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4f5f6"/><stop offset="1" stop-color="#c7cbd0"/></linearGradient></defs>
<rect width="640" height="400" fill="url(#si)"/>
<path d="M0 0H300L170 400H0Z" fill="#111"/>
<path d="M312 0H330L200 400H182Z" fill="#111"/>
{wedge}<rect x="592" y="30" width="26" height="300" fill="none" stroke="#111" stroke-width="2"/>
<path d="M24 52L32.4 22H82.4L74 52Z" fill="#f4f5f6"/>
<text x="53.2" y="45" text-anchor="middle" font-size="23" fill="#111" style="font-family: Archivo; font-weight: 800; font-style: italic;">XA</text>
<text x="88" y="45" font-size="22" fill="#f4f5f6" style="font-family: 'Roboto Condensed'; font-weight: 700; letter-spacing: 3px;">PAN·T</text>
<text transform="translate(66 330) rotate(-90)" font-size="17" fill="#f4f5f6" opacity=".85" style="font-family: 'Roboto Condensed'; font-weight: 700; letter-spacing: 6px;">MULTI-SPEED</text>
<text x="330" y="118" font-size="110" fill="#111" style="font-family: 'Bebas Neue'; letter-spacing: 6px;">ESSEX</text>
<text x="334" y="150" font-size="17" fill="#3a3d42" style="font-family: 'Roboto Condensed'; font-weight: 700; letter-spacing: 1px;">T-GRAIN · SHOOT AT EI 800–6400</text>
<rect x="276" y="200" width="62" height="106" fill="#111"/>
<text x="307" y="295" text-anchor="middle" font-size="106" fill="#f4f5f6" style="font-family: 'Bebas Neue';">P</text>
<text x="348" y="306" font-size="140" fill="#111" style="font-family: 'Bebas Neue'; letter-spacing: 2px;">{{ei}}</text>
<rect x="0" y="352" width="640" height="48" fill="#111"/>
<text x="210" y="382" font-size="15" fill="#f4f5f6" style="font-family: 'Roboto Condensed'; font-weight: 700; letter-spacing: 2px;">BLACK &amp; WHITE NEGATIVE · 135-36 · PUSH PROCESS</text>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".05" style="mix-blend-mode: overlay;"/>''')

# BLEECKER 400: the classic street film, punchy and forgiving (Tri-X's character)
holes = ''.join(f'<rect x="{x}" y="{12 + i * 26}" width="14" height="16" rx="3" fill="#efe8d8"/>' for x in (12, 124) for i in range(15))
F['bleecker400'] = (400, f'''<defs>{GRAIN(.8)}</defs>
<rect width="640" height="400" fill="#efe8d8"/>
<rect x="0" y="0" width="150" height="400" fill="#141414"/>{holes}
<text transform="translate(94 380) rotate(-90)" font-size="40" fill="#efe8d8" style="font-family: 'DM Serif Display'; letter-spacing: 4px;">BLACK &amp; WHITE</text>
<path d="M176 52L184.4 22H234.4L226 52Z" fill="#141414"/>
<text x="205.2" y="45" text-anchor="middle" font-size="23" fill="#efe8d8" style="font-family: Archivo; font-weight: 800; font-style: italic;">XA</text>
<text x="240" y="45" font-size="22" fill="#141414" style="font-family: 'Roboto Condensed'; font-weight: 700; letter-spacing: 3px;">PAN 400</text>
<text x="174" y="132" font-size="86" fill="#141414" style="font-family: 'DM Serif Display';">Bleecker</text>
<rect x="176" y="148" width="440" height="2" fill="#141414"/><rect x="176" y="154" width="440" height="1" fill="#141414"/>
<text x="178" y="182" font-size="22" fill="#5b554a" style="font-family: 'Cormorant Garamond'; font-weight: 700; font-style: italic;">the Village street film · punchy, forgiving</text>
<text x="174" y="338" font-size="168" fill="#141414" style="font-family: 'DM Serif Display';">{{ei}}</text>
<circle cx="560" cy="290" r="46" fill="none" stroke="#141414" stroke-width="3"/><circle cx="560" cy="290" r="39" fill="none" stroke="#141414" stroke-width="1"/>
<text x="560" y="300" text-anchor="middle" font-size="34" fill="#141414" style="font-family: 'DM Serif Display';">36</text>
<text x="560" y="318" text-anchor="middle" font-size="10" fill="#141414" style="font-family: 'Roboto Condensed'; font-weight: 700; letter-spacing: 2px;">EXP</text>
<text x="178" y="378" font-size="15" fill="#5b554a" style="font-family: 'Roboto Condensed'; font-weight: 700; letter-spacing: 2px;">BLACK &amp; WHITE NEGATIVE · 135-36 · ISO 400/27°</text>
<rect width="640" height="400" fill="#000" filter="url(#g)" opacity=".07" style="mix-blend-mode: overlay;"/>''')
