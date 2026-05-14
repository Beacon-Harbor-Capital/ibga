import base64
import urllib.parse
import sys

# Paste your full migration string here
migration_url = "otpauth-migration://offline?data=ClQKFMIff1hPv8AUeSvwKm9n9zU0yYmPEgx5a2tlZXBhaXNhZmUaE0ludGVyYWN0aXZlIEJyb2tlcnMgASgBMAJCEzRjZWY4YTE3NjY0MzczMzYxNjUQAhgBIAA%3D"

# Extract and decode the data
data = urllib.parse.urlparse(migration_url)
params = urllib.parse.parse_qs(data.query)
decoded = base64.b64decode(params['data'][0])

# Parse protobuf manually - secret is in the first field
from google.protobuf import descriptor_pool, descriptor_pb2
from google.protobuf.internal.decoder import _DecodeVarint

i = 0
while i < len(decoded):
    tag, new_i = _DecodeVarint(decoded, i)
    field_number = tag >> 3
    wire_type = tag & 0x7
    i = new_i
    if wire_type == 2:  # length-delimited
        length, i = _DecodeVarint(decoded, i)
        value = decoded[i:i+length]
        if field_number == 1:  # OTP parameters
            # Secret is nested field 1
            j = 0
            while j < len(value):
                inner_tag, new_j = _DecodeVarint(value, j)
                inner_field = inner_tag >> 3
                inner_wire = inner_tag & 0x7
                j = new_j
                if inner_wire == 2:
                    inner_len, j = _DecodeVarint(value, j)
                    inner_val = value[j:j+inner_len]
                    if inner_field == 1:  # secret bytes
                        print("Secret:", base64.b32encode(inner_val).decode().rstrip('='))
                    j += inner_len
                else:
                    j += 1
        i += length