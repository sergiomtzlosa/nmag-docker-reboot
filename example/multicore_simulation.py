# Simple Multicore / Parallel Micromagnetic Simulation in Nmag
# Run this with: mpiexec -n <N_CORES> nsim example/multicore_simulation.py
# Example:      docker run --rm -v "$(pwd):/io" nmag:latest mpiexec -n 2 nsim example/multicore_simulation.py

import os
import sys
import time
import nmag
from nmag import SI

# Optional MPI diagnostics
try:
    import ocaml
    nodes, rank = ocaml.mpi_status()
    print ">>> Process Rank: %d / %d MPI nodes active <<<" % (rank, nodes)
except Exception as e:
    rank = 0
    nodes = 1
    print ">>> Running in single-process mode (or MPI diagnostics unavailable) <<<"

start_time = time.time()

# 1. Initialize Simulation Object
# In parallel mode, Nmag automatically distributes FEM matrix assembly and solves across MPI ranks.
sim = nmag.Simulation("multicore_sphere_sim")

# 2. Define Magnetic Material (Permalloy: Py)
Py = nmag.MagMaterial(
    name='Py',
    Ms=SI(1e6, 'A/m'),                       # Saturation magnetisation
    exchange_coupling=SI(13.0e-12, 'J/m')   # Exchange coupling constant
)

# 3. Locate and load the mesh file
script_dir = os.path.dirname(os.path.abspath(__file__))
mesh_path = os.path.join(script_dir, "sphere1.nmesh.h5")
if not os.path.exists(mesh_path):
    mesh_path = "sphere1.nmesh.h5"

if not os.path.exists(mesh_path):
    print "Error: Mesh file '%s' not found!" % mesh_path
    sys.exit(1)

if rank == 0:
    print "Loading finite-element mesh from: %s" % mesh_path

sim.load_mesh(
    mesh_path,
    [('sphere', Py)],
    unit_length=SI(1e-9, 'm')                # 1 unit = 1 nanometre
)

# 4. Set Initial Magnetisation uniform in X-direction
sim.set_m([1.0, 0.0, 0.0])

# 5. Set External Applied Magnetic Field (zero field to probe demag field)
sim.set_H_ext([0.0, 0.0, 0.0], SI('A/m'))

# 6. Save spatially resolved and averaged fields
sim.save_data(fields='all')

# 7. Sample the demagnetising field across the diameter of the sphere (-10 nm to +10 nm)
if rank == 0:
    print "\nSampling demag field along X-axis:"
    print "-" * 55
    print "Position x (nm) | H_demag_x (A/m) | Expected (-Ms/3)"
    print "-" * 55

for i in range(-10, 11, 2):
    x_nm = float(i)
    x_m = x_nm * 1e-9
    H_demag = sim.probe_subfield_siv('H_demag', [x_m, 0.0, 0.0])
    
    # In an ideal uniformly magnetised sphere, H_demag = -1/3 * Ms = -3.333e5 A/m
    if rank == 0:
        H_dx = H_demag[0] if H_demag is not None else 0.0
        print "x = %5.1f nm    | %12.4e    | -3.3333e+05" % (x_nm, H_dx)

elapsed = time.time() - start_time
if rank == 0:
    print "-" * 55
    print "Simulation completed successfully in %.2f seconds!" % elapsed
    print ">>> Parallel multicore run finished with %d processes <<<" % nodes
