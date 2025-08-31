#!/bin/bash
set -e

# Config
URL_DSI="https://cirrus.local/ocearo-ui"
URL_HDMI="https://cirrus.local/ocearo-ui"

# Setup screens
/usr/local/bin/setup-screens.sh

# Start Chromium on each screen
chromium-browser --kiosk --window-position=0,0 \
  --user-data-dir=/home/pi/.config/chrome-dsi "$URL_DSI" &

chromium-browser --kiosk --window-position=1920,0 \
  --user-data-dir=/home/pi/.config/chrome-hdmi "$URL_HDMI" &

wait
