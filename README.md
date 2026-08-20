# uo_outlands_docker

**UO Outlands as a Docker container for Unraid.**

Runs the Windows client of [UO Outlands](https://uooutlands.com) as a Docker container.
Controlled entirely in the browser - the container ships a full web desktop, no VNC client
needed.

![Outlands client in the container](docs/screenshot-client.png)

The actual startup logic (loading GE-Proton, creating the Wine prefix, starting the
launcher) comes unmodified from the upstream project
[Hezkore/uo-outlands-appimage](https://github.com/Hezkore/uo-outlands-appimage) - its
`AppDir/AppRun` runs here inside a container instead of as an AppImage.

All mutable data lives under `/config`.

## Build the image

The image isn't published to any registry - build it locally:

```bash
git clone https://github.com/layer0180/uo_outlands_docker.git
cd uo_outlands_docker
docker build -t uo-outlands:latest .
```

Optionally pin to a specific upstream version:

```bash
docker build --build-arg UPSTREAM_REF=v0.1.1 -t uo-outlands:latest .
```

GE-Proton and the game client are **not** part of the image - they're downloaded to
`/config` on first container start.

## Run it

**Option A - docker-compose**

```bash
docker compose up -d --build
```

**Option B - Unraid template**

Copy `uo-outlands.xml` to `/boot/config/plugins/dockerMan/templates-user/`, then
Docker → *Add Container* → select template `uo-outlands`.

Then open `http://<host-ip>:3010/`.

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
  - /dev/dri:/dev/dri
group_add:
  - "<host GID of the video group>"
  - "<host GID of the render group>"
```

The `group_add` entries are required, not optional. On the host, `/dev/dri/renderD*` is
owned by `root:render` (mode 660); without matching group membership the container can
*see* the device but can't open it. Symptom: the startup log reports a GPU was found, but
the game window never appears. Find the correct GIDs on the host with:

```bash
stat -c '%g' /dev/dri/card0 /dev/dri/renderD128
```

Force software rendering regardless with `UOOUTLANDS_FORCE_SOFTWARE_GL=1`.

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

## License

This repository has no license set yet. The startup logic executed inside the image
comes from [Hezkore/uo-outlands-appimage](https://github.com/Hezkore/uo-outlands-appimage)
and is under its own license; it's cloned at build time, not redistributed here.

## Legal

This project is not affiliated with Ultima Online or UO Outlands. The game client is
downloaded from the official servers at runtime and is not distributed with the image.
