# Nmag Docker Environment

A containerized environment for running the [Nmag](https://nmag-project.github.io/) micromagnetic simulation solver.

---

## 📌 Background & Motivation

**Nmag** is a legacy finite-element micromagnetic simulation package developed at the University of Southampton. It combines **Python 2.7** for script configuration and **OCaml 3.12** for the multi-physics finite element core, alongside strict versions of numerical libraries:
- `PETSc 3.1`
- `Sundials 2.3.0`
- `ParMetis 3.1.1`
- `MPICH2 1.2.1`
- `Qhull 2003.1`
- `HDF5 1.8.7` & `PyTables 2.1.2`

Because modern Linux distributions have newer, incompatible versions of these libraries (and the original download domain `nmag.soton.ac.uk` is no longer active), running Nmag inside a container is the most reliable way to execute simulations without dependency conflicts.

---

## 📁 Repository Structure

| File | Description |
| :--- | :--- |
| [`Dockerfile`](Dockerfile) | **Recommended.** Builds Nmag 0.2.1 using the self-contained archive (`nmag-0.2.1.tar.gz`), compiling all pinned libraries hermetically. |
| [`Dockerfile.core`](Dockerfile.core) | Builds Nmag core (`nmag-core-0.2.1.tar.gz`) against system packages from Ubuntu repositories, as outlined in the small tarball guide. |
| [`entrypoint.sh`](entrypoint.sh) | Container entrypoint that initializes the MPICH2 `mpd` daemon and handles argument forwarding. |
| [`docker-compose.yml`](docker-compose.yml) | Compose configuration for easy mounting and running. |
| [`Makefile`](Makefile) | Quick commands for building, running, and testing. |
| [`example/test_nmag.py`](example/test_nmag.py) | Self-contained Python script to verify Nmag installation. |
| [`example/multicore_simulation.py`](example/multicore_simulation.py) | **Multicore simulation example** running in parallel across multiple MPI ranks. |
| [`example/sphere1.py`](example/sphere1.py) | Full sample micromagnetic simulation script. |
| [`example/sphere1.nmesh.h5`](example/sphere1.nmesh.h5) | Sample finite element mesh representing a nanosphere. |

---

## 🚀 Quick Start Guide

### 1. Build the Docker Image

Because compilation takes 15–20 minutes, `make build` and `make build-core` automatically run in a **detached GNU `screen` session** and log to file:

```bash
# Launch build in a detached screen session (safe against terminal disconnects)
make build

# Reattach to the running build screen
make attach

# Or follow the live log in real time
make logs
```

*(To run directly in the foreground without screen, use `make build-fg` or `docker build -t nmag:latest .`)*

> **Note on Build Duration:** Compiling Nmag and its bundled components (PETSc, Sundials, OCaml, Python, MPICH2) from source takes approximately 10–25 minutes depending on CPU performance. Using `screen` ensures the compilation continues uninterrupted if SSH or the terminal disconnects.

---

### 2. Verify the Installation

Run the basic verification script:

```bash
docker run --rm -v "$(pwd):/io" nmag:latest nsim example/test_nmag.py
```

---

### 3. Running Multicore Parallel Simulations (MPI)

Nmag natively supports multicore and cluster execution via MPI. The container automatically initializes the MPICH2 `mpd` daemon on startup through `entrypoint.sh`.

To run the multicore simulation across **4 CPU cores**:

```bash
docker run --rm -v "$(pwd):/io" nmag:latest mpiexec -n 4 nsim example/multicore_simulation.py
```

*(Or via Makefile: `make multicore CORES=4`)*

#### Expected Multicore Output:
```text
>>> Process Rank: 0 / 4 MPI nodes active <<<
>>> Process Rank: 1 / 4 MPI nodes active <<<
>>> Process Rank: 2 / 4 MPI nodes active <<<
>>> Process Rank: 3 / 4 MPI nodes active <<<
Loading finite-element mesh from: .../sphere1.nmesh.h5

Sampling demag field along X-axis:
-------------------------------------------------------
Position x (nm) | H_demag_x (A/m) | Expected (-Ms/3)
-------------------------------------------------------
x = -10.0 nm    |  -3.3289e+05    | -3.3333e+05
x =  -8.0 nm    |  -3.3312e+05    | -3.3333e+05
x =   0.0 nm    |  -3.3331e+05    | -3.3333e+05
x =  10.0 nm    |  -3.3291e+05    | -3.3333e+05
-------------------------------------------------------
Simulation completed successfully in 3.42 seconds!
>>> Parallel multicore run finished with 4 processes <<<
```

---

### 4. Interactive Usage Modes

#### A. Interactive Bash Shell
To enter the container with your current workspace mounted at `/io`:

```bash
docker run --rm -it -v "$(pwd):/io" nmag:latest
```

*(Or on Windows PowerShell: `docker run --rm -it -v "${PWD}:/io" nmag:latest`)*

#### B. Interactive Nmag Python Prompt (`nsim`)
To launch the interactive IPython shell for Nmag:

```bash
docker run --rm -it -v "$(pwd):/io" nmag:latest nsim
```

---

## 🛠 Using Docker Compose

```bash
# Build the image
docker compose build

# Start an interactive container
docker compose run --rm nmag

# Execute a simulation
docker compose run --rm nmag nsim example/multicore_simulation.py
```

---

## 💡 "All Tarball" vs. "Core (Small) Tarball"

- **`Dockerfile` (All-in-one Tarball):**
  Uses `nmag-0.2.1.tar.gz`. It bundles the exact source code for every required component (PETSc, Sundials, OCaml, Python 2.7, MPICH2, PyTables, NumPy). This ensures 100% ABI compatibility, avoids repository deprecation issues, and is the official approach recommended by the Nmag creators.

- **`Dockerfile.core` (Small Tarball):**
  Uses `nmag-core-0.2.1.tar.gz` and installs pre-compiled libraries via Ubuntu APT packages (`libpetsc3.1-dev`, `python-tables`, etc.) plus compilation of `sundials-2.3.0`.
  To build this variant, run:
  ```bash
  docker build -t nmag:core -f Dockerfile.core .
  ```

---

## 🧹 Cleanup Commands

The [`Makefile`](Makefile) provides simple targets to delete simulation outputs, running containers, and images:

```bash
# Delete simulation output data (*.ndt, *.log, *.h5, *.vtk, *.pyc)
make clean

# Stop and delete any running or stopped Nmag containers
make clean-containers

# Delete the Nmag Docker images
make clean-images

# Full purge: remove all simulation outputs, containers, and images
make clean-all
```
