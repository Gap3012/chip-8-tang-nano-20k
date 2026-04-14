; ============================================
; Boat demo
; Draws a boat sprite in the center of screen
; ============================================

; --- entry point ---
    LD   V0, 0x1C     ; X position = 28 (center of 64-wide screen)
    LD   V1, 0x0C     ; Y position = 12 (center of 32-tall screen)
    LD   I, boat    ; point I at our sprite
    DRW  V0, V1, 5  ; draw 5 rows tall

loop:
    JP   loop       ; hang forever

; --- sprite data ---
boat:
    DB 18           ;    XX        (mast top)
    DB 7E           ;  XXXXXX      (sail)
    DB FF           ; XXXXXXXX     (hull top)
    DB FF           ; XXXXXXXX     (hull bottom)
    DB 7E           ;  XXXXXX      (water line)