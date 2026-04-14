import sys

REGISTERS = {f'V{i:X}': i for i in range(16)}  # V0-VF
debug = 1
start_addr = 0x200 # CHIP-8 programs always start at 0x200

def tokenize(source):
    """Returns list of (line_number, [tokens]) with comments stripped."""
    print("Tokenizing code...")
    result = []
    addr = start_addr
    for i, line in enumerate(source.splitlines()):
        line = line.split(';')[0].strip()
        if line:
            tokens = line.replace(',', ' ').split()
            result.append((i + 1, tokens))
            if not tokens[0].endswith(':'):  # labels don't advance address
                addr += 2
    if debug:
        addr = 0x200
        for lineno, toks in result:
            if toks[0].endswith(':'):
                print(f"  {'---':5s}: {toks}")
            else:
                print(f"  0x{addr:03X}: {toks}")
                if toks[0].upper() == 'DB':
                    addr += len(toks) - 1   # one byte per token
                else:
                    addr += 2
    return result

def first_pass(tokens):
    """Returns the symbol table, where """
    print("\nRunning first pass...")
    labels = {}     # our symbol table: name → address
    addr = start_addr    

    for lineno, toks in tokens:

        if toks[0].endswith(':'):
            # This is a label definition like "loop:" or "sprite:"
            # Labels don't emit any bytes — they just mark the current address
            # Strip the colon and record where we are
            name = toks[0][:-1]         # "loop:" → "loop"
            labels[name] = addr         # "loop" lives at current addr
            # DON'T advance addr — labels are zero-width

        elif toks[0].upper() == 'DB':
            # Raw data — one byte per token after the DB keyword
            # DB FC FF 00 18  → 4 bytes → addr advances by 4
            addr += len(toks) - 1       # -1 to exclude the 'DB' token itself

        elif toks[0].upper() == 'ORG':
            # Force-set the address counter
            # ORG 0xF00 means "next thing goes at 0xF00"
            addr = int(toks[1], 16)     # parse the address
            # DON'T advance addr — ORG itself emits no bytes

        else:
            # Regular instruction — always exactly 2 bytes in CHIP-8
            addr += 2

    if debug:
        print("\nSymbol table:")
        for name, address in labels.items():
            print(f"  {name:<20s} = 0x{address:03X}")
        print()

    return labels   # hand the symbol table to second_pass

def resolve(token, labels):
    if token in labels:
        return labels[token]
    else:
        return int(token, 16)   # everything is hex unless prefixed with 0x

def encode(toks, labels, addr):
    mnemonic = toks[0].upper()

    if mnemonic == 'CLS':
        return 0x00E0

    elif mnemonic == 'RET':
        return 0x00EE

    elif mnemonic == 'JP':
        nnn = resolve(toks[1], labels)
        return 0x1000 | nnn

    elif mnemonic == 'CALL':
        nnn = resolve(toks[1], labels)
        return 0x2000 | nnn

    elif mnemonic == 'SE':
        t1 = toks[1].upper()
        t2 = toks[2].upper()
        if t1 in REGISTERS and t2 in REGISTERS:    # SE Vx, Vy
            x = REGISTERS[t1]
            y = REGISTERS[t2]
            return 0x5000 | (x << 8) | (y << 4)
        elif t1 in REGISTERS:                       # SE Vx, kk
            x  = REGISTERS[t1]
            kk = resolve(toks[2], labels)
            return 0x3000 | (x << 8) | kk
        else:
            raise ValueError(f"Unknown SE variant: {toks}")

    elif mnemonic == 'SNE':
        t1 = toks[1].upper()
        t2 = toks[2].upper()
        if t1 in REGISTERS and t2 in REGISTERS:    # SNE Vx, Vy
            x = REGISTERS[t1]
            y = REGISTERS[t2]
            return 0x9000 | (x << 8) | (y << 4)
        elif t1 in REGISTERS:                       # SNE Vx, kk
            x  = REGISTERS[t1]
            kk = resolve(toks[2], labels)
            return 0x4000 | (x << 8) | kk
        else:
            raise ValueError(f"Unknown SNE variant: {toks}")

    elif mnemonic == 'OR':
        x = REGISTERS[toks[1].upper()]
        y = REGISTERS[toks[2].upper()]
        return 0x8001 | (x << 8) | (y << 4)

    elif mnemonic == 'AND':
        x = REGISTERS[toks[1].upper()]
        y = REGISTERS[toks[2].upper()]
        return 0x8002 | (x << 8) | (y << 4)

    elif mnemonic == 'XOR':
        x = REGISTERS[toks[1].upper()]
        y = REGISTERS[toks[2].upper()]
        return 0x8003 | (x << 8) | (y << 4)

    elif mnemonic == 'SUB':
        x = REGISTERS[toks[1].upper()]
        y = REGISTERS[toks[2].upper()]
        return 0x8005 | (x << 8) | (y << 4)

    elif mnemonic == 'SHR':
        x = REGISTERS[toks[1].upper()]
        return 0x8006 | (x << 8)

    elif mnemonic == 'SUBN':
        x = REGISTERS[toks[1].upper()]
        y = REGISTERS[toks[2].upper()]
        return 0x8007 | (x << 8) | (y << 4)

    elif mnemonic == 'SHL':
        x = REGISTERS[toks[1].upper()]
        return 0x800E | (x << 8)

    elif mnemonic == 'RND':
        x  = REGISTERS[toks[1].upper()]
        kk = resolve(toks[2], labels)
        return 0xC000 | (x << 8) | kk

    elif mnemonic == 'SKP':
        x = REGISTERS[toks[1].upper()]
        return 0xE09E | (x << 8)

    elif mnemonic == 'SKNP':
        x = REGISTERS[toks[1].upper()]
        return 0xE0A1 | (x << 8)

    elif mnemonic == 'LD':
        t1 = toks[1].upper()
        t2 = toks[2].upper()
        if t1 == 'I':
            nnn = resolve(toks[2], labels)
            return 0xA000 | nnn
        elif t1 == 'DT':
            x = REGISTERS[t2]
            return 0xF015 | (x << 8)
        elif t1 == 'ST':
            x = REGISTERS[t2]
            return 0xF018 | (x << 8)
        elif t1 == 'F':
            x = REGISTERS[t2]
            return 0xF029 | (x << 8)
        elif t1 == 'B':
            x = REGISTERS[t2]
            return 0xF033 | (x << 8)
        elif t1 == '[I]':
            x = REGISTERS[t2]
            return 0xF055 | (x << 8)
        elif t2 == '[I]':
            x = REGISTERS[t1]
            return 0xF065 | (x << 8)
        elif t2 == 'DT':
            x = REGISTERS[t1]
            return 0xF007 | (x << 8)
        elif t2 == 'K':
            x = REGISTERS[t1]
            return 0xF00A | (x << 8)
        elif t1 in REGISTERS and t2 in REGISTERS:
            x = REGISTERS[t1]
            y = REGISTERS[t2]
            return 0x8000 | (x << 8) | (y << 4)
        elif t1 in REGISTERS:
            x  = REGISTERS[t1]
            kk = resolve(toks[2], labels)
            return 0x6000 | (x << 8) | kk
        else:
            raise ValueError(f"Unknown LD variant: {toks}")

    elif mnemonic == 'ADD':
        t1 = toks[1].upper()
        t2 = toks[2].upper()
        if t1 == 'I':
            x = REGISTERS[t2]
            return 0xF01E | (x << 8)
        elif t1 in REGISTERS and t2 in REGISTERS:
            x = REGISTERS[t1]
            y = REGISTERS[t2]
            return 0x8004 | (x << 8) | (y << 4)
        elif t1 in REGISTERS:
            x  = REGISTERS[t1]
            kk = resolve(toks[2], labels)
            return 0x7000 | (x << 8) | kk
        else:
            raise ValueError(f"Unknown ADD variant: {toks}")

    elif mnemonic == 'DRW':
        x = REGISTERS[toks[1].upper()]
        y = REGISTERS[toks[2].upper()]
        n = resolve(toks[3], labels)
        return 0xD000 | (x << 8) | (y << 4) | n

    raise NotImplementedError(f"Unknown instruction: {toks}")

def second_pass(tokens, labels):
    print("Running second pass...")
    output = []             # flat list of bytes, this is our binary
    addr   = start_addr     # track address for debug output

    for lineno, toks in tokens:

        if toks[0].endswith(':'):
            # Labels emit no bytes — skip them
            # We already handled them in first_pass
            continue

        elif toks[0].upper() == 'ORG':
            # Pad output with zeros up to the target address
            target = int(toks[1], 16)
            while addr < target:
                output.append(0x00)
                addr += 1

        elif toks[0].upper() == 'DB':
            # Raw bytes — emit each one directly
            for byte_tok in toks[1:]:
                output.append(int(byte_tok, 16))
                addr += 1

        else:
            # Regular instruction — encode to 2-byte word
            word = encode(toks, labels, addr)

            high = (word >> 8) & 0xFF   # upper byte
            low  =  word       & 0xFF   # lower byte

            output.append(high)
            output.append(low)
            addr += 2

    if debug:
        print("\nProgram:")
        base = 0x200
        for i in range(0, len(output), 16):
            chunk = output[i:i+16]
            pairs = []
            for j in range(0, len(chunk), 2):
                if j + 1 < len(chunk):
                    pairs.append(f'{chunk[j]:02X}{chunk[j+1]:02X}')
                else:
                    pairs.append(f'{chunk[j]:02X}  ')  # lone byte, pad with spaces
            print(f"  0x{base+i:03X}: {' '.join(pairs)}")

    return output

def assemble(source):
    tokens = tokenize(source)
    labels = first_pass(tokens)
    binary = second_pass(tokens, labels)
    return binary

if __name__ == '__main__':
    with open(sys.argv[1]) as f:
        source = f.read()
    
    binary = assemble(source)
    
    with open(sys.argv[2], 'w') as f:       # 'w' not 'wb' — text mode
        for byte in binary:
            f.write(f'{byte:02x}\n')         # one byte per line, lowercase hex
    
    print(f"\nAssembled {len(binary)} bytes ({len(binary)//2} instructions)")