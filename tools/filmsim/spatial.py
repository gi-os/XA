import numpy as np, time, colour, sys, glob
from PIL import Image
from spektrafilm.runtime.params_builder import digest_params, init_params
from spektrafilm.runtime.pipeline import SimulationPipeline
from spektrafilm_lut_creator.bundles import BundleSpec
from spektrafilm_lut_creator.color_spaces import decode_cctf, encode_cctf, input_exposure_gain
from lutpath import load, apply, read_cube
film, paper = 'kodak_portra_400', 'kodak_portra_endura'
spec = BundleSpec(film_profile=film, print_profiles=(paper,), input_color_space="sRGB", output_color_space="sRGB", topology="2lut")
gain = input_exposure_gain("sRGB", spec.stops_above_midgray)
def pipe(spatial, lut_mode=False):
    p = init_params(film, paper)
    p.debug.lut_mode = lut_mode
    p.io.input_color_space = 'sRGB'; p.io.output_color_space = 'sRGB'
    p.io.input_cctf_decoding = False; p.io.output_cctf_encoding = False
    p.io.input_gamut_compress = spec.input_gamut_compress; p.io.output_gamut_compress = spec.output_gamut_compress
    p.camera.auto_exposure = False
    if spatial == 'none': p.debug.deactivate_spatial_effects = True; p.debug.deactivate_stochastic_effects = True
    if spatial == 'det': p.debug.deactivate_stochastic_effects = True
    return SimulationPipeline(digest_params(p))
mode = sys.argv[1]; name = sys.argv[2]; edge = int(sys.argv[3])
img = load(name + '.png', edge)
lin = (decode_cctf(img, 'sRGB') * gain).astype(np.float32)
t = time.time(); out = np.clip(encode_cctf(np.asarray(pipe({'full':'full','nospatial':'none','det':'det'}[mode]).process(lin)), 'sRGB'), 0, 1); dt = time.time() - t
Image.fromarray((out*255+.5).astype(np.uint8)).save(f'sp_{mode}_{name}_{edge}.png')
B = glob.glob('build/lut_bundles/*portra400*2lut*')[0]
L1 = read_cube(glob.glob(B + '/*_film.cube')[0]); L2 = read_cube(glob.glob(B + '/*_print.cube')[0])
fast = apply(L2, np.clip(apply(L1, img), 0, 1))
lab = lambda x: colour.XYZ_to_Lab(colour.sRGB_to_XYZ(x))
de = colour.delta_E(lab(out), lab(fast), method='CIE 2000')
print(mode, name, edge, '%.1fs' % dt, 'dE vs tables mean %.2f p95 %.2f' % (de.mean(), np.percentile(de, 95)), flush=True)
