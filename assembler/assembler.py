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
        addr = start_addr
        for lineno, toks in result:
            if not toks[0].endswith(':'):
                print(f"  0x{addr:03X}: {toks}")
                addr += 2
            else:
                print(f"  {'---':5s}: {toks}")
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
    """Turn a token into an integer — handle hex, decimal, labels."""
    if token in labels:
        return labels[token]
    elif token.startswith('0x') or token.startswith('0X'):
        return int(token, 16)
    else:
        return int(token, 0)

def encode(toks, labels, addr):
    """
    YOUR JOB: given a token list, return a 2-byte integer.
    
    Examples:
        ['CLS']              → 0x00E0
        ['JP', 'loop']       → 0x1NNN  where NNN = labels['loop']
        ['LD', 'V2', '0A']   → 0x620A
        ['ADD', 'V0', 'V1']  → 0x8014
        ['DRW', 'V0', 'V1', '5'] → 0xD015
    """
    mnemonic = toks[0].upper()  #Turn into uppercase no matter what the programmer wrote

    if mnemonic == 'CLS':
        return 0x00E0
    elif mnemonic == 'RET':
        return 0x00EE
    elif mnemonic == 'JP':
        nnn = resolve(toks[1],labels)
        return 0x1000 | nnn;
    elif mnemonic == 'LD':
        t1 = toks[1].upper()
        t2 = toks[2].upper()

        if t1 == 'I':                        # LD I, addr
            nnn = resolve(toks[2], labels)
            return 0xA000 | nnn

        elif t1 == 'DT':                     # LD DT, Vx
            x = REGISTERS[t2]
            return 0xF015 | (x << 8)

        elif t1 == 'ST':                     # LD ST, Vx
            x = REGISTERS[t2]
            return 0xF018 | (x << 8)

        elif t1 == 'F':                      # LD F, Vx  (font)
            x = REGISTERS[t2]
            return 0xF029 | (x << 8)

        elif t1 == 'B':                      # LD B, Vx  (BCD)
            x = REGISTERS[t2]
            return 0xF033 | (x << 8)

        elif t1 == '[I]':                    # LD [I], Vx  (store)
            x = REGISTERS[t2]
            return 0xF055 | (x << 8)

        elif t2 == '[I]':                    # LD Vx, [I]  (load)
            x = REGISTERS[t1]
            return 0xF065 | (x << 8)

        elif t2 == 'DT':                     # LD Vx, DT
            x = REGISTERS[t1]
            return 0xF007 | (x << 8)

        elif t2 == 'K':                      # LD Vx, K
            x = REGISTERS[t1]
            return 0xF00A | (x << 8)

        elif t1 in REGISTERS and t2 in REGISTERS:  # LD Vx, Vy
            x = REGISTERS[t1]
            y = REGISTERS[t2]
            return 0x8000 | (x << 8) | (y << 4)

        elif t1 in REGISTERS:                # LD Vx, kk
            x  = REGISTERS[t1]
            kk = resolve(toks[2], labels)
            return 0x6000 | (x << 8) | kk

        else:
            raise ValueError(f"Unknown LD variant: {toks}")
    elif mnemonic == 'ADD':
        t1 = toks[1].upper()
        t2 = toks[2].upper()

        if t1 == 'I':                        # ADD I, Vx
            x = REGISTERS[t2]
            return 0xF01E | (x << 8)

        elif t1 in REGISTERS and t2 in REGISTERS:  # ADD Vx, Vy
            x = REGISTERS[t1]
            y = REGISTERS[t2]
            return 0x8004 | (x << 8) | (y << 4)

        elif t1 in REGISTERS:                # ADD Vx, kk
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