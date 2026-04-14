; ============================================
; CHIP-8 CPU test suite
; Each test:
;   - displays test number top left
;   - runs the check
;   - waits 10 seconds
;   - moves to next test
; On fail:
;   - displays FAIL + test number
;   - halts forever
; ============================================

; --- register conventions ---
; V0, V1  scratch for tests
; V2, V3  scratch for tests
; VC      current test number (for display)
; VD      X position for test number display
; VE      timer scratch (used by wait)
; VF      collision/carry flag (CHIP-8 hardware)

    CLS
    LD   VC, 00     ; test counter starts at 0
    LD   VD, 00     ; display X = 0
    LD   VB, 00     ; display Y = 0

; ============================================
; TEST 01 - LD Vx, kk
; ============================================
test01:
    ADD  VC, 01
    CALL show_test      ; display test number

    LD   V0, 42
    SE   V0, 42
    JP   fail

    LD   V0, 00
    SE   V0, 00
    JP   fail

    LD   V0, FF
    SE   V0, FF
    JP   fail

    CALL wait
    CALL clear_test     ; erase test number before next

; ============================================
; TEST 02 - ADD Vx, kk
; ============================================
test02:
    ADD  VC, 01
    CALL show_test

    LD   V0, 10
    ADD  V0, 05
    SE   V0, 15
    JP   fail

    LD   V0, FF         ; test wraparound
    ADD  V0, 01
    SE   V0, 00
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 03 - LD Vx, Vy
; ============================================
test03:
    ADD  VC, 01
    CALL show_test

    LD   V0, 42
    LD   V1, V0
    SE   V1, 42
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 04 - OR Vx, Vy
; ============================================
test04:
    ADD  VC, 01
    CALL show_test

    LD   V0, 0F
    LD   V1, F0
    OR   V0, V1
    SE   V0, FF
    JP   fail

    LD   V0, 00
    LD   V1, 00
    OR   V0, V1
    SE   V0, 00
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 05 - AND Vx, Vy
; ============================================
test05:
    ADD  VC, 01
    CALL show_test

    LD   V0, FF
    LD   V1, 0F
    AND  V0, V1
    SE   V0, 0F
    JP   fail

    LD   V0, FF
    LD   V1, 00
    AND  V0, V1
    SE   V0, 00
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 06 - XOR Vx, Vy
; ============================================
test06:
    ADD  VC, 01
    CALL show_test

    LD   V0, FF
    LD   V1, FF
    XOR  V0, V1
    SE   V0, 00
    JP   fail

    LD   V0, F0
    LD   V1, 0F
    XOR  V0, V1
    SE   V0, FF
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 07 - ADD Vx, Vy with carry
; ============================================
test07:
    ADD  VC, 01
    CALL show_test

    LD   V0, 01         ; no carry
    LD   V1, 01
    ADD  V0, V1
    SE   V0, 02
    JP   fail
    SE   VF, 00         ; VF should be 0 (no carry)
    JP   fail

    LD   V0, FF         ; carry
    LD   V1, 01
    ADD  V0, V1
    SE   V0, 00
    JP   fail
    SE   VF, 01         ; VF should be 1 (carry)
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 08 - SUB Vx, Vy with borrow
; ============================================
test08:
    ADD  VC, 01
    CALL show_test

    LD   V0, 05         ; no borrow (V0 > V1)
    LD   V1, 03
    SUB  V0, V1
    SE   V0, 02
    JP   fail
    SE   VF, 01         ; VF=1 means NO borrow
    JP   fail

    LD   V0, 03         ; borrow (V0 < V1)
    LD   V1, 05
    SUB  V0, V1
    SE   VF, 00         ; VF=0 means borrow occurred
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 09 - SHR Vx
; ============================================
test09:
    ADD  VC, 01
    CALL show_test

    LD   V0, 02
    SHR  V0
    SE   V0, 01
    JP   fail
    SE   VF, 00         ; shifted out bit was 0
    JP   fail

    LD   V0, 03
    SHR  V0
    SE   V0, 01
    JP   fail
    SE   VF, 01         ; shifted out bit was 1
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 10 - SUBN Vx, Vy
; ============================================
test10:
    ADD  VC, 01
    CALL show_test

    LD   V0, 03         ; V1 > V0, no borrow
    LD   V1, 05
    SUBN V0, V1
    SE   V0, 02
    JP   fail
    SE   VF, 01         ; VF=1 no borrow
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 11 - SHL Vx
; ============================================
test11:
    ADD  VC, 01
    CALL show_test

    LD   V0, 01
    SHL  V0
    SE   V0, 02
    JP   fail
    SE   VF, 00         ; top bit was 0
    JP   fail

    LD   V0, 80
    SHL  V0
    SE   V0, 00
    JP   fail
    SE   VF, 01         ; top bit was 1
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 12 - SE Vx, Vy
; ============================================
test12:
    ADD  VC, 01
    CALL show_test

    LD   V0, 42
    LD   V1, 42
    SE   V0, V1         ; should skip
    JP   fail

    LD   V0, 42
    LD   V1, 43
    SNE  V0, V1         ; should skip (they are different)
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 13 - CALL and RET
; ============================================
test13:
    ADD  VC, 01
    CALL show_test

    LD   V0, 00
    CALL ret_test       ; should set V0 = 42 and return
    SE   V0, 42
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 14 - AND I, ADD I, Vx
; ============================================
test14:
    ADD  VC, 01
    CALL show_test

    LD   I, 0x300       ; I = 0x300
    LD   V0, 10
    ADD  I, V0          ; I should = 0x310
    LD   V1, 10
    ADD  I, V1          ; I should = 0x320
    LD   [I], V1        ; store V0..V1 at 0x320
    LD   V0, 00
    LD   V1, 00
    LD   V0, [I]        ; load back — wait, need to reset I first
    ; better approach: store then reload and compare
    LD   I, 0x300
    LD   V0, AB
    LD   V1, CD
    LD   [I], V1        ; store V0=AB, V1=CD at 0x300, 0x301
    LD   V2, 00
    LD   V3, 00
    LD   V2, [I]        ; load back into V2, V3
    SE   V2, AB
    JP   fail
    SE   V3, CD
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; TEST 15 - BCD
; ============================================
test15:
    ADD  VC, 01
    CALL show_test
    LD   I, 0x300
    LD   V0, 7B         ; 0x7B = 123 decimal
    LD   B, V0          ; store BCD at I, I+1, I+2
    LD   V2, [I]        ; load back V0=hundreds, V1=tens, V2=ones
    SE   V0, 01         ; hundreds = 1
    JP   fail
    SE   V1, 02         ; tens = 2
    JP   fail
    SE   V2, 03         ; ones = 3
    JP   fail
    CALL wait
    CALL clear_test

; ============================================
; TEST 16 - delay timer
; ============================================
test16:
    ADD  VC, 01
    CALL show_test

    LD   V0, 3C         ; set timer to 60
    LD   DT, V0
    LD   V1, DT         ; read back immediately
    SE   VF, 00         ; VF should not be trashed
    JP   fail
    SNE  V1, 00         ; timer should not be 0 yet
    JP   fail

    CALL wait
    CALL clear_test

; ============================================
; ALL TESTS PASSED
; ============================================
pass_all:
    CLS
    LD   V0, 18     ; X center
    LD   V1, 0C     ; Y center
    LD   I, smiley
    DRW  V0, V1, 5
    JP   pass_all   ; hang here showing smiley

; ============================================
; FAIL handler
; ============================================
fail:
    CLS
    LD   V0, 1C     ; center X
    LD   V1, 08     ; center Y
    LD   F, VC      ; font sprite for test number
    DRW  V0, V1, 5  ; draw test number that failed
fail_loop:
    JP   fail_loop  ; halt forever

; ============================================
; show_test subroutine
; draws current test number VC at top left
; ============================================
show_test:
    LD   VD, 01     ; X=1
    LD   VB, 01     ; Y=1
    LD   F, VC
    DRW  VD, VB, 5
    RET

; ============================================
; clear_test subroutine
; erases test number (XOR redraw)
; ============================================
clear_test:
    LD   VD, 01
    LD   VB, 01
    LD   F, VC
    DRW  VD, VB, 5  ; XOR erase
    RET

; ============================================
; ret_test subroutine - used by test 13
; sets V0 = 42 and returns
; ============================================
ret_test:
    LD   V0, 42
    RET

; ============================================
; wait ~5 seconds
; 255 + 45 = 300 ticks at 60Hz = 5 seconds
; ============================================
wait:
    LD   VE, FF
    LD   DT, VE
wait_1:
    LD   VE, DT
    SE   VE, 00
    JP   wait_1

    LD   VE, 2D     ; 45 = 0x2D
    LD   DT, VE
wait_2:
    LD   VE, DT
    SE   VE, 00
    JP   wait_2

    RET

; ============================================
; sprite data
; ============================================
smiley:
    DB 3C       ;   XXXX
    DB 42       ;  X    X
    DB A5       ; X X  X X
    DB 81       ; X      X
    DB A5       ; X X  X X
    DB 99       ; X  XX  X
    DB 42       ;  X    X
    DB 3C       ;   XXXX