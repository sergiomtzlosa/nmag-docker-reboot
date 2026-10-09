# Standard Nmag micromagnetic simulation test script
# Can be run sequentially or in parallel with MPI (multicore):
#   Sequential: nsim example/sphere1.py
#   Parallel:   mpiexec -n 2 nsim example/sphere1.py

import os
import sys
import nmag
from nmag import SI

print "Initializing Nmag sphere simulation..."

# 1. Create simulation object
sim = nmag.Simulation("sphere_sim")

# 2. Define magnetic material (Permalloy)
Py = nmag.MagMaterial(
    name='Py',
    Ms=SI(1e6, 'A/m'),
    exchange_coupling=SI(13.0e-12, 'J/m')
)

# 3. Resolve mesh file location
script_dir = os.path.dirname(os.path.abspath(__file__))
mesh_file = os.path.join(script_dir, "sphere1.nmesh.h5")
if not os.path.exists(mesh_file):
    mesh_file = "sphere1.nmesh.h5"

if not os.path.exists(mesh_file):
    print "Error: '%s' not found. Please ensure sphere1.nmesh.h5 is in the same folder." % mesh_file
    sys.exit(1)

# 4. Load mesh
sim.load_mesh(
    mesh_file,
    [('sphere', Py)],
    unit_length=SI(1e-9, 'm')
)

# 5. Set initial magnetisation along the x-axis
sim.set_m([1.0, 0.0, 0.0])

# 6. Set external field (zero field)
sim.set_H_ext([0.0, 0.0, 0.0], SI('A/m'))

# 7. Save spatially resolved and averaged fields
sim.save_data(fields='all')

# 8. Sample demag field along the sphere diameter
print "Sampling demag field through sphere along X-axis:"
for i in range(-10, 11, 2):
    x_m = float(i) * 1e-9
    H_demag = sim.probe_subfield_siv('H_demag', [x_m, 0.0, 0.0])
    if H_demag is not None:
        print "x = %5.1f nm : H_demag = %s" % (float(i), H_demag)

print "Simulation finished successfully."
