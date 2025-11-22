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
URL_DSI="https://cirrus.local:3443/ocearo-ui"
URL_HDMI="https://cirrus.local:3443/ocearo-ui"

# Allow root to talk to X if script is run as root
if [ "$(id -u)" -eq 0 ]; then
    xhost +SI:localuser:pi >/dev/null 2>&1 || true
fi

# Fix Chrome profile directory permissions
chown -R pi:pi /home/pi/.config/chrome-dsi /home/pi/.config/chrome-hdmi 2>/dev/null || true
mkdir -p /home/pi/.config/chrome-dsi /home/pi/.config/chrome-hdmi
chown -R pi:pi /home/pi/.config/chrome-dsi /home/pi/.config/chrome-hdmi

# Setup screens (run in user session to access X and PipeWire)
sudo -u pi env DISPLAY="$DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  /usr/local/bin/setup-screens.sh

# Start Chromium on each screen as user 'pi'
sudo -u pi env DISPLAY="$DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  chromium-browser    --disable-translate  --start-fullscreen  --disable-restore-session-state --disable-session-crashed-bubble --disable-infobars --password-store=basic --noerrdialogs --window-position=0,0 \
  --user-data-dir=/home/pi/.config/chrome-hdmi "$URL_HDMI" &

sudo -u pi env DISPLAY="$DISPLAY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
  chromium-browser -force-device-scale-factor=1.2 --disable-translate  --start-fullscreen  --disable-restore-session-state --disable-session-crashed-bubble --disable-infobars --password-store=basic --noerrdialogs --kiosk --window-position=1920,0 \
  --user-data-dir=/home/pi/.config/chrome-dsi "$URL_DSI" &

wait
