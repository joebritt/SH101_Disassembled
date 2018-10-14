;
;  D48 V3.4.1 8048 Disassembly of 80C49_SH101.bin
;  2013/02/09 17:16
;
;  Joe Britt, britt@shapetable.com
;
; Notes:
;	There are only 4 subroutines (call/ret pairs):
;
;		dac_out
;		delay2
;		keyboard_read
;		cv_dac_val
;
;	None of those call again, so only use 1 stack entry (2 bytes).
;	Otherwise code is just a loop.
;
;	Does not use SEL RB instruction (i.e., no BANK 1 working regs)
;
;	Does not use START or STOP instructions! This means Timer/Counter
;	 function is not used. Uses T as another register.
;
;	80C49 clocked by 6MHz ceramic resonator
;
;	No external interrupt
;
; 	Sequencer can hold up to 100 steps
;

; ------------------------------------------------------------------------------
; T0/T1
;
; T0	HOLD external input
; T1	LFO trig input 

; ------------------------------------------------------------------------------
; DATA OUTPUT PORT
;
; D0	DAC LSB					Keyboard bank	(F3  - C4)
; D1	DAC					Keyboard bank	(C#4 - G#4)	
; D2	DAC					Keyboard bank	(A4  - E5)
; D3	DAC					Keyboard bank	(F5  - C6)
; D4	DAC		OCT COM			S3 RANGE COM	S7 ADSR COM
; D5	DAC MSB		BUTTONS COM
; D6			DAC ROUTE
; D7			DAC ROUTE
;
; D7 D6   DAC ROUTE
;  0  0	  CV OUT
;  0  1   VCO
;  1  0   RANDOM
;  1  1   unused

;
; Music keys split into 4 8-key banks.
; For each bank lowest key is connected to bit 0, highest to bit 7
;


; ------------------------------------------------------------------------------
; P1 INPUT PORT
;
; The D signals pull down commons, and the P1 port has 50K pullups.
; So, when a switch is "on" it reads as 0 (inverted sense)
;
;	D5 = 0		D4 = 0			D3-D0 = 0
;	======		======			=========
;
; P10	S14, LOAD	S3B, RANGE 16',4'	Keyboard - lowest note
; P11	S13, PLAY	S3A, RANGE 16',8'	Keyboard   .
; P12	S12, DOWN				Keyboard   .
; P13	S11, U&D	S7A, ADSR LFO		Keyboard   .
; P14	S10, UP		S7A, ADSR GATE+TRIG	Keyboard   .
; P15	S9,  HOLD	OCT UP			Keyboard   .	
; P16			OCT DOWN		Keyboard   .
; P17	S8, KEY TRANSP				Keyboard - highest note


; ------------------------------------------------------------------------------
; P2 OUTPUT PORT
;
; P20	LED select	\
; P21	LED select	Sequencer & Arpeggiator
; P22	LED select	/
; P23	PORTAMENTO OFF	
; P24	CLOCK RESET
; P25	LED select	HOLD	
; P26	LED select	KEY TRANSPOSE
; P27	GATE
;
; Funky LED drive via IC8, 4556, dual 2->4 decoders:
;
; P20 -> A1	/Q0 -> n/c
; P21 -> B1	/Q1 -> TR21
; P22 -> E1	/Q2 -> TR20
		/Q3 -> TR19
;
; P22 -> A2	/Q0 -> n/c
; P20 -> B2	/Q1 -> TR18
; P21 -> E2	/Q2 -> n/c
;		/Q3 -> TR17
;
; P25 -> TR16
; P26 -> TR10 -> TR15
;			     TR21 TR20 TR19       TR18      TR17
;  P22 P21 P20		1/Q0 1/Q1 1/Q2 1/Q3  2/Q0 2/Q1 2/Q2 2/Q3
;   0   0   0		 0    1    1    1     0    1    1    1
;   0   0   1		 1    0    1    1     1    1    0    1
;   0   1   0		 1    1    0    1     1    1    1    1
;   0   1   1		 1    1    1    0     1    1    1    1
;   1   0   0		 1    1    1    1     1    0    1    1
;   1   0   1		 1    1    1    1     1    1    1    0
;   1   1   0		 1    1    1    1     1    1    1    1
;   1   1   1		 1    1    1    1     1    1    1    1
;
; One transistor at a time is turned off.  P22-P20:
;
; 0 - all on
; 1 - TR21 - D46 - LOAD		\
; 2 - TR20 - D45 - PLAY		 \
; 3 - TR19 - D44 - DOWN		 mutually exclusive
; 4 - TR18 - D43 - UP & DOWN	 /
; 5 - TR17 - D42 - UP		/
; 6 - all on
; 7 - all on
;
; P25 = 0 ->            TR16 off - D41 - HOLD
; P26 = 1 -> TR10 on -> TR15 off - D40 - KEY TRANSPOSE
 
;
; RAM ORGANIZATION
;
; ------------------- All RAM can be indirectly accessed through R1/R0 (R1'/R0')
; 127	7F		\
;			 \
;			  \
;			   \
;			    \
;  32	20		     RAM loc 1B - 7F is used for 100 sequencer steps
; ------------------- BANK 1, directly accessible when BANK 1 is selected (not used!)
;  31	1F	R7'	    /
;  30	1E	R6'	   /
;  29	1D	R5'	  /
;  28	1C	R4'	 /
;  27	1B	R3'	/

;  26	1A	R2'
;  25	19	R1'
;  24	18	R0'
; ------------------- 8 LEVEL STACK (or user RAM)
;  23	17		Octave & LFO ADSR trigger (bit 6) stored here by RANGE DATA OUTPUT
;  22	16		Key Shift data (+Range?)
;  21	15
;  20	14		arp/sequencer related
;  19	13		last generated random number
;  18	12
;  17	11
;  16	10
;  15	0F
;  14	0E		something starts here, touched by keyboard_read 
;  13	0D		music keyboard bank 3
;  12	0C		music keyboard bank 2
;  11	0B		music keyboard bank 1
;  10	0A		music keyboard bank 0
;   9	09		RESERVED FOR CALL/RET
;   8	08		RESERVED FOR CALL/RET
; ------------------- BANK 0, directly accessible when BANK 0 is selected
;   7	07	R7
;   6	06	R6	OCTAVE setting: DOWN=0x00, NORM=0x0c, UP=0x18
;					bit 7 = 0 if GATE hi
;					bit 6 = 1 if LFO ADSR trigger (0x40,0x4c,0x58)
;					bit 5 = 0 if HOLD LED on
;   5	05	R5	RANGE setting: 16'=0x0c, 8'=0x18, 4'=0x24, 2'=0x30
;   4	04	R4	Last VCO RANGE, ADSR mode, OCTAVE switch state reading
;					bit 7 = n/a
;					bit 6 = OCT DOWN 
;					bit 5 = OCT UP 
;					bit 4 = S7A, ADSR GATE+TRIG 
;					bit 3 = S7A, ADSR LFO 
;					bit 2 = n/a
;					bit 1 = RANGE 16',8' 
;					bit 0 = RANGE 16',4' 
;   3	03	R3
;   2	02	R2	last raw key bank read
;   1	01	R1
;   0	00 	R0
;

;
; USER FLAGS
;
; F0
; F1	0 if S7 = GATE+TRIG
;	1 if S7 = LFO (and bit 6 will be set in r6)
;	==> 0 = keyboard last note priority
;	    1 = keyboard lowest note priority
;

;
; TIMER
;
; 80C49 can clock 8-bit internal timer from T1 input or xtal/480
; So here 6MHz / 480 = 12,500 counts / sec
; But this design does not use the Timer or Counter functions -- just the Timer T reg
;
; We call these T FLAGS
;
; b7: 
; b6: LFO hi/lo state
; b5: LFO H->L edge, lasts just 1 loop 
; b4: HOLD hi/lo state
; b3: 
; b2: used in key scanner 
; b1: used in cv_dac_val (FUNCTION SWITCH READ)
; b0: 
;
; There are 12 places that write to the T flags
; There are 27 places that read the T flags
;


	org	0

; ------------------------------------------------------------------------------
;       RESET ENTRY
;
	mov	a,#0dfh		; 1101 1111 
	outl	bus,a		;   ^- bit 5 is to read buttons 
	call	delay2		; let things settle
	in	a,p1
	add	a,#82h		; 1000 0010
				; if LOAD and KEY TRANS down, we will read
				;  0111 1110. 0x82 + 0x7e = 0x00
	jnz	START	

; ------------------------------------------------------------------------------
; 1. TEST MODE

TEST_MODE:
	mov	r0,#0		; r0 = previous button state
	mov	r1,#1		; r1 = last button(s) that went down
				;      (init to LOAD)

testloop:
	mov	a,#0dfh
	outl	bus,a		; drive DB5 low to read buttons
	call	delay2
	in	a,p1		; read buttons, 0 = btn down
	cpl	a		; 1 = btn down
	xch	a,r0		; swap this read with prev read
	xrl	a,r0		; A = bits that changed from previous read
	anl	a,r0		; A = bits that changed to 1 (btn now down)
	jz	handle_btns	

	mov	r1,a		; r1 = last button(s) that went down

handle_btns:
	clr	a
	mov	r2,a
	mov	r3,a		; start each loop with r2 = 0, r3 = 0

	mov	a,r1		; A = last btn(s) that went down
	cpl	a		; flip them
	jb0	not_LOAD

LOAD:				; KCV = 0V, Range = 0V, Gate = Off
	mov	r4,#0f9h	; 1111 1001 - gate off, LED state

not_LOAD:
	jb1	not_PLAY	

PLAY:				; KCV = 2.75V, Range = 0V, Gate = Off
	mov	r2,#21h		; !!! There is code that jumps to X0027,
				;     which would be the middle of this
				;     instruction.  Opcode 0x21 = xch A,@r1
				;     Seems like just a bug.  Bit rot?
	mov	r4,#0fah	; 1111 1010 - gate off, LED state

not_PLAY:
	jb2	not_DOWN	

DOWN:				; KCV = 2.5V, Range = 0V, Gate = Off
	mov	r2,#1eh
	mov	r4,#0fbh	; 1111 1011 - gate off, LED state

not_DOWN:
	jb3	not_UPDOWN	

UPDOWN:				; KCV = 4.75V, Range = 0V, Gate = On
	mov	r2,#39h
	mov	r4,#7ch		; 0111 1100 - gate off, LED state

not_UPDOWN:
	jb4	not_UP:	

UP:				; KCV = 0V, Range = 4.75V, Gate = On
	mov	r3,#39h
	mov	r4,#7dh		; 0111 1101 - gate off, LED state

not_UP:
	cpl	a
	jb5	START		; bit 5 = HOLD --> exit test mode

	mov	a,r2
	call	dac_out	
	anl	a,#3fh		; 00xx xxxx => 4052 output 0 => CV out
	outl	bus,a

	call	delay2

	mov	a,r3
	call	dac_out	
	anl	a,#7fh		; 01xx xxxx =? 4052 output 1 => VCO
	outl	bus,a

	mov	a,r4
	outl	p2,a

	jmp	testloop	


; ------------------------------------------------------------------------------
;       NORMAL START



; ------------------------------------------------------------------------------
; 2. INITIAL SET

START:
	mov	r0,#2
	clr	a
	mov	r1,#1ah		; clear 0x1a (26) bytes starting at loc 2

zero_ram:
	mov	@r0,a		; clears keyboard and switch data, but not seq data
	inc	r0
	djnz	r1,zero_ram


MAIN_LOOP:

; ------------------------------------------------------------------------------
; 3. RANGE DATA READ
;
; on exit:	R5 = VCO Range
;		R6 = Octave Transpose, ENV LFO ADSR trigger
;

; READ AND MEMORIZE THE POSITION OF THE VCO RANGE SWITCH

	mov	a,#0efh		; D4 = 0 --> set up to read OCTAVE SELECT,
	outl	bus,a		;            RANGE SELECT, ENV GEN TRIG SELECT

	mov	r5,#30h		; base range value

	in	a,p1		; read switch states (inverted, 0 = true)
				; d7: n/a
				; d6: OCT DOWN 
				; d5: OCT UP
				; d4: S7A, ADSR GATE+TRIG 
				; d3: S7A, ADSR LFO 
				; d2: n/a
				; d1: S3A, RANGE 16',8' 
				; d0: S3B, RANGE 16',4' 

	clr	f1
	cpl	f1		; F1 = 1 (assume lower note prio)

	jb4	not_gate_trig	; if S7 is on GATE+TRIG, bit 4 = 0

				; if we get here, S7 is on GATE+TRIG
	cpl	f1		; S7 = GATE+TRIG -> F1 = 0 --> last note prio
				;                   F1 = 1 --> lower note prio	

not_gate_trig:
	mov	r4,a		; R4 = A = RANGE, ADSR mode, OCTAVE switch states

;
; bit 0 = 0 -> 4' or 16'
; bit 0 = 1 -> 2' or 8'
; bit 1 = 0 -> 8' or 16'
; bit 1 = 1 -> 2' or 4'
;
; so:	00	16'
;	01	 8'
;	10	 4'
;	11	 2'
;

check_range:
	jb0	range_2_or_8	

range_4_or_16:
	xch	a,r5
	add	a,#0f4h		; 0x30 + 0xf4 = 0x24 for 16' or 4'
	xch	a,r5

range_2_or_8:
	jb1	range_2_4_or_16

range_8_or_16:
	xch	a,r5
	add	a,#0e8h
	xch	a,r5

range_2_4_or_16:
				; range = 16': r5 = 0x30 + 0xf4 + 0xe8 = 0x0c
				; range =  8': r5 = 0x30        + 0xe8 = 0x18
				; range =  4': r5 = 0x30 + 0xf4        = 0x24
				; range =  2': r5 = 0x30               = 0x30
				;
				; --> these make sense, each range is 12 apart


; READ AND MEMORIZE THE POSITION OF THE TRANSPOSE (L, M, H) SWITCH
; A still holds last  R4, the VCO RANGE, ADSR mode, and OCTAVE switch settings
; (which are active low!)

check_octave:
	jb6	oct_up		; b6 = 1 --> OCTAVE UP
				; b6 = 0 --> OCTAVE DOWN or MIDDLE

	jb5	oct_down	; b5 = 1 --> OCTAVE DOWN
				; b5 = 0 --> OCTAVE UP or MIDDLE
	
	mov	r6,#0ch		; middle setting, neither up nor down, R6 = 0x0c (norm)
	jmp	oct_adj_done	

oct_up:
	mov	r6,#18h		; octave up, R6 = 0x18 (norm +12)
	jmp	oct_adj_done	

oct_down:
	mov	r6,#0		; octave down, R6 = 0x00 (norm -12)


; READ AND MEMORIZE THE POSITION OF THE ENV LFO SWITCH
; A still holds last  R4, the VCO RANGE, ADSR mode, and OCTAVE switch settings
; (which are active low!)

oct_adj_done:
	jb3	not_adsr_lfo	; b3 = 1 --> ADSR trigger GATE or GATE+TRIG	

	mov	a,r6
	orl	a,#40h		; set bit 6 in r6 to indicate LFO ADSR trigger
	mov	r6,a

not_adsr_lfo:


; ------------------------------------------------------------------------------
; 4. RANGE DATA OUTPUT
;
; on entry:	R5 = Range
;		R6 = Octave, LFO ADSR trigger (bit 6)
;

; THE CPU SENDS THE VCO RANGE DATA (READ IN STEP 3) TO THE D/A CONVERTER
;
;	Range Selector		Range Data
;		16'		1V
;		 8'		2V
;		 4'		3V
;		 2'		4V
;
; IF THE CPU CONTAINS KEY TRANSPOSE DATA (STORED DURING STEP 8 OF THE PREVIOUS
; PROGRAM EXECUTION), THE KEY SHIFT DATA IS ADDED TO THE RANGE SELECTOR DATA.
; FOR EXAMPLE, IF THE USER SELECTS THE LOWEST F-KEY AND SETS THE RANGE SELECTOR
; TO 16', THE RANGE DATA WILL BE 0.417V.  LIKEWISE, IF THE USER SELECTS A HIGHER
; C-KEY AND SETS THE RANGE SELECTOR TO 2', THE RANGE DATA WILL BE 5V.

	mov	r0,#17h
	mov	a,r6		; R6 = OCTAVE setting, GATE, LFO ADSR mode, HOLD LED 
	mov	@r0,a

	dec	r0		; R0 -> 0x16 (Key Shift data)

	mov	a,r5		; R5 = range data
	add	a,@r0		; add Key Shift data
	call	dac_out		; drive DAC data, but don't route anywhere

	anl	a,#7fh		; 01xx xxxx => 4052 output 1 => VCO
	outl	bus,a		; now route the DAC to the VCO

; THE CPU USES A 4X8 MATRIX TO READ THE NUMBER AND POSITION OF KEYS BEING PRESSED
; ON THE KEYBOARD, AND DETERMINES THE OUTPUT PRIORITY OF THE CV DATA AND WHETHER
; NEW GATE SIGNAL SHOULD BE OUTPUT ACCORDING TO THE KEY MODE (LEGATO OR NON-LEGATO)
; AND THE SETTINGS OF THE PANEL CONTROLS (PORTAMENTO, ARPEGGIO, GATE/TRIG, ETC.)

	call	keyboard_read	; 5. KEYBOARD READ
				; 6. CLOCK CHECK

				; 7. RANDOM DATA OUTPUT (random data in A here)
	call	dac_out	
	anl	a,#0bfh		; 10xx xxxx => 4052 output 2 => Random waveform out
	outl	bus,a
	call	delay2

	call	cv_dac_val	; 8. FUNCTION SW READ
				; 9. LOAD
				; 10. PLAY
				; 11. ARPEGGIO

				; 12. CV OUTPUT
	call	dac_out	
	anl	a,#3fh		; 00xx xxxx => 4052 output 0 => CV out
	outl	bus,a

	jmp	update_outputs	


; = CALL =======================================================================
; ------------------------------------------------------------------------------
; 5. KEYBOARD READ
;
; Behavior when more than 1 key is pressed depends on ADSR mode:
;
; GATE:		lower note priority
; GATE + TRIG:	last note priority
; LFO:		lower note priority
;
; Flag F1 = 0 if ADSR mode = GATE + TRIG.  So:
;
; F1 = 0 --> last note priority
; F1 = 1 --> lower note priority
;
; We scan low bank -> high bank, and in each bank low key -> high key.
; So, in low key priority mode, as soon as we find a key down, we are done.
; In last key priority mode, we have an extra step: XOR the keys down at
;  the last pass with the keys down now, then find the lowest of those.
;
; Flag F0 = 1 when we have found our low (or last) key.
;
; R0 -> locs 0a, 0b, 0c, 0d = key bank states
; R2 = read current keys down in this bank
; R3 = raw key # 0-7
; R4 = keys that changed that are down now
; R5 = single 0 marched for scan 
; R7 = 4->0 bank scan countdown
;
; Returns random data in A
;

keyboard_read:
	mov	r1,#0eh		; r1 -> RAM loc 0e

	clr	f0		; haven't found low (or last) key yet 

	jf1	read_low_note_prio

read_last_note_prio:

	mov	a,@r1
	inc	a		; 
	mov	r4,a

read_low_note_prio:

; ------------------------------------------------------------------------------
; Scan music keyboard
;
; Trashes r0, r2, r3, r4, r5, r6, r7
;
; On Entry:
; F1 tells key scan mode: 0 = last note priority, 1 = low note priority
; r4 = value read from RAM loc 0e
;
; Used:
; r0 -> key bank state address, goes 0a, 0b, 0c, 0d
; r2 = last bank read, 8 keys, current key state (1 = down)
; r3 = raw key #
; r5 = key bank column drive (marching 0)
; r6 = scratch counter, 0-7 for keys in a bank
; r7 
;

init_music_kb_scan:
	mov	r0,#0ah		; locs 0a, 0b, 0c, 0d = key bank states
	mov	r3,#0		; raw key #

	mov	r5,#0feh	; march a 0 for keyboard scan
				; scan banks lowest -> highest notes
	mov	r7,#4		; 4x 8-key banks

keyboard_scan:
	mov	a,r5
	outl	bus,a		; drive one bank's common low
	rl	a		; rotate 0 into pos for next part of scan
	mov	r5,a

	in	a,p1		; read in 8 keys
	cpl	a		; as read 0 = down, so invert -> 1 = down

	mov	r2,a		; R2 = current keys down in this bank       \ low note
				;  A = current keys down in this bank       /   prio

	jf1	scan_low_note_prio

scan_last_note_prio:

	xrl	a,@r0		; R0 -> previous keys down state for this bank, so now
				;  A = keys that changed since last scan

	anl	a,r2		;  A = keys that changed that are down now

	xch	a,r2		; R2 = keys that changed that are down now  \ last note 
				;  A = current keys down in this bank       /   prio
scan_low_note_prio:

	mov	@r0,a		; update current keys down in this bank loc

	jf0	rd_next_bank	; already found low key, skip this bank

	xch	a,r2		; see above for A / R2 contents 
	mov	r6,#8		; 8 keys per bank

	; ----------------------- 
	; A = keys to check (keys down)
	;
	; for low key priority,  R2 = current keys down in this bank
	; for last key priority, R2 = keys that just changed to down in this bank 
	;
	; 1 = key down

chk_keys:
	rrc	a		; lowest bit from "keys to check" into carry
				; rotating right checks keys in low -> high note order
	jc	key_is_down	

	jf1	low_note_prio	; if not low note prio, just bump raw note num and
				;  look at the next higher key
last_note_prio:	

	xch	a,r4		; R4 = keys that changed that are down now
				;  A = loc 0x0e that was read and possibly incremented 
				;      on entry to this pass
	dec	a
	xch	a,r2		;  A = current keys down in this bank
				; R2 = incremented/decremented loc 0x0e 

	rrc	a		; 1 bit from "current keys down in this bank" to C

	xch	a,r2		;  A = incremented/decremented loc 0x0e
				; R2 = current keys down in this bank
	jnz	X00dc		; jump if there are keys down now
	jc	X00dc		; jump if the bit we shifted out was a key down

	cpl	f1
	jmp	init_music_kb_scan	

key_is_down:
	cpl	f0		; found low key!
	mov	a,r3
	mov	@r1,a		; store raw key # @R1 (loc 0eh)
	jmp	rd_next_bank	; in low note prio mode, 1st one we find is lowest	

X00dc:	xch	a,r4

low_note_prio:
	inc	r3		; raw key # goes 0->7 from low keys to high in bank
	djnz	r6,chk_keys

	; ----------------------- 

rd_next_bank:
	inc	r0		; R0 -> next "current keys down in this bank" loc
	djnz	r7,keyboard_scan	; 4 banks


	clr	f1
	cpl	f1		; F1 = 1 --> low note prio

	mov	r0,#0ah		; R0 -> 1st key bank state
	mov	r5,#0		; 
	mov	r7,#4		; R7 = 4->0 bank scan countdown

X00eb:	mov	a,@r0		; A = key bank state
	jz	X00f7		; nothing down?

	mov	r6,#8		; something down, check all 8 bits

X00f0:	rrc	a
	jnc	X00f5

	inc	r5
	clr	f1

X00f5:	djnz	r6,X00f0

X00f7:	inc	r0		; next key bank
	djnz	r7,X00eb

	mov	a,@r1
	mov	r3,a
	mov	a,t		; === READ T flags

	clr	f0
	cpl	f0

	jb2	X0127		; !!! was X0027, isn't this really jb2 X0127?
				; !!! was X0027, isn't this really jb2 X0127?

	jf1	X0123

	orl	a,#0ch		; set T flag b2 and b3
	jmp	X012d



X0107:	mov	r0,#13h
	mov	r6,a
	jb1	X010d

	clr	f0

X010d:	mov	a,@r0
	anl	a,#0c0h
	jf0	X011a

	mov	r7,#80h
	cpl	f0
	jz	X011f

X0117:	mov	a,r6
	jmp	X012d
;
X011a:	add	a,#40h
	mov	r7,a
	jc	X0117

X011f:	cpl	f0
	mov	a,r6
	jmp	X012b



X0123:	anl	a,#0f3h		; clear T flag b2 and b3
	jmp	X012d

X0127:
	anl	a,#0f3h		; clear T flag b2 and b3
	jf1	X0107

X012b:	orl	a,#4		; set T flag b2

X012d:	anl	a,#7fh		; clear T flag b7


; ------------------------------------------------------------------------------
; 6. CLOCK CHECK
;
; ANY VARIATION IN THE VOLTAGE OF THE CLOCK SIGNAL (LFO OR EXT CLK) IS
; DETECTED AT THE T1 TERMINAL.  IF A LOW CLOCK SIGNAL TURNS HIGH, TR11 INVERTS
; IT TO LOW AND SENDS IT TO THE CPU, WHICH THEN PERFORMS THE FOLLOWING
; OPERATIONS:
;		(A) GENERATES RANDOM DATA
;		(B) PREPARES THE DATA FOR ARPEGGIO AND SEQUENCER PLAYING
;
;
; Normally the LFO is the CLK. If you plug a cable into the EXT CLK IN jack,
;  the jack disconnects the LFO and feeds the external signal in.
;
; T flag b6 = current LFO state (hi / lo)
; T flag b5 = LFO just went H->L (lasts just 1 loop, so it's a H->L edge)
;

	jnt1	lfo_trig_lo	

lfo_trig_hi:			; H now
	orl	a,#40h		; set T flag b6		-- remember it is H
	jmp	X0139

lfo_trig_lo:			; L now
	jb6	clk_was_hi	; was it H last time?	-- is this H->L edge?

	anl	a,#0bfh		; clear T flag b6	-- no, just remember it is L 


X0139:	anl	a,#0dfh		; clear T flag b5	-- not H->L edge, so b5 = 0 
	jmp	X0141


clk_was_hi:			;			-- this is H->L edge
	anl	a,#0bfh		; clear T flag b6 	-- remember it is L
	orl	a,#20h		; set T flag b5		-- b5 = 1 to indicate edge
				;			   (b5 will be cleared next pass)

X0141:	mov	t,a		; === STORE T flags

	mov	r0,#13h		; r0 -> last generated random #
	cpl	a		; done to flip b5 (CLK H->L edge)
	jb5	update_random	; it was not an edge, so just update random & done

update_arp_seq:			; we just got a CLK H->L edge, clock the arp/seq
	mov	r1,#14h		; r1 -> RAM loc 14

X0149:	inc	@r1
	mov	a,@r1
	movp	a,@a		; ??? 
	anl	a,#3fh		; A = 0 - 63
	jz	X0149		; looks for the pgm mem loc that contains 00, 40, 80, or c0

	add	a,@r0		; some more entropy for the random #
	mov	@r0,a

update_random:
	mov	a,@r0		; last random # -> A 
	anl	a,#3fh		; 0-63
	jf0	found_low_key	
	orl	a,r7		; r7 is whatever it is, more randomness

found_low_key:
	mov	@r0,a		; returns random byte in A, rememebers it in RAM loc 13
	ret

; = RETURN =====================================================================


; = CALL =======================================================================
; ------------------------------------------------------------------------------
; 8. FUNCTION SWITCH READ
;
; THE CPU SCANS ALL THE FUNCTION SWITCHES IN ORDER TO DETECT ANY CHANGES MADE
; BY THE USER.  IF AN ON/OFF CHANGE IS DETECTED, THE CPU JUMPS TO THE
; APPROPRIATE STEP.
; REFER TO THE FLOW CHART.  THE CPU CAN DETECT THE ON/OFF STATUS OF THE HOLD
; FUNCTION AT BOTH THE PANEL BUTTON AND THE PEDAL SWITCH.  WHEN THE KEY
; TRANSPOSE BUTTON IS PRESSED AND A NEW KEY SELECTED, THE CPU IDENTIFIES THE
; KEY THAT WAS PRESSED ON THE KEYBOARD ADN THUS IDENTIFIES THE KEY (PITCH)
; TO THE TRANSPOSED.

cv_dac_val:
	mov	a,#0dfh		; D5 = 0 --> prep to read buttons
	outl	bus,a

	mov	r0,#19h
	mov	r1,#15h
	clr	f0

	in	a,p1		; read buttons
	mov	r2,a

	jb7	not_key_transp	
	jf1	not_key_transp	
	mov	r4,a
	inc	r1
	mov	a,r3
	add	a,#0ech
	mov	a,r3
	jnc	X0172
	add	a,#0f4h
X0172:	add	a,#0f9h
	mov	@r1,a
	dec	r1

	mov	a,t		; === READ T flags
	jb1	X017d
	mov	a,@r1
	jb7	X0180

	mov	a,t		; === READ T flags

X017d:	anl	a,#0f3h		; clear T flag b3 and b2
	mov	t,a		; === STORE T flags
X0180:	mov	a,r4

not_key_transp:
	orl	a,#80h
	clr	f1
	cpl	f1		; F1 = 1
	cpl	a		; make it so 1 = down
	mov	r4,a		; R4 = current down/up state
	xrl	a,@r0		; xor with previous down/up state for 1 = changed
	anl	a,r4		; A = buttons which just changed to down
	xch	a,r4		; A = current down/up state
	mov	@r0,a		; save it for next time
	mov	a,r4		; A = buttons which just changed to down
	anl	a,#1fh		; only care about UP, U&D, DOWN, PLAY, LOAD
	mov	r6,a		; R6 = just changed to down state for those
	mov	a,r4		; A = all buttons which just changed to down
	jz	no_btns_just_dn	

	mov	a,@r1
	anl	a,#3fh
	anl	a,r4
	jz	X01a8
	jb5	X01a0

	mov	a,@r1
	jb5	X019e

	clr	f1
X019e:	jmp	X01a5
;
X01a0:	clr	f1
	anl	a,#1fh
	jz	X01b7
X01a5:	clr	a
	jmp	X01c7
;
X01a8:	mov	a,r4
	jb5	X01b1

	mov	a,@r1
	jb5	X01b4

	clr	f1
	jmp	X01b4
;
X01b1:	mov	a,r6
	jz	X01ba
X01b4:	mov	a,r6
	jmp	X01c7
;
X01b7:	mov	a,r6
	jnz	X01b4
X01ba:	mov	a,@r1
	anl	a,#1fh
	jmp	X01c7
;
no_btns_just_dn:
	mov	a,@r1
	anl	a,#3fh
	jb5	X01c5
	clr	f1
X01c5:	anl	a,#1fh
X01c7:	xch	a,r6

	mov	a,t		; === READ T flags

; ------------------------------------------------------------------------------
; Handle external HOLD input

	jt0	hold_input_hi	; if external HOLD switch is closed, T0 = 0 (ground)

hold_input_lo:			; external HOLD requested
	clr	f1
	cpl	f1		; --> F1 = 1, HOLD requested
	orl	a,#10h		; set T flags b4
	jmp	X01d9

hold_input_hi:			; external HOLD not requested
	cpl	a		; invert T flags
	jb4	X01d6		; b4 = HOLD, inverted, so jump if HOLD was 0

	clr	f1		; --> F1 = 0, HOLD not requested
	cpl	f0

X01d6:	mov	a,t		; === READ T flags 
	anl	a,#0efh		; clear T flag b4
 
X01d9:	jf1	X01dd
	anl	a,#0fdh		; clear T flag b1 

X01dd:	mov	t,a		; === STORE T flags 
	xch	a,r6
	jz	X01eb
	jb0	load_dn		; b0 = LOAD
	jb1	play_dn		; b1 = PLAY
	jmp	X02db

load_dn:
	jmp	handle_load	

play_dn:
	jmp	handle_play	



X01eb:	mov	r6,#0ffh
X01ed:	mov	a,#1bh
	mov	r0,a
	mov	@r0,a
X01f1:	mov	r0,#1ah
	mov	a,r6
	cpl	a
	jb7	X01ff
	mov	a,t		; === READ T Flags
	jb1	X01ff
	jb2	X01ff
	mov	a,@r0
	jmp	X0207
;
X01ff:	mov	a,r3
	mov	r1,#18h
	mov	@r1,a
	dec	r1
	mov	a,r3
	add	a,@r1
	mov	@r0,a
X0207:	add	a,#5
	ret

; = RETURN =====================================================================


; = CALL =======================================================================

delay2:	mov	r7,#2
dly2:	djnz	r7,dly2
	ret

; = RETURN =====================================================================

; ------------------------------------------------------------------------------
handle_load:
	mov	r0,#17h		; r0 -> RAM loc 17
	clr	f1
	mov	a,r3
	add	a,@r0
	mov	r5,a

	mov	r0,#1bh		; r0 -> RAM loc 1b, base of seq step data
	mov	a,@r0
	clr	f0
	jb7	X021c

	cpl	f0
X021c:	anl	a,#7fh
	mov	@r0,a
	add	a,#0e5h
	jnz	X0231
	mov	a,t		; === READ T Flags
	jb2	X0229
	mov	a,r2
	jb7	X0231
X0229:	inc	r0
	clr	a
	mov	r7,#64h
X022d:	mov	@r0,a
	inc	r0
	djnz	r7,X022d
X0231:	mov	a,t		; === READ T Flags
	cpl	a
	jb2	X0269
	mov	r6,#7eh
	mov	a,r5
	cpl	a
	mov	r0,#18h
	add	a,@r0
	inc	a
	jnz	X0243
	mov	a,t		; === READ T Flags
	cpl	a
	jb3	X0276
X0243:	clr	f0
X0244:	mov	r0,#1bh
	mov	a,@r0
	mov	r1,a
	cpl	f0
	jf0	X024e
	orl	a,#80h
	mov	@r0,a
X024e:	inc	@r0
	inc	r1
	mov	a,r1
	anl	a,#7fh
	jz	X0284
	mov	a,r5
	jf0	X025c
	orl	a,#40h
	jmp	X0266
;
X025c:	orl	a,#80h
	xch	a,r2
	jb5	X0265
	xch	a,r2
	orl	a,#40h
	xch	a,r2
X0265:	xch	a,r2
X0266:	mov	@r1,a
	jmp	X0276
;
X0269:	mov	r6,#0feh
	mov	a,r2
	jb7	X0276
	jf0	X0244
	mov	r0,#1bh
	mov	a,@r0
	orl	a,#80h
	mov	@r0,a
X0276:	mov	r0,#16h
	mov	@r0,#0
X027a:	mov	r0,#17h
	mov	a,@r0
	anl	a,#40h
	mov	@r0,a
	mov	a,r5
	mov	r3,a
	jmp	X01f1
;
X0284:	jmp	X01eb
;

; ------------------------------------------------------------------------------
handle_play:
	mov	r1,#1bh
	mov	a,t		; === READ T Flags
	anl	a,#0f1h
	mov	t,a		; === STORE T Flags
	cpl	a
	jb5	X0297
	inc	@r1
	mov	a,@r1
	mov	r0,a
	mov	a,@r0
	jb6	X0297
	mov	r2,#0
X0297:	mov	r0,#15h
	mov	a,@r0
	jb1	X02a4
	mov	r0,#17h
	mov	@r0,#40h
	mov	a,t		; === READ T Flags
	orl	a,#8
	mov	t,a		; === STORE T Flags
X02a4:	mov	a,@r1
	add	a,#0e5h
	jnz	X02ad
	mov	r6,#0fdh
	jmp	X01f1
;
X02ad:	mov	a,@r1
	anl	a,#7fh
	mov	r0,a
	jnz	X02b7
	mov	@r1,#1ch
	jmp	X0297
;
X02b7:	mov	a,@r0
	jnz	X02c3
	mov	a,@r1
	add	a,#0e4h
	jz	X0284
	mov	@r1,#1ch
	jmp	X0297
;
X02c3:	jb7	X02c9
	mov	r6,#0fdh
	jmp	X02d1
;
X02c9:	xch	a,r2
	mov	r6,#7dh
	jnz	X02d0
	mov	r6,#0fdh
X02d0:	mov	a,r2
X02d1:	anl	a,#3fh
	mov	r5,a
	cpl	f0
	jf0	X02d9
	mov	r6,#0ffh
X02d9:	jmp	X027a
;
X02db:	mov	r6,a
	mov	a,t		; === READ T Flags
	jb1	X02fa
	mov	a,r5
	add	a,#0feh
	jc	X02fa
	clr	f0
	mov	a,t		; === READ T Flags
	anl	a,#0fch
	mov	t,a		; === STORE T Flags
X02e9:	mov	a,r6
	jb2	X02f2
	jb3	X02f6
X02ee:	mov	r6,#0efh
	jmp	X01ed
;
X02f2:	mov	r6,#0fbh
	jmp	X01ed
;
X02f6:	mov	r6,#0f7h
	jmp	X01ed
;
X02fa:	mov	a,t		; === READ T Flags
	orl	a,#80h
	mov	t,a		; === STORE T Flags
	cpl	a
	clr	f0
	jb1	X0306
	mov	a,t		; === READ T Flags
	cpl	a
	jb3	X0307
X0306:	cpl	f0
X0307:	mov	a,r2
	cpl	a
	jb7	X031a
	mov	r0,#0ah
	mov	r1,#0fh
	mov	r7,#4
X0311:	mov	a,@r0
	jf0	X0315
	orl	a,@r1
X0315:	mov	@r1,a
	inc	r0
	inc	r1
	djnz	r7,X0311
X031a:	mov	a,t		; === READ T Flags
	jb1	X0325
	jf1	X0321
	jmp	X032c
;
X0321:	orl	a,#2
	jmp	X032b
;
X0325:	cpl	a
	jb3	X032c
	mov	a,t		; === READ T Flags
	anl	a,#0fdh
X032b:	mov	t,a		; === STORE T Flags
X032c:	mov	a,t		; === READ T Flags
	jb5	X033c
	cpl	a
	jb3	X0336
	mov	a,t		; === READ T Flags
	anl	a,#0fdh
	mov	t,a		; === STORE T Flags
X0336:	mov	r0,#18h
	mov	a,@r0
	mov	r3,a
	jmp	X02e9
;
X033c:	mov	r0,#18h
	mov	a,@r0
	jb5	X0343
	jmp	X0345
;
X0343:	mov	a,r3
	mov	@r0,a
X0345:	mov	r4,a
	clr	f0
	mov	a,r6
	jb2	X03a6
	jb4	X0352
	mov	r6,#0
	cpl	f0
	mov	a,t		; === READ T Flags
	jb0	X03a6
X0352:	mov	r0,#0eh
	mov	r3,#0f7h
	mov	r7,#5
X0358:	mov	a,#8
	add	a,r3
	mov	r3,a
	dec	r7
	inc	r0
	mov	a,#0f8h
	add	a,r4
	mov	r4,a
	jc	X0358
	add	a,#9
	mov	r4,a
	mov	a,@r0
	jz	X0377
	mov	r1,#8
X036c:	inc	r3
	dec	r1
	rrc	a
	djnz	r4,X036c
	xch	a,r1
	jz	X037b
	xch	a,r1
	jmp	X038b
;
X0377:	mov	a,#8
	add	a,r3
	mov	r3,a
X037b:	inc	r0
	djnz	r7,X0386
	jf0	X0399
	mov	r0,#0fh
	mov	r7,#4
	mov	r3,#0ffh
X0386:	mov	r1,#8
	mov	a,@r0
	jz	X0377
X038b:	inc	r3
	rrc	a
	jnc	X0395
	jf0	X0393
	jmp	X02ee
;
X0393:	jmp	X02f6
;
X0395:	djnz	r1,X038b
	jmp	X037b
;
X0399:	mov	a,t		; === READ T Flags
	orl	a,#1		; set b0
	mov	t,a		; === STORE T Flags
	mov	r0,#18h
	mov	a,@r0
	mov	r4,a
	mov	a,r6
	jz	X03a5
	inc	r4
X03a5:	inc	r6
X03a6:	mov	r0,#13h
	mov	r3,#28h
	mov	r7,#5
	mov	a,r4
	cpl	a
	add	a,#20h
	mov	r4,a
X03b1:	mov	a,#0f8h
	add	a,r3
	mov	r3,a
	dec	r7
	dec	r0
	mov	a,#0f8h
	add	a,r4
	mov	r4,a
	jc	X03b1
	add	a,#9
	mov	r4,a
	mov	a,@r0
	jz	X03d0
	mov	r1,#8
X03c5:	dec	r3
	dec	r1
	rlc	a
	djnz	r4,X03c5
	xch	a,r1
	jz	X03d4
	xch	a,r1
	jmp	X03e4
;
X03d0:	mov	a,#0f8h
	add	a,r3
	mov	r3,a
X03d4:	dec	r0
	djnz	r7,X03df
	jf0	X03f0
	mov	r0,#12h
	mov	r7,#4
	mov	r3,#20h
X03df:	mov	r1,#8
	mov	a,@r0
	jz	X03d0
X03e4:	dec	r3
	rlc	a
	jnc	X03ec
	jf0	X0393
	jmp	X02f2
;
X03ec:	djnz	r1,X03e4
	jmp	X03d4
;
X03f0:	mov	a,t		; === READ T Flags
	anl	a,#0feh		; clear b0
	mov	t,a		; === STORE T Flags
	mov	r0,#18h
	mov	a,@r0
	mov	r4,a
	jmp	X0352
;


; = CALL =======================================================================

; Set the 6-bit DAC and program the analog mux to not drive it anywhere
;

dac_out:
	cpl	a
	orl	a,#0c0h		; 11xx xxxx => DAC not routed anywhere
	outl	bus,a
	ret

; = RETURN =====================================================================


; ------------------------------------------------------------------------------
; 13. GATE & LED DATA OUTPUT 
;
; 	Update LEDs, GATE, CLOCK RESET, and PORTAMENTO OFF signals
;

update_outputs:
	mov	r1,#15h		; r1 -> RAM loc 15
	mov	a,r6		; A = OCTAVE / GATE / LFO ADSR / HOLD LED

	cpl	f1
	jf1	X040b

	anl	a,#0dfh		; b5 = 0 --> HOLD LED on
	mov	r6,a

	mov	a,@r1
	jb7	X040f

X040b:	mov	a,t		; === READ T Flags
	cpl	a
	jb2	X0413

X040f:	mov	a,r6
	anl	a,#7fh		; b7 = 0 --> GATE hi
	mov	r6,a

X0413:	mov	r0,#16h		; r0 -> RAM loc 16
	mov	a,@r0
	jnz	X041c

	mov	a,r6
	anl	a,#0bfh		; b6 = 0 --> KEY TRANSPOSE LED on (LFO ADSR trigger?)
	mov	r6,a

X041c:	mov	a,@r1
	cpl	a
	xrl	a,r6
	jb1	X0438
	mov	r4,a
	mov	a,t		; === READ T Flags
	cpl	a
	jb1	X0440
	mov	a,r4
	jb4	X042f
	jb3	X0431
	jb2	X0433
	jmp	X0440
;
X042f:	jb3	X0440
X0431:	jb2	X0440
X0433:	anl	a,r5
	anl	a,#1ch
	jnz	X0440

X0438:	mov	a,t		; === READ T Flags
	anl	a,#0f9h		; clear b2 and b1
	mov	t,a		; === STORE T Flags
	mov	a,r6
	orl	a,#80h		; GATE low
	mov	r6,a

X0440:	mov	a,r6
	jb0	X0451
	mov	a,r2
	jb7	trans_led_on	
	xch	a,r6
	orl	a,#40h		; KEY TRANSPOSE LED off
	xch	a,r6

trans_led_on:
	jb5	X0450
	mov	a,r6
	anl	a,#0dfh		; HOLD LED on
	mov	r6,a

X0450:	mov	a,r6
X0451:	cpl	a
	mov	@r1,a
	anl	a,#1fh
	jz	X0483

	mov	r7,#0f8h
	mov	r5,#5

X045b:	inc	r7
	rrc	a
	jc	X0461
	djnz	r5,X045b

X0461:	mov	a,r6
	orl	a,#1fh
	anl	a,r7
	mov	r6,a
	inc	r0
	jb7	X0470
	mov	a,r5
	jz	X0478
	add	a,#0fbh
	jz	X0478

X0470:	mov	a,t		; === READ T Flags
	cpl	a
	jb3	X0478
	mov	a,r6
	anl	a,#0efh		; clear GATE
	mov	r6,a

X0478:	mov	a,t		; === READ T Flags 
	jb7	X047f		; b7 = 0 -> time to clear PORTA OFF
	mov	a,r6
	anl	a,#0f7h		; clear PORTAMENTO OFF
	mov	r6,a

X047f:	mov	a,r6
	outl	p2,a		; update LEDs, CLOCK RESET and  GATE

	jmp	MAIN_LOOP	; back to Step 3!
	

X0483:	inc	r0
	mov	a,@r0
	jb6	X0470
	jmp	X0478


	end

