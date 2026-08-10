#!/bin/bash
#
# Recover wlan0 when the supplicant gets stuck refusing to associate.
#
# Observed on the boat: after a cold boot the Pi and the 4G hotspot power up
# together and wpa_supplicant logs `CTRL-EVENT-ASSOC-REJECT status_code=16` in a
# loop — 88 attempts over ~16 minutes on 2026-07-24 before it finally associated.
# Each failure also trips `CTRL-EVENT-SSID-TEMP-DISABLED` (10s, 20s, ...), so the
# back-off grows exactly when we want it to retry harder. NetworkManager's
# `autoconnect-retries=0` does not help: it re-runs the same stuck supplicant
# state. Cycling the radio clears both the association state and the back-off.
#
# The kiosk points at https://localhost:3443, so the displays keep working
# throughout; this only restores off-boat connectivity.

set -u
export LC_ALL=C
export LANG=C

IFACE="${IFACE:-wlan0}"
CHECK_INTERVAL="${CHECK_INTERVAL:-20}"    # seconds between checks
GRACE="${GRACE:-45}"                      # seconds to allow normal association
COOLDOWN="${COOLDOWN:-90}"                # seconds to wait after a radio cycle

log() { echo "wifi-watchdog: $*"; }

is_connected() {
    nmcli -t -f DEVICE,STATE device 2>/dev/null \
        | grep -q "^${IFACE}:connected$"
}

# Preferred profile = highest autoconnect-priority among wifi profiles.
preferred_profile() {
    nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | awk -F: '$2 == "802-11-wireless" {print $1}' \
        | while read -r name; do
            prio=$(nmcli -t -f connection.autoconnect-priority connection show "$name" 2>/dev/null | cut -d: -f2)
            echo "${prio:-0}|$name"
        done | sort -t'|' -k1,1nr | head -1 | cut -d'|' -f2
}

# Power saving makes an already-marginal 2.4 GHz link drop more often.
# nmcli first: it persists in the profile and needs no extra package. iw is only
# a best-effort immediate nudge and is not installed on every image.
disable_powersave() {
    local profile
    profile=$(preferred_profile)
    if [ -n "$profile" ]; then
        current=$(nmcli -t -f 802-11-wireless.powersave connection show "$profile" 2>/dev/null | cut -d: -f2)
        case "$current" in
            *2*) ;;   # already disabled
            *) nmcli connection modify "$profile" 802-11-wireless.powersave 2 2>/dev/null || true ;;
        esac
    fi
    if command -v iw >/dev/null 2>&1; then
        iw dev "$IFACE" set power_save off 2>/dev/null || true
    fi
}

cycle_radio() {
    local profile="$1"
    log "no link for ${GRACE}s — cycling radio"
    nmcli radio wifi off 2>/dev/null || true
    sleep 3
    nmcli radio wifi on 2>/dev/null || true
    sleep 8
    disable_powersave
    if [ -n "$profile" ]; then
        log "bringing up profile '$profile'"
        nmcli connection up "$profile" ifname "$IFACE" 2>/dev/null || true
    fi
}

log "watching $IFACE (interval ${CHECK_INTERVAL}s, grace ${GRACE}s)"
disable_powersave

down_since=0
while true; do
    if is_connected; then
        if [ "$down_since" -ne 0 ]; then
            log "link restored"
            down_since=0
        fi
    else
        now=$(date +%s)
        if [ "$down_since" -eq 0 ]; then
            down_since=$now
        elif [ $((now - down_since)) -ge "$GRACE" ]; then
            cycle_radio "$(preferred_profile)"
            sleep "$COOLDOWN"
            down_since=0
            continue
        fi
    fi
    sleep "$CHECK_INTERVAL"
done
