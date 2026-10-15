# Notices and credits

XA — Copyright © 2026 Giovanni Lupo. Licensed under the GNU GPL version 3 with the additional
permission in `EXCEPTION.md`.

## Roll

XA builds on [Roll](https://github.com/gi-os/Roll) (MIT), an earlier camera app by the same author.

## spektrafilm

Film modeling in XA is powered by, and inspired by, spektrafilm: a spectral simulation of analog
photography from published film datasheets.

- Author: Andrea Volpato.
- Source: https://github.com/andreavolpato/spektrafilm
- License: spektrafilm code is GPL version 3. Its stock profiles, and the LUTs and other tables made
  from them, are [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The licensor's notice
  is in `XA/Resources/Stocks/SPEKTRAFILM_LICENSE.txt`.

Derived from spektrafilm by Andrea Volpato, https://github.com/andreavolpato/spektrafilm, licensed
CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/). Modified by Giovanni Lupo.

What was modified: the colour film tables in `XA/Resources/Stocks` were generated from spektrafilm and
changed in the process. Each stock's spectral model was baked into two 33×33×33 colour tables (the
`*_film.bin` and `*_print.bin` files), and `stocks.json` and `grain.json` hold values XA added or
fitted: exposure, gain, push and pull offsets, and grain. Ludlow 1600 uses a profile XA read from the
film's datasheet, baked with spektrafilm's tools. The three black-and-white stocks (Bleecker,
Delancey, Essex) are XA's own curves, made without spektrafilm data.

Everything in `XA/Resources/Stocks` (the `.bin` tables, `stocks.json` and `grain.json`) is shared
under the same license, CC BY-SA 4.0, with the same credit to spektrafilm. Work in `tools/filmsim`
uses spektrafilm and stays under spektrafilm's licenses.

## Fonts

The fonts in `XA/Resources/Fonts` come from Google Fonts. Their license texts are in
`XA/Resources/Fonts/licenses` and ship inside the app.

- SIL Open Font License 1.1: Anton, Archivo, Bebas Neue, Bungee, Caveat, Chakra Petch,
  Cormorant Garamond, DM Serif Display, Fredoka, IBM Plex Sans Condensed, Mochiy Pop One,
  Nunito, Orbitron, Oxanium, Press Start 2P, Racing Sans One, Righteous, Russo One,
  Saira Extra Condensed, Share Tech Mono, Silkscreen, Space Mono, Stardos Stencil, Unbounded.
- Apache License 2.0: Roboto Condensed (Copyright 2011 Google Inc.), Yellowtail (Astigmatic),
  Permanent Marker (Font Diner, Inc.).

## Film names

Film stock names such as Kodak Portra or Fujifilm are trademarks of their owners and are used
only to say which datasheet a model was built from. XA is not affiliated with or endorsed by them.
