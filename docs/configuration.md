# Configuration reference

### Key settings

| Setting | Value | Why |
| --- | --- | --- |
| `security_opt: seccomp:unconfined` | required | Docker blocks `modify_ldt` by default, without which no 32-bit Wine process starts. |
| `shm_size` / `ulimits.nofile` | `2gb` / `1048576` | Needed by Proton (esync/fsync). |
| `/config` volume | e.g. `./appdata` | Plan for at least **20 GB** free space. |
| Ports 3010/3011 → 3000/3001 | web desktop (HTTP/HTTPS) | |

### Environment variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `PUID` / `PGID` | `99` / `100` | Unraid default (nobody/users) |
| `TZ` | `Europe/Berlin` | Time zone |
| `CUSTOM_USER` / `PASSWORD` | - | Web desktop login. Without a password the WebUI is open - don't expose it to the internet. |
| `AUTOSTART` | `true` | Launcher starts with the container. |
| `RESTART_ON_EXIT` | `false` | Restart the launcher automatically after the game exits. |
| `WINE_DESKTOP_SIZE` | `1280x800` | Game window size (virtual Wine desktop). `auto` = current resolution. |
| `WINE_VIRTUAL_DESKTOP` | `true` | Keeps the game in its own window instead of true fullscreen. |
| `WINDOWED_MODE` | `true` | Keeps stripping the fullscreen attribute from the game window. |

## GPU passthrough

Without a GPU, rendering falls back to software (llvmpipe) - usually fine for this 2D
game, but costs CPU. To pass through an Intel/AMD iGPU:

```yaml
devices:
  - /dev/dri/card0:/dev/dri/card0
  - /dev/dri/renderD128:/dev/dri/renderD128
group_add:
  - "<host GID of the video group>"
  - "<host GID of the render group>"    # omit if identical to the video GID
```

Pass only the specific card/render node that belongs to the real GPU, not the whole
`/dev/dri` directory. Some hosts (e.g. Unraid VMs) expose a second, unrelated DRM device
(such as a virtual `vkms` card) alongside the real one - `ls -l /dev/dri` inside the
container shows it: the real GPU node is normally owned by `root:<group>` with mode `660`
(e.g. `card0`), while an unrelated virtual node is often world-writable (`crw-rw-rw-`,
e.g. `card1`/`renderD129`). If both are visible, Mesa may pick the wrong one and the game
window silently never appears, even though the GPU was "found".

The `group_add` entries are required, not optional. On the host, `/dev/dri/renderD*` is
owned by `root:render` (mode 660); without matching group membership the container can
*see* the device but can't open it. Symptom: the startup log reports a GPU was found, but
the game window never appears. On some hosts `video` and `render` share the same GID - in
that case one `group_add` entry is enough. Find the correct GIDs on the host with:

```bash
stat -c '%g' /dev/dri/card0 /dev/dri/renderD128
```

Force software rendering regardless with `UOOUTLANDS_FORCE_SOFTWARE_GL=1`.

## Building the image yourself

```bash
git clone https://github.com/layer0180/outlands-docker.git
cd outlands-docker
docker build -t uo-outlands:latest .
```

Optionally pin to a specific upstream version:

```bash
docker build --build-arg UPSTREAM_REF=v0.1.1 -t uo-outlands:latest .
```

GE-Proton and the game client are **not** part of the image - they're downloaded to
`/config` on first container start.

## Troubleshooting

| Symptom | Cause / Fix |
| --- | --- |
| GPU found in the log, but no game window appears | Missing `group_add` for the host's video/render GIDs - see [GPU passthrough](#gpu-passthrough). |
| Launcher starts twice | Rebuild the image; an older image restores the saved XFCE session. |
| "already running" after a hard container stop | The lock directory `/config/uooutlands/.lock` is removed automatically on start; delete it by hand if it persists. |
| Client won't start, `launch.log` shows Wine crashes | `--security-opt seccomp=unconfined` is missing. |
| Black window / very slow | Software rendering - see [GPU passthrough](#gpu-passthrough). |
| Download aborts | Delete the partial file (`/config/uooutlands/Outlands.exe` or `proton-download.tar.gz`) and restart the launcher. |
| Reset everything | Right-click → *Reinstall*, or delete `/config/uooutlands`. |

Logs: `docker logs uo-outlands` (container start, s6), `/config/uooutlands/container.log`
(wrapper), `/config/uooutlands/launch.log` (Proton/Wine).
