#!/usr/bin/env bash
# Starts the desktop inside the KasmVNC container.
#
# Instead of the bare Openbox from the base image, this runs XFCE: regular
# windows with a title bar, panel, and desktop icon. That makes the game a
# normal window that can be moved and minimized.

# Nvidia GPU support, same as in the base image
if which nvidia-smi >/dev/null 2>&1; then
	export LIBGL_KOPPER_DRI2=1
	export MESA_LOADER_DRIVER_OVERRIDE=zink
	export GALLIUM_DRIVER=zink
fi

# Apply the default panel layout without prompting
export XFCE_PANEL_MIGRATE_DEFAULT=1

exec /usr/bin/startxfce4
