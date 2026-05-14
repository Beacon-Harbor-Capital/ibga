#!/usr/bin/env python3
import sys, hmac, hashlib, base64, struct, time, re

raw = re.sub(r'[^A-Z2-7]', '', sys.stdin.read().strip().upper())
pad = "=" * ((8 - len(raw) % 8) % 8)
key = base64.b32decode(raw + pad)
counter = struct.pack(">Q", int(time.time()) // 30)
digest = hmac.new(key, counter, hashlib.sha1).digest()
offset = digest[-1] & 0x0F
code = (struct.unpack(">I", digest[offset:offset + 4])[0] & 0x7FFFFFFF) % 1_000_000
print(f"{code:06d}")
