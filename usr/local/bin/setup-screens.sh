#!/bin/bash
set -e
export LC_ALL=C
export LANG=C
export LANGUAGE=C

PRIMARY_DSI="DSI-2"
PRIMARY_HDMI="HDMI-1-1"

# Dynamic touch device detection
get_touch_dsi_id() {
    xinput list | grep "11-005d Goodix Capacitive TouchScreen" | grep -o "id=[0-9]*" | cut -d= -f2 | head -1
}

get_touch_hdmi_id() {
    xinput list | grep "ILITEK ILITEK-TP" | grep -v "Mouse" | grep -o "id=[0-9]*" | cut -d= -f2 | head -1
}


# Dynamic sink detection for PipeWire
get_hdmi_sink() {
    pactl list short sinks 2>/dev/null | grep -i hdmi | head -1 | awk '{print $2}' || echo ""
}

get_jack_sink() {
    pactl list short sinks 2>/dev/null | grep -E "jack|bcm2835" | head -1 | awk '{print $2}' || echo ""
}

if xrandr --listmonitors | grep -q "$PRIMARY_HDMI"; then
    echo ">>> HDMI detected - dual screen configuration + HDMI audio"
    xrandr --output "$PRIMARY_HDMI" --primary --mode 1920x1080 --rate 60 \
           --output "$PRIMARY_DSI" --mode 720x1280 --right-of "$PRIMARY_HDMI"

    # Get dynamic touch device IDs
    TOUCH_DSI=$(get_touch_dsi_id)
    TOUCH_HDMI=$(get_touch_hdmi_id)
    
    echo ">>> Touch devices detected: DSI=$TOUCH_DSI, HDMI=$TOUCH_HDMI"
    
    # Reset and map touch devices
    if [ -n "$TOUCH_DSI" ]; then
        xinput set-prop "$TOUCH_DSI" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1 2>/dev/null || true
        xinput map-to-output "$TOUCH_DSI" "$PRIMARY_DSI" 2>/dev/null || true
        echo ">>> DSI touch mapped to $PRIMARY_DSI"
    else
        echo ">>> DSI touch device not found"
    fi
    
    if [ -n "$TOUCH_HDMI" ]; then
        xinput set-prop "$TOUCH_HDMI" "Coordinate Transformation Matrix" 1 0 0 0 1 0 0 0 1 2>/dev/null || true
        xinput map-to-output "$TOUCH_HDMI" "$PRIMARY_HDMI" 2>/dev/null || true
        echo ">>> HDMI touch mapped to $PRIMARY_HDMI"
    else
        echo ">>> HDMI touch device not found"
    fi

    # Switch audio to HDMI
    if command -v pactl >/dev/null 2>&1; then
        # Wait for PipeWire/PulseAudio to be ready
        sleep 1
        if pactl info >/dev/null 2>&1; then
            HDMI_SINK=$(get_hdmi_sink)
            if [ -n "$HDMI_SINK" ]; then
                pactl set-default-sink "$HDMI_SINK"
                echo ">>> Audio routed to HDMI ($HDMI_SINK)"
            else
                echo ">>> HDMI audio sink not found, keeping current audio setup"
            fi
        else
            echo ">>> PipeWire/PulseAudio not ready, skipping audio configuration"
        fi
    else
        echo ">>> Audio control not available, skipping audio configuration"
    fi
else
    echo ">>> HDMI absent - DSI screen only + jack audio"
    xrandr --output "$PRIMARY_DSI" --primary --mode 720x1280 \
           --output "$PRIMARY_HDMI" --off

    xinput map-to-output "$TOUCH_DSI" "$PRIMARY_DSI" || true

    # Switch audio to Jack
    if command -v pactl >/dev/null 2>&1; then
        # Wait for PipeWire/PulseAudio to be ready
        sleep 1
        if pactl info >/dev/null 2>&1; then
            JACK_SINK=$(get_jack_sink)
            if [ -n "$JACK_SINK" ]; then
                pactl set-default-sink "$JACK_SINK"
                echo ">>> Audio routed to Jack ($JACK_SINK)"
            else
                echo ">>> Jack audio sink not found, keeping current audio setup"
            fi
        else
            echo ">>> PipeWire/PulseAudio not ready, skipping audio configuration"
        fi
    else
        echo ">>> Audio control not available, skipping audio configuration"
    fi
fi
