#!/bin/bash
# Ensure SSL stays enabled in SignalK settings.json.
# Third-party tools (OpenPlotter, admin UI saves) may rewrite settings.json
# and drop the ssl/port/sslport keys; this runs as ExecStartPre of signalk.service.
SETTINGS="/home/pi/.signalk/settings.json"
[ -f "$SETTINGS" ] || exit 0
python3 - "$SETTINGS" <<'EOF'
import json, sys
p = sys.argv[1]
with open(p) as f:
    d = json.load(f)
if d.get("ssl") is True and d.get("port") == 3000 and d.get("sslport") == 3443:
    sys.exit(0)
d["ssl"] = True
d["port"] = 3000
d["sslport"] = 3443
with open(p, "w") as f:
    json.dump(d, f, indent=2)
print("signalk-ensure-ssl: restored ssl/port/sslport in settings.json")
EOF
