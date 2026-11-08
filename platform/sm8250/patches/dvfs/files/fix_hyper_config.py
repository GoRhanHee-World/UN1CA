# Copyright (c) 2026 GoRhanHee
# SPDX-License-Identifier: GPL-3.0-or-later

import json
import sys
from pathlib import Path


for filename in sys.argv[1:]:
    path = Path(filename)
    config = json.loads(path.read_text())
    resources = config.get("Resources", [])
    unsupported = {
        entry["Name"]
        for entry in resources
        if entry.get("BoostPath") == "/sys/kernel/mm/vmscan/am_app_launch"
    }
    config["Resources"] = [
        entry for entry in resources if entry.get("Name") not in unsupported
    ]
    for hint in config.get("Hints", []):
        # Samsung's configuration uses this spelling.
        if "ResoureList" in hint:
            hint["ResoureList"] = [
                entry for entry in hint["ResoureList"]
                if entry.get("Resource") not in unsupported
            ]
    # SM8250's governor has a combined rate_limit_us control. A down-only
    # request cannot be mapped to it without also changing ramp-up behavior.
    config["Sysfs"] = [
        entry for entry in config.get("Sysfs", [])
        if not entry.get("Path", "").endswith("/schedutil/down_rate_limit_us")
    ]
    path.write_text(json.dumps(config, indent=2) + "\n")
