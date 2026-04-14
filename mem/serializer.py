FILENAME = "test/alu/alu_test"

with open(f"{FILENAME}.mem", "r") as f:
    lines = f.readlines()

# Separate header lines from data lines
header = []
data_bytes = []

for line in lines:
    line = line.strip()
    if line.startswith('#') or line.startswith('@'):
        header.append(line)
    elif line:
        # Split space-separated bytes
        data_bytes.extend(line.split())

with open(f"{FILENAME}_fixed.mem", "w") as f:
    for h in header:
        f.write(h + "\n")
    for byte in data_bytes:
        f.write(byte + "\n")

print(f"Written {len(data_bytes)} bytes to {FILENAME}_fixed.mi")