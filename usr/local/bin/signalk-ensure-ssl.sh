#!/bin/bash
# Ensure SSL stays enabled in SignalK settings.json, and self-heal the known
# "Extra data" corruption (a shorter JSON written over a longer file without
# truncation leaves the old tail behind). Runs as ExecStartPre of signalk.service.
SETTINGS="/home/pi/.signalk/settings.json"
[ -f "$SETTINGS" ] || exit 0
python3 - "$SETTINGS" <<'EOF2'
import json, os, sys, tempfile
p = sys.argv[1]
raw = open(p).read()
try:
    d = json.loads(raw)
    truncated = False
except json.JSONDecodeError:
    # Salvage the valid JSON head if the file has trailing garbage
    d, end = json.JSONDecoder().raw_decode(raw)
    truncated = True
    print(f"signalk-ensure-ssl: settings.json had extra data, kept {end} of {len(raw)} bytes")
dirty = truncated
if not (d.get("ssl") is True and d.get("port") == 3000 and d.get("sslport") == 3443):
    d["ssl"] = True
    d["port"] = 3000
    d["sslport"] = 3443
    dirty = True
    print("signalk-ensure-ssl: restored ssl/port/sslport in settings.json")
if not dirty:
    sys.exit(0)
# Atomic replace: never leave a partially-written settings.json
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(p), prefix=".settings-", suffix=".json")
with os.fdopen(fd, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
os.replace(tmp, p)
EOF2
