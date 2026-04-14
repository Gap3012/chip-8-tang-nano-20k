addr:
CLS
RET  
JP addr         ;Jump Instruction
LD V0, 0x11
ADD V1, 0x22
addr2:
JP addr