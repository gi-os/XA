# Ludlow 1600: Natura 1600 from its datasheet

Natura 1600 was Fujifilm's Superia 1600 in a Japanese box. spektrafilm has no profile for it,
so this folder builds one from Fujifilm's published datasheet (Fujicolor Superia 1600,
AF3-145E):

1. `digitize_superia1600.py` reads the datasheet's characteristic curves, spectral sensitivity
   and spectral dye densities straight out of the PDF's vector paths (no tracing by eye) and
   writes `xa_natura_1600.json`, a spektrafilm film profile.
2. Anything the datasheet does not publish (the three dyes' individual spectra, spectral
   upsampling, the coupler model) is kept from spektrafilm's Fujifilm X-tra 400 profile, the
   closest stock it has. The cyan-sensitive "4th layer" on the datasheet is not modelled.
3. `neutral_filters.py` finds the enlarger filtration that prints 18% grey as grey on Crystal
   Archive paper (`neutral_print_filters_addition.json`), which spektrafilm needs per film.
4. `../bake_xa.py` bakes it with the other stocks.

The profile derives from a CC BY-SA 4.0 profile by Andrea Volpato and is CC BY-SA 4.0 too;
the changes are listed in its metadata. The datasheet itself is Fujifilm's and is not in the repo.
