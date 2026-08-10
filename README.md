# ocearo-cirrus-config

Debian package that turns a Raspberry Pi 5 running [OpenPlotter](https://openmarine.net/openplotter) into the onboard computer of the sailing yacht *Cirrus*: a Chromium kiosk on one or two touchscreens, Signal K reachable over HTTPS, a WiFi that recovers on its own, a clock that survives a power cut, and a PS5 controller as a cockpit helm remote.

Everything here is boat-specific configuration, not application code. The applications it drives live elsewhere:

| Project | Role |
|---|---|
| [ocearo-ui](https://github.com/laborima/ocearo-ui) | 3D navigation interface (HDMI screen) |
| [ocearo-core](https://github.com/laborima/ocearo-core) | Signal K plugin: logbook, anchor, AI copilot, PS5 input |
| [KIP](https://github.com/mxtommy/Kip) | Instrument panel (DSI touchscreen) |

---

## What the package installs

### Services

| Unit | Type | What it does |
|---|---|---|
| `kiosk.service` | long-running | Launches Chromium: KIP on the DSI, ocearo-ui on the HDMI. Detects at startup whether one or two screens are connected and lays out accordingly. |
| `cirrus-certs.service` | oneshot | Generates the self-signed CA and certificates if missing, and trusts them system-wide and in Chromium. Ordered **after `time-sync.target`** — see [Clock](#clock-no-rtc-battery). |
| `wifi-watchdog.service` | long-running | Recovers `wlan0` when the supplicant refuses to associate. See [WiFi](#wifi-recovery). |
| `ollama-power.service` | long-running | Stops Ollama after a long idle to free CPU and RAM. See [Power](#power-management). |
| `ps5-controller.service` | oneshot | Pairs and configures the DualSense controller over Bluetooth. |

### Systemd drop-ins

These exist because **OpenPlotter's Signal K post-install rewrites the unit files** and drops HTTPS. Drop-ins are never touched by OpenPlotter, so they win.

| File | Why |
|---|---|
| `signalk.socket.d/10-ssl-ports.conf` | OpenPlotter rewrites `ListenStream=3000` only, killing HTTPS. The empty `ListenStream=` resets the list, then 3443 (HTTPS) and 3000 (HTTP redirect) are declared. |
| `signalk.service.d/10-ensure-ssl.conf` | Runs `signalk-ensure-ssl.sh` before start to restore `ssl`/`port`/`sslport` in `settings.json` if a tool dropped them, and forces `EXTERNALPORT=3443`. |
| `ollama.service.d/10-cirrus-power.conf` | CPU caps plus `OLLAMA_KEEP_ALIVE=60s` — the default holds the model resident for 5 minutes after every generation, about 1.4 GB of RAM on `llama3.2:1b`. |

### Scripts (`/usr/local/bin`)

`setup-screens.sh` · `kiosk-start.sh` · `setup-certs.sh` · `signalk-ensure-ssl.sh` · `wifi-watchdog.sh` · `ollama-power.sh` · `setup-ps5.sh` · `test-ps5-controller.sh` · `setup-jarvis.sh`

Plus `etc/chromium.d/50-cirrus` (forces `--password-store=basic`, which suppresses the GNOME keyring unlock prompt on a headless kiosk) and `etc/udev/rules.d/99-ps5-controller.rules`.

---

## Installation

```bash
# 1. Add the APT repository
echo "deb [trusted=yes] https://laborima.github.io/ocearo-cirrus-config/ ./" \
  | sudo tee /etc/apt/sources.list.d/cirrusconfig.list

# 2. Install
sudo apt update
sudo apt install cirrusconfig

# 3. Enable the services
sudo systemctl enable --now kiosk cirrus-certs wifi-watchdog ollama-power
sudo systemctl enable --now ps5-controller   # only if you use the controller
```

`ollama-power` is only useful if Ollama is installed; leave it disabled otherwise.

### Verify

```bash
systemctl is-active kiosk cirrus-certs wifi-watchdog ollama-power
curl -sk https://localhost:3443/signalk | head -c 200   # Signal K over HTTPS
```

---

## Screens

Two touchscreens, detected by name rather than by device number — `xinput` ids change on every boot:

| Output | Panel | Touch device | Application |
|---|---|---|---|
| `HDMI-1-1` | 1920×1080 | `ILITEK ILITEK-TP` | ocearo-ui |
| `DSI-2` | 720×1280 (portrait) | `11-005d Goodix Capacitive TouchScreen` | KIP |

**Single-screen mode.** With the HDMI unplugged, `kiosk-start.sh` launches KIP alone, full-screen on the DSI at the origin `xrandr` actually reports — not a hard-coded `1920,0`, which used to push the window off-screen. Plugging the HDMI back in and restarting `kiosk.service` returns to the two-screen layout.

> The kiosk points at `https://localhost:3443`, **not** `https://cirrus.local`. mDNS resolution fails while the WiFi has not associated, and the kiosk would show an error page on a boat with no shore network.

To change what each screen displays, edit `URL_DSI` / `URL_HDMI` in `/usr/local/bin/kiosk-start.sh`.

---

## WiFi recovery

After a cold boot the Pi and the 4G hotspot power up together, and `wpa_supplicant` can get stuck in a loop of `CTRL-EVENT-ASSOC-REJECT status_code=16` — **88 attempts over about 16 minutes** was measured on 2026-07-24. Each failure also trips `CTRL-EVENT-SSID-TEMP-DISABLED`, whose back-off grows exactly when you want it to retry harder. NetworkManager's `autoconnect-retries=0` does not help: it re-runs the same stuck supplicant state.

`wifi-watchdog.sh` cycles the radio (`nmcli radio wifi off/on`) after a grace period, which clears both the association state and the back-off, then brings the highest-priority profile back up. It also disables WiFi power-save persistently in the profile.

Tunable through the environment in the unit: `IFACE` (default `wlan0`), `CHECK_INTERVAL` (20 s), `GRACE` (45 s), `COOLDOWN` (90 s).

```bash
journalctl -u wifi-watchdog -f
```

---

## Clock (no RTC battery)

The Pi 5 has an internal RTC but **no backup battery fitted**, so it boots at 1970 and `fake-hwclock` restores whatever date it last saw — possibly days stale. Without internet nothing corrects it.

Two safety nets:

1. **`cirrus-certs.service` is ordered after `time-sync.target`.** Generating certificates before the clock is correct stamps them with an absurd `notBefore` date, and every HTTPS client then rejects them.
2. **GPS time.** The NMEA2000 bus carries exact UTC (PGN 129029, published as `navigation.datetime`). Install the [`@signalk/set-system-time`](https://www.npmjs.com/package/@signalk/set-system-time) plugin and **enable it** — installed-but-unconfigured is indistinguishable from working in the Signal K admin UI. ocearo-ui additionally derives its own wall clock from that path when the system clock is off.

A backup battery on the Pi 5 J2 connector, with `dtparam=rtc_bbat_vchg=3000000` in `/boot/firmware/config.txt`, is the only thing that would also cover the gap between power-on and the first GPS fix. Not fitted here.

---

## Power management

On a Pi 5 driving two kiosks, a resident Ollama is the heaviest process on the box: 247 % CPU during generation, 83 °C SoC, firmware reporting frequency-capped and throttled.

- `OLLAMA_KEEP_ALIVE=60s` unloads the model shortly after use (~1.4 GB of RAM back).
- `ollama-power.sh` stops the unit entirely after 15 minutes with no loaded model. ocearo-core restarts it on demand before a generation, which costs a few seconds on the first call.

It never stops Ollama while a model is loaded or a request is in flight. Tunable: `CHECK_INTERVAL` (60 s), `IDLE_BEFORE_STOP` (900 s).

```bash
vcgencmd get_throttled   # 0x0 = healthy; any bit set = under-voltage or thermal cap
vcgencmd measure_temp
```

---

## PS5 controller

Used as a helm remote for the autopilot. Pairing and device permissions are handled here; the **button mapping and the autopilot commands live in ocearo-core**, which reads `/dev/input` server-side so the controller keeps working with the screens off.

```bash
# Pairing mode: hold PS + Share for 5 seconds
sudo test-ps5-controller.sh     # verify detection
```

Default mapping (configurable from the ocearo-ui autopilot screen): hold **Cross** to engage, **Circle** to disengage, **D-Pad** ±1°, **L1/R1** ±10°, **left stick** to steer. Engaging requires the button to be *held* so a controller knocked about in the cockpit cannot take the helm; disengaging is always immediate.

### Troubleshooting

```bash
bluetoothctl devices                 # is it paired?
bluetoothctl info <MAC>              # is it connected?
sudo systemctl restart bluetooth
sudo setup-ps5.sh                    # re-run pairing
```

The controller's motion sensors are exposed as a **second input device sharing the same name**, and the `/dev/input/jsN` number changes on every reconnect — which is why ocearo-core locates it by name in `/proc/bus/input/devices` rather than by a fixed path.

---

## SSL certificates

Generated and trusted automatically by `setup-certs.sh`:

| File | Role |
|---|---|
| `/etc/cirrus/certs/rootCA.pem` | Root CA |
| `/etc/cirrus/certs/cirrus.local.pem` | Domain certificate and key |
| `/home/pi/.signalk/ssl/ca.pem` | Root CA for Signal K |
| `/home/pi/.signalk/ssl/key-cert.pem` | Certificate and key for Signal K |

`signalk-ensure-ssl.sh` runs before every Signal K start and repairs `settings.json` when a tool has dropped the SSL keys. It also recovers from a truncated or duplicated `settings.json` — a corruption seen four times on this installation, whose cause is **still not identified**; the script treats the symptom.

---

## Network layout

`wlan0` joins an upstream network (4G hotspot ashore or at sea, marina WiFi in port). A separate access point on `wlan0_ap` serves the boat's own network so phones and tablets can reach Signal K without any upstream connectivity.

Profiles are managed with NetworkManager and are **not** shipped in this package — they hold credentials:

```bash
nmcli connection show
nmcli connection modify <name> connection.autoconnect-priority 10
```

Give the preferred network the highest `autoconnect-priority`; that is the profile `wifi-watchdog` brings back up after cycling the radio.

---

## Development

```bash
sudo apt install build-essential devscripts debhelper
dpkg-buildpackage -us -uc -b     # produces ../cirrusconfig_<version>_all.deb
```

### Release

```bash
dch -i                  # add a changelog entry
git tag vX.Y            # the CI builds and publishes on tags matching v*.*
git push origin vX.Y
```

`.github/workflows/deb.yml` builds the package and publishes the APT repository to GitHub Pages.

> **Keep `debian/cirrusconfig.install` in sync.** It lists every file that goes into the package, and a file present in the source tree but absent from that list is silently dropped. Five files were missing this way until 0.1-4, including the Signal K SSL guard that was actively protecting the production install.

A Docker variant for the Pi 5 is documented separately in [README-docker.md](README-docker.md).

---

## License

Apache 2.0 — see `debian/copyright`.
