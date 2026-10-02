# Fujifilm's 4th colour layer

Superia/Natura and X-tra have a fourth layer sensitive to blue-green light (the dashed curve,
peak ~520 nm, on the Superia 1600 datasheet). It holds the red-sensitive layer back, like the
negative red lobe of human vision: purer greens and teals, truer violets.

- `read_cyan.py` reads that curve from the datasheet into `cyan_layer.json`.
- `fourth_layer.py` patches spektrafilm's exposure step at bake time so the red layer's
  sensitivity becomes S_red − 0.9·S_cyan for Ludlow (Natura 1600) and Orchard (X-tra 400).
- `neutral_print_filters_4th.json` is the re-fitted grey balance for those two stocks
  (`../natura/neutral_filters.py`, run with the patch imported).

The strength (0.9) is ours: the datasheet gives the layer's sensitivity, not how hard it inhibits.

    PYTHONPATH=tools/filmsim/fourth python -c "import fourth_layer; ..."   # then bake as usual
