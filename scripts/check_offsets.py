#!/usr/bin/env python3
from pathlib import Path
import re
text = Path("include/RewardTraceOffsets.h").read_text(encoding="utf-8")
items = re.findall(r"inline constexpr std::uint64_t\s+(k\w+)\s*=\s*(0x[0-9A-Fa-f]+);", text)
if not items:
    raise SystemExit("no RVAs found")
seen = {}
for name, raw in items:
    value = int(raw, 16)
    if value & 3:
        raise SystemExit(f"unaligned ARM64 RVA: {name}={raw}")
    if value in seen:
        raise SystemExit(f"duplicate RVA {raw}: {seen[value]} and {name}")
    seen[value] = name
print(f"OK: {len(items)} unique aligned RVAs")
