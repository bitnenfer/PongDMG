	lib Registers

	isdmg
	offbankgroup
	puball
	
title 	group 	$00
	; Interrupts and Catridge Header
	org $0000
	
	; Interrupts
	ret
	org *+$08
	ret
	org *+$10
	ret
	org *+$18
	ret
	org *+$20
	ret
	org *+$28
	ret
	org *+$30
	ret
	org *+$38
	ret
	org *+$40
	ret
	org *+$48
	ret
	org *+$50
	ret
	org *+$58
	ret
	org *+$60
	ret
		
	org $0100
	nop
	jp EntryPoint
	
	;; NINTENDO LOGO
	db $CE,$ED,$66,$66		
	db $CC,$0D,$00,$0B
	db $03,$73,$00,$83
	db $00,$0C,$00,$0D
	db $00,$08,$11,$1F
	db $88,$89,$00,$0E
	db $DC,$CC,$6E,$E6
	db $DD,$DD,$D9,$99
	db $BB,$BB,$67,$63
	db $6E,$0E,$EC,$CC
	db $DD,$DC,$99,$9F
	db $BB,$B9,$33,$3E

	;; TITLE
	db "P","O","N","G"		
	db "D","M","G",$00
	db $00,$00,$00,$00
	db $00,$00,$00

	;; GAMEBOY COLOR
	db $00			
	;; MAKER
	db $00,$00			
	;; MACHINE
	db $00			
	;; CASSETTE TYPE
	db $00			
	;; ROM SIZE
	db $00			
	;; RAM SIZE
	db $00			
	;; COUNTRY
	db $01			
	;; GAMEBOY
	db $00			
	;; ROM VERSION
	db $00			
	;; NEGATIVE CHECK
	db $67			
	;; CHECK SUM
	db $00,$00			
	
	
; Constants
StartDMA	equ $FF80 
MoveSpeed	equ $02
PuckSpeed 	equ $01
		
Main	group $00
		org $0150
	
	; Code
EntryPoint:
	
	; Turn off LCD
	ld hl,LCDC
	res $07,(hl)
	
	; Enable Sprites
	set $01,(hl)
	
	; Clear OAM RAM
	ld hl,OAM0
	ld de,OAM39_ATTRIB
	ld b,$00
	call MemSet
	
	; Init Shadow OAM
	call InitShadowOAM
	
	; Load Tiles
	ld bc,TileData
	ld hl,VRAM_TILE_START
	ld de,96
	call MemCpy
	
	; Set Palette
	ld a,%11010100
	ld (BGP),a
	ld a,%11101100
	ld (OBJP0),a
	ld (OBJP1),a
	
	; Clear Screen
	ld hl,VRAM_BGMAP0_START
	ld de,VRAM_BGMAP0_END
	ld b,$01
	call MemSet
	
	; Initialize Player Paddle
	ld a,$00
	ld (SPRITE0_TILE),a
	ld a,$04
	ld (SPRITE1_TILE),a
	ld a,$05
	ld (SPRITE2_TILE),a
	ld a,LCD_WIDTH/2+2
	ld (SPRITE1_Y),a
	ld a,$10
	ld (SPRITE0_X),a
	ld (SPRITE1_X),a
	ld (SPRITE2_X),a
	
	; Initialize CPU Paddle
	ld a,$00
	ld (SPRITE4_TILE),a
	ld a,$04
	ld (SPRITE5_TILE),a
	ld a,$05
	ld (SPRITE6_TILE),a
	ld a,LCD_WIDTH/2+2
	ld (SPRITE5_Y),a
	ld a,LCD_WIDTH-$8
	ld (SPRITE4_X),a
	ld (SPRITE5_X),a
	ld (SPRITE6_X),a
	
	; Set Middle Line
	ld a,$02
	ld ($9809),a
	ld ($9849),a
	ld ($9889),a
	ld ($98C9),a
	ld ($9909),a
	ld ($9949),a
	ld ($9989),a
	ld ($99C9),a
	ld ($9A09),a
	ld ($9A49),a
	ld ($9A89),a
	ld ($9AC9),a
	ld ($9B09),a
	ld ($9B49),a
	ld ($9B89),a
	ld ($9BC9),a
	ld a,$00
	ld (ScrollBackground),a
	
	; Reset ScrollX to avoid doing Reset Hardware 
	; every time
	xor a 
	ld (SCY),a
	ld (SCX),a
	
	; Center the middle line
	ld a,(SCX)
	sub $04
	ld (SCX),a
	
	; Initialize Puck
	ld a,$03
	ld (SPRITE3_TILE),a
	ld a,LCD_WIDTH/2
	ld (SPRITE3_X),a
	ld a,LCD_HEIGHT/2+8
	ld (SPRITE3_Y),a
	ld a,-PuckSpeed
	ld (PuckVelX),a
	ld (PuckVelY),a
	
	; Turn on LCD
	ld hl,LCDC
	set $07,(hl)
	
MainLoop:
	; First Wait for V-Blank
	call WaitVBlank
	
_HandleInput:
	; Handle Input
	; Direction Button Reading
	ld hl,JOYP
	res $04,(hl)
	
	; Checking for Button Down
_TestBtnDown:
	bit $03,(hl)
	jr nz,_TestBtnUp
	ld a,(SPRITE1_Y)
	add a,MoveSpeed
	ld (SPRITE1_Y),a

	; Check Bottom Limit
	cp LCD_HEIGHT
	jr c, _FinishedInputHandling
	ld a,LCD_HEIGHT
	ld (SPRITE1_Y),a
	jr _FinishedInputHandling

_TestBtnUp:
	bit $02,(hl)
	jp nz,_FinishedInputHandling
	ld a,(SPRITE1_Y)
	sub MoveSpeed
	ld (SPRITE1_Y),a
	
	; Check Top Limit
	cp $18
	jr nc,_FinishedInputHandling
	ld a,$18
	ld (SPRITE1_Y),a
	
_FinishedInputHandling:
	
	; Update Player Paddle Position
	ld a,(SPRITE1_Y)
	sub $08
	ld (SPRITE0_Y),a
	ld a,(SPRITE1_Y)
	add a,$08
	ld (SPRITE2_Y),a

	; Handle CPU Paddle """""AI"""""
_CheckCPUMovementDown:
	ld a,(SPRITE3_Y)
	ld b,a
	ld a,(SPRITE5_Y)
	cp b
	jr nc,_CheckCPUMovementUp
	inc a
	ld (SPRITE5_Y),a
	
	; Check Bottom Limit
	cp LCD_HEIGHT
	jr c, _UpdateCPUPaddlePos
	ld a,LCD_HEIGHT
	ld (SPRITE5_Y),a
	jr _UpdateCPUPaddlePos

_CheckCPUMovementUp:
	ld a,(SPRITE3_Y)
	ld b,a
	ld a,(SPRITE5_Y)
	cp b
	jr c,_UpdateCPUPaddlePos
	dec a
	ld (SPRITE5_Y),a
	
	; Check Top Limit
	cp $18
	jr nc,_UpdateCPUPaddlePos
	ld a,$18
	ld (SPRITE5_Y),a
	
_UpdateCPUPaddlePos:
	; Update CPU Paddle Position
	ld a,(SPRITE5_Y)
	sub $08
	ld (SPRITE4_Y),a
	ld a,(SPRITE5_Y)
	add a,$08
	ld (SPRITE6_Y),a
	
	; Scroll Background
	ld a,(ScrollBackground)
	inc a
	ld (ScrollBackground),a
	cp $05
	jr nz,_PuckXMotion
	ld a,$00
	ld (ScrollBackground),a
	ld hl,SCY
	inc (hl)
	
	; Update Puck Horizontal Motion
_PuckXMotion:
	ld a,(PuckVelX)
	ld b,a
	ld a,(SPRITE3_X)
	add a,b
	ld (SPRITE3_X),a
	
	; Update Puck Vertical Motion
_PuckYMotion:
	ld a,(PuckVelY)
	ld b,a
	ld a,(SPRITE3_Y)
	add a,b
	ld (SPRITE3_Y),a
	
	; Test Collision Right Wall
_PuckTestRightWall:
	ld a,(SPRITE3_X) 	; I know I shouldn't load it twice
						; I just want a more understandable .fsdf
	cp LCD_WIDTH
	jr c,_PuckTestLeftWall
	ld a,LCD_WIDTH
	ld (SPRITE3_X),a
	
	; Lost game
	ld a,-PuckSpeed
	ld (PuckVelX),a
	; TODO: We should increment Player score

	jr _PuckSetToCenter
	
	; Test Collision Left Wall
_PuckTestLeftWall:
	ld a,(SPRITE3_X)
	cp $08
	jr nc,_PuckTestBottomWall
	ld a,$08
	ld (SPRITE3_X),a
	
	; Lost game
	ld a,PuckSpeed
	ld (PuckVelX),a
	; TODO: We should increment CPU score

	jr _PuckSetToCenter
	
	; Test Collision Bottom Wall
_PuckTestBottomWall:
	ld a,(SPRITE3_Y) 	
	cp LCD_HEIGHT+$08
	jr c,_PuckTestTopWall
	ld a,LCD_HEIGHT+$08
	ld (SPRITE3_Y),a
	
	; Bounce Puck
	ld a,-PuckSpeed
	ld (PuckVelY),a
	jr _TestCollision
	
	; Test Collision Top Wall
_PuckTestTopWall:
	ld a,(SPRITE3_Y)
	cp $10
	jr nc,_TestCollision
	ld a,$10
	ld (SPRITE3_Y),a
	
	; Bounce Puck
	ld a,PuckSpeed
	ld (PuckVelY),a
	jr _TestCollision

_PuckSetToCenter:
	ld a,LCD_WIDTH/2
	ld (SPRITE3_X),a
	ld a,LCD_HEIGHT/2+8
	ld (SPRITE3_Y),a
	
	; Check which paddle needs collision test
_TestCollision:
	ld a,(PuckVelX)
	cp -PuckSpeed
	jr nz,_CheckPuckCPUCol
	
	; Check collision between Puck and Player Paddle
_CheckPuckPlayerCol:
	ld a,(SPRITE0_Y)
	ld b,a
	ld a,(SPRITE3_Y)
	add a,$08
	cp b
	jr c,_SkipScrollBackground
	ld a,(SPRITE2_Y)
	ld b,a
	ld a,(SPRITE3_Y)
	sub $08
	cp b
	jr nc,_SkipScrollBackground
	ld a,(SPRITE3_X)
	cp $18
	jr nc,_SkipScrollBackground
	ld a,PuckSpeed
	ld (PuckVelX),a
	
	; Check collision between Puck and CPU Paddle
_CheckPuckCPUCol:
	ld a,(SPRITE4_Y)
	ld b,a
	ld a,(SPRITE3_Y)
	add a,$08
	cp b
	jr c,_SkipScrollBackground
	ld a,(SPRITE6_Y)
	ld b,a
	ld a,(SPRITE3_Y)
	sub $08
	cp b
	jr nc,_SkipScrollBackground
	ld a,(SPRITE3_X)
	cp LCD_WIDTH-$10
	jr c,_SkipScrollBackground
	ld a,-PuckSpeed
	ld (PuckVelX),a
	
_SkipScrollBackground:
	; After Sprite Update
	; push to OAM RAM
	call StartDMA
	jp MainLoop

	; Static Data
TileData:
    DB $3C, $3C, $7E, $7E, $E7, $FF, $DB, $FF, $DB, $FF, $DB, $FF, $DB, $FF, $DB, $FF
    DB $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    DB $00, $18, $00, $18, $00, $18, $00, $18, $00, $18, $00, $18, $00, $18, $00, $18
    DB $3C, $3C, $66, $7E, $DB, $FF, $A5, $FF, $A5, $FF, $DB, $FF, $66, $7E, $3C, $3C
    DB $DB, $FF, $DB, $FF, $DB, $FF, $DB, $FF, $DB, $FF, $DB, $FF, $DB, $FF, $DB, $FF
    DB $DB, $FF, $DB, $FF, $DB, $FF, $DB, $FF, $DB, $FF, $E7, $FF, $7E, $7E, $3C, $3C

	lib Utils
	lib ShadowOAM
	lib Variables
	