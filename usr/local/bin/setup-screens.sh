#!/bin/bash
set -e

PRIMARY_DSI="DSI-1"
PRIMARY_HDMI="HDMI-1"

TOUCH_DSI="FT5406 memory based driver"
TOUCH_HDMI="ILITEK Multi-Touch"   # adapt with `xinput list`

SINK_HDMI="alsa_output.platform-hdmi-stereo"
SINK_JACK="alsa_output.platform-bcm2835-jack.stereo"

if xrandr | grep -q "$PRIMARY_HDMI connected"; then
    echo ">>> HDMI détecté → configuration double écran + son HDMI"
    xrandr --output "$PRIMARY_HDMI" --primary --mode 1920x1080 --rate 60 \
           --output "$PRIMARY_DSI" --mode 720x1280 --right-of "$PRIMARY_HDMI"

    xinput map-to-output "$TOUCH_DSI" "$PRIMARY_DSI" || true
    xinput map-to-output "$TOUCH_HDMI" "$PRIMARY_HDMI" || true

    # Basculer le son vers HDMI
    if pactl list short sinks | grep -q "$SINK_HDMI"; then
        pactl set-default-sink "$SINK_HDMI"
        echo ">>> Audio routé vers HDMI"
    fi
else
    echo ">>> HDMI absent → configuration écran DSI seul + son jack"
    xrandr --output "$PRIMARY_DSI" --primary --mode 720x1280 \
           --output "$PRIMARY_HDMI" --off

    xinput map-to-output "$TOUCH_DSI" "$PRIMARY_DSI" || true

    # Basculer le son vers Jack
    if pactl list short sinks | grep -q "$SINK_JACK"; then
        pactl set-default-sink "$SINK_JACK"
        echo ">>> Audio routé vers Jack"
    fi
fi
