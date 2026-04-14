FILENAME = "ch8_rom/pong"

with open(f"{FILENAME}.ch8", "rb") as f:
    data = f.read()

with open(f"{FILENAME}.mem", "w") as f:
    for byte in data:
        f.write(f"{byte:02x}\n")

print(f"Converted {len(data)} bytes to {FILENAME}.mem")