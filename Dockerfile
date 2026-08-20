# UO Outlands - Unraid/Docker container
#
# Based on the linuxserver.io KasmVNC base image: provides a web desktop
# (browser, no VNC client needed), s6-overlay, PUID/PGID, and /config as
# HOME - exactly the standard Unraid pattern.
#
# The actual game startup logic comes unmodified from the upstream repo
# https://github.com/Hezkore/uo-outlands-appimage (AppDir/AppRun). That
# script downloads GE-Proton and the Outlands launcher into
# /config/uooutlands on first start and then launches straight from the
# Wine prefix.

FROM ghcr.io/linuxserver/baseimage-kasmvnc:ubuntunoble

ARG UPSTREAM_REPO="https://github.com/Hezkore/uo-outlands-appimage.git"
# Pin to a tag/commit for reproducible builds, e.g. UPSTREAM_REF=v0.1.1
ARG UPSTREAM_REF="main"
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="UO Outlands" \
      org.opencontainers.image.description="UO Outlands (Ultima Online shard) via GE-Proton in a KasmVNC web desktop" \
      org.opencontainers.image.source="${UPSTREAM_REPO}"

# GE-Proton needs 32-bit and 64-bit libraries
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      file \
      git \
      procps \
      psmisc \
      python3 \
      tar \
      xz-utils \
      zenity \
      zstd \
      cabextract \
      xdg-utils \
      x11-utils \
      wmctrl \
      xdotool \
      dbus-x11 \
      xfce4-session \
      xfwm4 \
      xfdesktop4 \
      xfce4-panel \
      xfce4-settings \
      xfce4-terminal \
      thunar \
      xfce4-taskmanager \
      libc6:i386 \
      libgcc-s1:i386 \
      libstdc++6:i386 \
      zlib1g:i386 \
      libgl1 libgl1:i386 \
      libglx-mesa0 libglx-mesa0:i386 \
      libgl1-mesa-dri libgl1-mesa-dri:i386 \
      libegl1 libegl1:i386 \
      libgbm1 \
      libvulkan1 libvulkan1:i386 \
      mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
      libglu1-mesa libglu1-mesa:i386 \
      libfreetype6 libfreetype6:i386 \
      libfontconfig1 libfontconfig1:i386 \
      libgnutls30t64 libgnutls30t64:i386 \
      libasound2t64 libasound2t64:i386 \
      libasound2-plugins libasound2-plugins:i386 \
      libpulse0 libpulse0:i386 \
      libdbus-1-3 libdbus-1-3:i386 \
      libudev1 libudev1:i386 \
      libusb-1.0-0 libusb-1.0-0:i386 \
      libglib2.0-0t64 libglib2.0-0t64:i386 \
      libx11-6 libx11-6:i386 \
      libxext6 libxext6:i386 \
      libxrandr2 libxrandr2:i386 \
      libxinerama1 libxinerama1:i386 \
      libxcursor1 libxcursor1:i386 \
      libxi6 libxi6:i386 \
      libxcomposite1 libxcomposite1:i386 \
      libxrender1 libxrender1:i386 \
      libxfixes3 libxfixes3:i386 \
      libxtst6 libxtst6:i386 \
      libxxf86vm1 libxxf86vm1:i386 \
      libsdl2-2.0-0 libsdl2-2.0-0:i386 \
      libncurses6 libncurses6:i386 \
      libtinfo6 libtinfo6:i386 \
      libgcrypt20 libgcrypt20:i386 \
      libkrb5-3 libkrb5-3:i386 \
      libcups2t64 libcups2t64:i386 \
      libodbc2 libodbc2:i386 \
      ocl-icd-libopencl1 ocl-icd-libopencl1:i386 \
      libosmesa6 \
      fonts-liberation \
      fonts-wine \
      xterm \
      && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Fetch the upstream repo into the image. The layout stays exactly what
# AppRun expects in "dev mode": AppDir/AppRun finds ../constants and
# ../lang on its own.
RUN git clone --depth 1 --branch "${UPSTREAM_REF}" "${UPSTREAM_REPO}" /opt/uo-outlands 2>/dev/null || \
    ( git clone "${UPSTREAM_REPO}" /opt/uo-outlands && git -C /opt/uo-outlands checkout "${UPSTREAM_REF}" ) && \
    git -C /opt/uo-outlands rev-parse HEAD > /opt/uo-outlands.rev && \
    rm -rf /opt/uo-outlands/.git && \
    chmod +x /opt/uo-outlands/AppDir/AppRun

# Startup scripts, Openbox autostart/menu, and icon
COPY root/ /

RUN chmod +x /usr/local/bin/uo-outlands \
                 /usr/local/bin/uo-outlands-autostart \
                 /usr/local/bin/uo-outlands-reinstall \
                 /defaults/autostart \
                 /defaults/startwm.sh \
                 /etc/s6-overlay/s6-rc.d/init-uooutlands-config/run

# The XFCE panel applies its default configuration without prompting
ENV XFCE_PANEL_MIGRATE_DEFAULT=1

# Inside the container, KasmVNC listens on 3000 (HTTP) and 3001 (HTTPS).
# Mapped externally to 3010/3011 (see docker-compose.yml and the template).
EXPOSE 3000 3001

VOLUME ["/config"]
