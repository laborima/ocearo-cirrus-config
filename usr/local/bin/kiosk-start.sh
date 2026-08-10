#!/bin/bash
set -e
export LC_ALL=C
export LANG=C
export LANGUAGE=C

# Display/session environment
export DISPLAY=:0
PI_UID=1000
export XDG_RUNTIME_DIR="/run/user/${PI_UID}"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

# Config
# localhost, not cirrus.local: the UI must keep working when the WiFi has not
# associated yet (mDNS resolution fails and the kiosk would show an error page).
URL_DSI="https://localhost:3443/@mxtommy/kip"
URL_HDMI="https://localhost:3443/ocearo-ui"

# Must match setup-screens.sh
PRIMARY_DSI="DSI-2"
PRIMARY_HDMI="HDMI-1-1"

# Allow root to talk to X if script is run as root
if [ "$(id -u)" -eq 0 ]; then
    xhost +SI:localuser:pi >/dev/null 2>&1 || true
fi

# Fix Chrome profile directory permissions
chown -R pi:pi /home/pi/.config/chrome-dsi /home/pi/.config/chrome-hdmi 2>/dev/null || true
mkdir -p /home/pi/.config/chrome-dsi /home/pi/.config/chrome-hdmi
chown -R pi:pi /home/pi/.config/chrome-dsi /home/pi/.config/chrome-hdmi

# Mark previous session as cleanly exited to suppress the "Restore pages?" bubble
for PROFILE in /home/pi/.config/chrome-dsi /home/pi/.config/chrome-hdmi; do
    PREFS="$PROFILE/Default/Preferences"
    if [ -f "$PREFS" ]; then
        sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/; s/"exited_cleanly":false/"exited_cleanly":true/' "$PREFS" || true
    fi
done

# Setup screens (run in user session to access X and PipeWire)
sudo -u pi env DISPLAY="$DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  /usr/local/bin/setup-screens.sh

# Start Chromium on each screen as user 'pi'
# 3D optimization flags for Raspberry Pi 5 GPU
# autoplay/certificate flags are required for KIP's notification sounds over the
# self-signed localhost certificate.
CHROMIUM_3D_FLAGS="--autoplay-policy=no-user-gesture-required --ignore-certificate-errors --test-type --enable-gpu-rasterization --enable-zero-copy --enable-accelerated-video-decode --enable-hardware-overlays --use-angle=gles --enable-features=VaapiVideoDecoder --disable-software-rasterizer --enable-oop-rasterization --num-raster-threads=2 --enable-raw-draw"
CHROMIUM_COMMON="--disable-translate --start-fullscreen --disable-restore-session-state --disable-session-crashed-bubble --hide-crash-restore-bubble --disable-infobars --password-store=basic --noerrdialogs --no-first-run --no-default-browser-check"

as_pi() {
    sudo -u pi env DISPLAY="$DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
        DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" "$@"
}

# Read each screen's real origin from X rather than assuming the dual-screen
# layout. Previously both browsers were always launched and the DSI window was
# pinned to 1920,0 — with HDMI unplugged the DSI sits at 0,0, so KIP opened off
# screen and the ocearo-ui window landed on the small display instead.
screen_origin() {
    as_pi xrandr | awk -v out="$1" '$1 == out && $2 == "connected" {
        for (i = 3; i <= NF; i++) if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
            split($i, a, "+"); print a[2] "," a[3]; exit
        }
    }'
}

HDMI_ORIGIN=$(screen_origin "$PRIMARY_HDMI")
DSI_ORIGIN=$(screen_origin "$PRIMARY_DSI")

if [ -n "$HDMI_ORIGIN" ]; then
    echo ">>> Dual screen: ocearo-ui on $PRIMARY_HDMI ($HDMI_ORIGIN), KIP on $PRIMARY_DSI ($DSI_ORIGIN)"
    as_pi chromium-browser $CHROMIUM_COMMON --window-position="$HDMI_ORIGIN" \
        $CHROMIUM_3D_FLAGS \
        --user-data-dir=/home/pi/.config/chrome-hdmi "$URL_HDMI" &

    as_pi chromium-browser -force-device-scale-factor=1.2 $CHROMIUM_COMMON --kiosk \
        --window-position="${DSI_ORIGIN:-1920,0}" \
        $CHROMIUM_3D_FLAGS \
        --user-data-dir=/home/pi/.config/chrome-dsi "$URL_DSI" &
else
    # Single screen: KIP only, on the DSI, at wherever it actually is.
    echo ">>> Single screen: KIP only on $PRIMARY_DSI (${DSI_ORIGIN:-0,0})"
    as_pi chromium-browser -force-device-scale-factor=1.2 $CHROMIUM_COMMON --kiosk \
        --window-position="${DSI_ORIGIN:-0,0}" \
        $CHROMIUM_3D_FLAGS \
        --user-data-dir=/home/pi/.config/chrome-dsi "$URL_DSI" &
fi

wait
