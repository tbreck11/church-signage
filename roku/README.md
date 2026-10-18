# Church Signage — Roku app

The Roku side of [church-signage](https://github.com/tbreck11/church-signage). It shows the slides that `schedule.json` in that repo says should be on screen, and checks for changes every 5 minutes. Day-to-day content changes happen in the content manager page, not here.

## Remote behavior

- **Back** or **OK**: reload the schedule and images from GitHub right away. The app stays open.
- Every other button is ignored, so a bumped remote won't knock the board off the screen. Roku never lets an app block **Home**.

## Deploy

1. Enable Developer Mode on each Roku (remote: **Home ×3, Up ×2, Right, Left, Right, Left, Right**) and set a developer password.
2. Edit `deploy.json` (copy `deploy.example.json` if it's missing). Put the developer password in `rokuPassword`. Add each TV's IP address to `rokuIps`. If one TV has a different password, give it its own entry under `passwords`.
3. From this folder, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1
```

To update only certain TVs, pass their IPs. They override `rokuIps`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1 -RokuIp 192.168.1.50,192.168.1.51
```

macOS / Linux: `scripts/deploy.sh [ip ...]`.

The script builds `out/church-signage.zip` and uploads it to `http://<roku-ip>/plugin_install` on each TV. If one TV fails, it still updates the others, then lists the ones that failed. Pass `-ZipOnly` (or `--zip-only`) to only build the zip, which you can upload by hand at `http://<roku-ip>` in a browser.

A Roku holds only one sideloaded app at a time, so deploying replaces any other dev app on that TV, such as the media dashboard.

`deploy.json` holds the password and is git-ignored. Never commit it.

## Settings

`source/Config.brs` sets which GitHub repo to read, how often to refresh (`refreshIntervalSeconds`), and the download timeout (`requestTimeoutSeconds`).

## Debugging

To see `print` output and crash logs, run `telnet <roku-ip> 8085`.
