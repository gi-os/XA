"""Fujifilm's 4th colour layer, for spektrafilm bakes.

Superia (Natura) and X-tra carry a fourth emulsion layer sensitive to blue-green light (peak
near 525 nm, the dashed "cyan sensitive layer" on the Superia 1600 datasheet). It holds back the
red-sensitive layer through inhibitor couplers, which acts like the negative red lobe of human
vision: truer greens and violets, and less of a green cast under fluorescent light.

spektrafilm models three layers. Its exposure is linear in the layer sensitivities, so the effect
is added by giving the red layer an effective sensitivity S_red − k·S_cyan. The cyan curve is
read from the datasheet (cyan_layer.json, same scale as the layer curves); k is ours.

Import this module before building a bundle; it patches FilmingStage for the stocks listed in
FOURTH (profile name → k)."""
import json, os
import numpy as np
from spektrafilm.runtime.stages import filming

HERE = os.path.dirname(os.path.abspath(__file__))
CYAN = json.load(open(os.path.join(HERE, 'cyan_layer.json')))   # {"wavelengths": [...], "log_sensitivity": [...]}
FOURTH = {'xa_natura_1600': 0.9, 'fujifilm_xtra_400': 0.9}

from spektrafilm.runtime.stages.filming import (standard_illuminant, compute_band_pass_filter,
                                                rgb_to_raw_hanatos2025, rgb_to_raw_mallett2019)


def _rgb_to_film_raw(self, rgb, *, color_space="sRGB", apply_cctf_decoding=False):
    """spektrafilm's FilmingStage._rgb_to_film_raw, with the red layer inhibited by the 4th layer."""
    sensitivity = np.nan_to_num(10 ** self._film.data.log_sensitivity)
    k = FOURTH.get(self._film.info.stock, 0)
    if k:
        wl = np.asarray(self._film.data.wavelengths, float)
        cyan = 10 ** np.interp(wl, CYAN['wavelengths'], CYAN['log_sensitivity'], left=-10, right=-10)
        sensitivity = sensitivity.copy()
        sensitivity[:, 0] = sensitivity[:, 0] - k * cyan
    if self._camera.filter_uv[0] > 0 or self._camera.filter_ir[0] > 0:
        illuminant = standard_illuminant(self._film.info.reference_illuminant)
        band_pass_filter = compute_band_pass_filter(self._camera.filter_uv, self._camera.filter_ir)
        band_pass_filter = np.tile(band_pass_filter[:, None], (1, 3))
        normalization = np.sum(sensitivity * band_pass_filter * illuminant[:, None], axis=0) / np.sum(sensitivity * illuminant[:, None], axis=0)
        sensitivity *= band_pass_filter / normalization
    if self._settings.rgb_to_raw_method == "hanatos2025":
        tc_lut = self._lut_service.get_filming_tc_lut(sensitivity)
        raw = rgb_to_raw_hanatos2025(rgb, sensitivity, color_space=color_space, apply_cctf_decoding=apply_cctf_decoding,
                                     reference_illuminant=self._film.info.reference_illuminant, tc_lut=tc_lut)
    else:
        raw = rgb_to_raw_mallett2019(rgb, sensitivity, color_space=color_space, apply_cctf_decoding=apply_cctf_decoding,
                                     reference_illuminant=self._film.info.reference_illuminant)
    if k:
        # Pure blue-green light can drive the red exposure below nothing; film can't go below fog.
        raw = np.maximum(raw, 1e-6)
    return raw


filming.FilmingStage._rgb_to_film_raw = _rgb_to_film_raw
