.PHONY: help build build-core build-fg build-core-fg run nsim test multicore sphere1 compose-up attach attach-core logs logs-core screen-status clean clean-containers clean-images clean-all prune prune-core run-core nsim-core test-core multicore-core sphere1-core

IMAGE_NAME ?= nmag
IMAGE_TAG ?= 0.2.1
CORES ?= 2

SCREEN_NAME ?= nmag-build
SCREEN_CORE_NAME ?= nmag-core-build

help:
	@echo "Nmag Docker Makefile commands:"
	@echo "  make build            - Build Nmag in background screen session ('$(SCREEN_NAME)')"
	@echo "  make build-core       - Build Nmag Core in background screen session ('$(SCREEN_CORE_NAME)')"
	@echo "  make build-fg         - Build Nmag in foreground (standard output)"
	@echo "  make build-core-fg    - Build Nmag Core in foreground (standard output)"
	@echo "  make attach           - Reattach to running build screen session"
	@echo "  make attach-core      - Reattach to running core build screen session"
	@echo "  make logs             - Tail the live build log (build.log)"
	@echo "  make logs-core        - Tail the live core build log (build-core.log)"
	@echo "  make screen-status    - List active screen sessions"
	@echo "  make run              - Open an interactive bash shell in the container"
	@echo "  make run-core         - Open an interactive bash shell in the core container"
	@echo "  make nsim             - Launch the interactive nsim / Python shell"
	@echo "  make nsim-core        - Launch nsim / Python shell in core container"
	@echo "  make test             - Run the test script (example/test_nmag.py)"
	@echo "  make test-core        - Run the test script in core container"
	@echo "  make multicore        - Run parallel simulation on multiple cores (default: CORES=2)"
	@echo "  make multicore-core   - Run parallel simulation in core container (default: CORES=2)"
	@echo "  make sphere1          - Run sphere1 simulation"
	@echo "  make sphere1-core     - Run sphere1 simulation in core container"
	@echo "  make compose-up       - Build and start using docker-compose"
	@echo "  make clean            - Remove simulation output and build log files"
	@echo "  make clean-containers - Stop and remove all Nmag containers"
	@echo "  make clean-images     - Remove Nmag Docker images"
	@echo "  make clean-all        - Delete simulation outputs, containers, and Docker images"
	@echo "  make prune-core       - Remove only nmag:core containers and image"

# Build inside a detached screen session (resilient against network drops)
build:
	@if command -v screen >/dev/null 2>&1; then \
		echo "Starting build in detached screen session '$(SCREEN_NAME)'..."; \
		echo "Live log is being written to: build.log"; \
		screen -dmS $(SCREEN_NAME) bash -c "docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -t $(IMAGE_NAME):latest -f Dockerfile . 2>&1 | tee build.log"; \
		echo "Build is running in the background!"; \
		echo "  -> Attach to screen:  make attach   (or: screen -r $(SCREEN_NAME))"; \
		echo "  -> Watch live log:    make logs     (or: tail -f build.log)"; \
	else \
		echo "'screen' not found on host. Running build in foreground..."; \
		docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -t $(IMAGE_NAME):latest -f Dockerfile .; \
	fi

build-core:
	@if command -v screen >/dev/null 2>&1; then \
		echo "Starting core build in detached screen session '$(SCREEN_CORE_NAME)'..."; \
		echo "Live log is being written to: build-core.log"; \
		screen -dmS $(SCREEN_CORE_NAME) bash -c "docker build -t $(IMAGE_NAME):core -f Dockerfile.core . 2>&1 | tee build-core.log"; \
		echo "Core build is running in the background!"; \
		echo "  -> Attach to screen:  make attach-core (or: screen -r $(SCREEN_CORE_NAME))"; \
		echo "  -> Watch live log:    make logs-core   (or: tail -f build-core.log)"; \
	else \
		echo "'screen' not found on host. Running build in foreground..."; \
		docker build -t $(IMAGE_NAME):core -f Dockerfile.core .; \
	fi

# Foreground builds (standard behavior)
build-fg:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -t $(IMAGE_NAME):latest -f Dockerfile .

build-core-fg:
	docker build -t $(IMAGE_NAME):core -f Dockerfile.core .

# Reattach to running screen sessions
attach:
	screen -r $(SCREEN_NAME)

attach-core:
	screen -r $(SCREEN_CORE_NAME)

# Follow log files
logs:
	tail -f build.log

logs-core:
	tail -f build-core.log

screen-status:
	screen -ls || true

run:
	docker run --rm -it -v "$$(pwd):/io" $(IMAGE_NAME):latest

run-core:
	docker run --rm -it -v "$$(pwd):/io" $(IMAGE_NAME):core

nsim:
	docker run --rm -it -v "$$(pwd):/io" $(IMAGE_NAME):latest nsim

nsim-core:
	docker run --rm -it -v "$$(pwd):/io" $(IMAGE_NAME):core nsim

test:
	docker run --rm -v "$$(pwd):/io" $(IMAGE_NAME):latest nsim example/test_nmag.py

test-core:
	docker run --rm -v "$$(pwd):/io" $(IMAGE_NAME):core nsim example/test_nmag.py

multicore:
	docker run --rm -v "$$(pwd):/io" $(IMAGE_NAME):latest mpiexec -n $(CORES) nsim example/multicore_simulation.py --clean

multicore-core:
	docker run --rm -v "$$(pwd):/io" $(IMAGE_NAME):core mpiexec -n $(CORES) nsim example/multicore_simulation.py --clean

sphere1:
	docker run --rm -v "$$(pwd):/io" $(IMAGE_NAME):latest mpiexec -n $(CORES) nsim example/sphere1.py --clean

sphere1-core:
	docker run --rm -v "$$(pwd):/io" $(IMAGE_NAME):core mpiexec -n $(CORES) nsim example/sphere1.py --clean

compose-up:
	docker compose run --rm nmag

# Delete simulation outputs, logs, and temporary files
clean:
	@echo "Removing simulation outputs and build logs..."
	-rm -f build.log build-core.log *.ndt *.log *.vtk *_dat.h5 example/*.ndt example/*.log example/*.vtk example/*_dat.h5 example/*.pyc *.pyc 2>/dev/null || true

# Stop and remove any running or stopped Nmag containers
clean-containers:
	@echo "Stopping and removing Nmag containers..."
	-docker compose down --remove-orphans 2>/dev/null || true
	-docker rm -f nmag-solver nmag-simulation 2>/dev/null || true
	-docker ps -a -q --filter "ancestor=$(IMAGE_NAME):latest" --filter "ancestor=$(IMAGE_NAME):$(IMAGE_TAG)" --filter "ancestor=$(IMAGE_NAME):core" | xargs -r docker rm -f 2>/dev/null || true

# Remove Docker images (stops containers first to prevent image busy errors)
clean-images: clean-containers
	@echo "Removing Nmag Docker images ($(IMAGE_NAME):latest, $(IMAGE_NAME):$(IMAGE_TAG), $(IMAGE_NAME):core)..."
	-docker rmi -f $(IMAGE_NAME):latest $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):core 2>/dev/null || true

# Delete everything: simulation outputs, logs, containers, and images
clean-all: clean clean-containers clean-images
	@echo "Cleanup complete: simulation outputs, containers, and images have been removed."

prune: clean-all

# Prune only nmag:core containers and image
prune-core:
	@echo "Removing nmag:core containers and image..."
	-docker ps -a -q --filter "ancestor=$(IMAGE_NAME):core" | xargs -r docker rm -f 2>/dev/null || true
	-docker rmi -f $(IMAGE_NAME):core 2>/dev/null || true
	@echo "nmag:core cleanup complete."
