#!/bin/bash
#
# Stop the Ollama service while nothing is using it.
#
# On a Pi 5 driving two kiosks, a resident Ollama is the single heaviest process
# on the box (measured 247% CPU during generation, 83 degC SoC, firmware reporting
# frequency-capped + throttled). Between generations the server itself is idle,
# but it still holds the loaded model in RAM.
#
# Two levers, in order of effect:
#   1. OLLAMA_KEEP_ALIVE (systemd drop-in) unloads the model shortly after use,
#      returning ~1.4 GB of RAM.
#   2. This watchdog stops the unit entirely after a longer idle period, so
#      nothing is resident at all. ocearo-core restarts it on demand before a
#      generation (see LLMClient._ensureOllamaRunning), which costs a few
#      seconds on the first call.
#
# Deliberately conservative: it never stops Ollama while a model is loaded, and
# never while a request is in flight.

set -u
export LC_ALL=C
export LANG=C

CHECK_INTERVAL="${CHECK_INTERVAL:-60}"      # seconds between checks
IDLE_BEFORE_STOP="${IDLE_BEFORE_STOP:-900}" # 15 min with no loaded model
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"

log() { echo "ollama-power: $*"; }

# A loaded model means recent (or ongoing) use.
model_loaded() {
    local out
    out=$(curl -s --max-time 5 "$OLLAMA_HOST/api/ps" 2>/dev/null) || return 1
    # {"models":[]} when nothing is resident
    echo "$out" | grep -q '"models":[[:space:]]*\[[[:space:]]*{'
}

log "watching (stop after ${IDLE_BEFORE_STOP}s with no loaded model)"

idle_since=0
while true; do
    if ! systemctl is-active --quiet ollama; then
        idle_since=0
        sleep "$CHECK_INTERVAL"
        continue
    fi

    if model_loaded; then
        idle_since=0
    else
        now=$(date +%s)
        if [ "$idle_since" -eq 0 ]; then
            idle_since=$now
        elif [ $((now - idle_since)) -ge "$IDLE_BEFORE_STOP" ]; then
            log "idle for ${IDLE_BEFORE_STOP}s — stopping ollama"
            systemctl stop ollama 2>/dev/null || true
            idle_since=0
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
