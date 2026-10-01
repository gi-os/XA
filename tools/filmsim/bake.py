import sys, time
from spektrafilm_lut_creator.builders import BundleBuilder
from spektrafilm_lut_creator.bundles import BundleSpec
film, paper, topo = sys.argv[1], sys.argv[2], sys.argv[3]
spec = BundleSpec(film_profile=film, print_profiles=(paper,), input_color_space="sRGB", output_color_space="sRGB", topology=topo, resolution=33)
t=time.time(); b = BundleBuilder(spec); p = b.write(b.build()); print(p, f'{time.time()-t:.1f}s')
