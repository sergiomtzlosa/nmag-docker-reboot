# Dockerfile for Nmag micromagnetic simulation environment
# Uses the complete, self-contained distribution ("all" tarball)
# Recommended by Nmag developers for guaranteed dependency compatibility

FROM ubuntu:12.04

LABEL maintainer="Nmag Docker Project"
LABEL description="Nmag 0.2.1 micromagnetic simulation solver with OCaml, PETSc, Sundials, and MPICH2"

# Avoid interactive debconf dialogs
ENV DEBIAN_FRONTEND=noninteractive
ENV NMAG_VERSION=0.2.1

# 1. Update APT sources to old-releases.ubuntu.com (Ubuntu 12.04 is EOL)
#    Install system build prerequisites, including full Python packages
#    (so /usr/bin/python has urllib and full stdlib needed by MPICH2 mpd/mpiexec)
RUN sed -i -re 's/([a-z]{2}\.)?security.ubuntu.com|archive.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python \
        python-dev \
        wget \
        ca-certificates \
        dpkg-dev \
        g++ \
        gcc \
        gfortran \
        make \
        m4 \
        gawk \
        zlib1g-dev \
        libreadline-dev \
        readline-common \
        libx11-dev \
        patch \
        nano && \
    rm -rf /var/lib/apt/lists/*

# 2. Create unprivileged nmag user (UID 1000) for running simulations
RUN useradd -m -s /bin/bash -u 1000 nmag

# 3. Download the self-contained Nmag tarball from the official GitHub archive
#    (Note: original mirror http://nmag.soton.ac.uk is offline; official archive is fangohr/nmag-releases)
WORKDIR /home/nmag
RUN wget --no-check-certificate https://github.com/fangohr/nmag-releases/raw/master/0.2/all/nmag-${NMAG_VERSION}.tar.gz && \
    tar -xzvf nmag-${NMAG_VERSION}.tar.gz && \
    rm nmag-${NMAG_VERSION}.tar.gz && \
    chown -R nmag:nmag /home/nmag/nmag-${NMAG_VERSION}

# 4. Compile Nmag and embedded libraries as user 'nmag'
#    Builds internal Python 2.7, OCaml, PETSc 3.1, Sundials 2.3, MPICH2, ParMetis, etc.
#    'make clean' frees temporary object files to keep image size reasonable
RUN su - nmag -c "cd /home/nmag/nmag-${NMAG_VERSION} && make && make clean"

# 5. Fix MPICH2 Python shebangs and expose binaries and libraries
#    - Point MPICH2 Python scripts (mpd, mpiexec) to /usr/bin/env python
#    - Link binaries to /usr/bin and /usr/local/bin
#    - Link shared libraries to /usr/lib and /usr/local/lib
RUN sed -i 's|^#!.*python.*|#!/usr/bin/env python|' /home/nmag/nmag-${NMAG_VERSION}/lib/mpich2/bin/mp* && \
    ln -sf /home/nmag/nmag-${NMAG_VERSION}/bin/* /usr/bin/ && \
    ln -sf /home/nmag/nmag-${NMAG_VERSION}/bin/* /usr/local/bin/ && \
    ln -sf /home/nmag/nmag-${NMAG_VERSION}/lib/mpich2/bin/* /usr/bin/ && \
    ln -sf /home/nmag/nmag-${NMAG_VERSION}/lib/mpich2/bin/* /usr/local/bin/ && \
    find /home/nmag/nmag-${NMAG_VERSION}/lib -maxdepth 1 -type f -name "*.so*" -exec ln -sf {} /usr/local/lib/ \; && \
    find /home/nmag/nmag-${NMAG_VERSION}/lib -maxdepth 1 -type f -name "*.so*" -exec ln -sf {} /usr/lib/ \; && \
    ldconfig

# 6. Configure MPICH2 MPD daemon secret (/etc/mpd.conf is required by mpdroot, plus user configs)
RUN echo "MPD_SECRETWORD=nmag_secret_pass" > /etc/mpd.conf && \
    chown root:root /etc/mpd.conf && \
    chmod 600 /etc/mpd.conf && \
    echo "MPD_SECRETWORD=nmag_secret_pass" > /home/nmag/.mpd.conf && \
    chown nmag:nmag /home/nmag/.mpd.conf && \
    chmod 600 /home/nmag/.mpd.conf && \
    cp /etc/mpd.conf /root/.mpd.conf && \
    chmod 600 /root/.mpd.conf

# 7. Setup /io directory for host volume mounting
RUN mkdir -p /io && chown -R 1000:1000 /io

# 8. Copy and configure entrypoint script
COPY entrypoint.sh /home/nmag/entrypoint.sh
RUN chmod +x /home/nmag/entrypoint.sh

USER nmag
WORKDIR /io

ENV USER=nmag \
    HOME=/home/nmag \
    PATH=/home/nmag/nmag-0.2.1/bin:/home/nmag/nmag-0.2.1/lib/mpich2/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LD_LIBRARY_PATH=/home/nmag/nmag-0.2.1/lib:/home/nmag/nmag-0.2.1/lib/mpich2/lib:/usr/local/lib:/usr/lib

ENTRYPOINT ["/home/nmag/entrypoint.sh"]
CMD ["/bin/bash"]
