import csv

FILENAME = "test/alu/alu_test_fixed"

# Read bytes from {FILENAME}.mem in the same directory
with open(f"{FILENAME}.mem", "r") as f:
    bytes_list = [int(b.strip(), 16) for b in f if b.strip()]

# Pair into 2-byte opcodes starting at 0x200
BASE_ADDR = 0x200
rows = []
i = 0
while i + 1 < len(bytes_list):
    addr = BASE_ADDR + i
    opcode = (bytes_list[i] << 8) | bytes_list[i + 1]
    rows.append([f"0x{addr:03X}", f'"{opcode:04X}"', ""])
    i += 2

# Write CSV
output_file = f"{FILENAME}_disassembled.csv"
with open(output_file, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["Address", "Instruction", "Notes"])
    writer.writerows(rows)

print(f"Written {len(rows)} instructions to {output_file}")