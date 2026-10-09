#!/bin/bash

# Start the MPICH2 MPD daemon if available and not yet running
if command -v mpdtrace >/dev/null 2>&1; then
    if ! mpdtrace >/dev/null 2>&1; then
        mpd &
        sleep 1
    fi
fi

# If no arguments provided, open an interactive bash shell
if [ $# -eq 0 ]; then
    exec /bin/bash
else
    # Execute the requested command (e.g., nsim, mpiexec, ncol, etc.)
    exec "$@"
fi
