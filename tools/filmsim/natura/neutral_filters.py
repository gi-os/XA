"""Find the enlarger's neutral filtration for a film on a paper: the yellow and magenta that
print an 18% grey as grey. spektrafilm keeps these per film in neutral_print_filters.json."""
import json, sys
import numpy as np
from scipy.optimize import minimize
from spektrafilm.runtime.params_builder import digest_params, init_params
from spektrafilm.runtime.pipeline import SimulationPipeline

film, paper = sys.argv[1], sys.argv[2]
grey = np.full((4, 4, 3), 0.184, np.float32)

def out(m, y):
    p = init_params(film, paper)
    p.settings.neutral_print_filters_from_database = False
    p.enlarger.m_filter_neutral, p.enlarger.y_filter_neutral = float(m), float(y)
    p.io.input_color_space = 'sRGB'; p.io.output_color_space = 'sRGB'
    p.io.input_cctf_decoding = False; p.io.output_cctf_encoding = False
    p.debug.deactivate_spatial_effects = True; p.debug.deactivate_stochastic_effects = True
    p.camera.auto_exposure = False
    return np.asarray(SimulationPipeline(digest_params(p)).process(grey))[2, 2]

def cast(v):
    rgb = out(*v)
    return float(np.sum((np.log(np.maximum(rgb, 1e-4)) - np.log(np.maximum(rgb.mean(), 1e-4))) ** 2))

r = minimize(cast, x0=np.array([60.0, 60.0]), method='Nelder-Mead', options={'xatol': 0.05, 'fatol': 1e-6, 'maxiter': 120})
m, y = r.x
print(json.dumps({'film': film, 'paper': paper, 'c': 0.0, 'm': round(float(m), 3), 'y': round(float(y), 3), 'grey_out': out(m, y).round(4).tolist()}))
