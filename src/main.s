.setcpu "6502"

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUADDR   = $2006
PPUDATA   = $2007
APUSTATUS = $4015
JOY1      = $4016

STATE_TITLE = 0
STATE_PLAY  = 1
STATE_OVER  = 2

DIR_UP    = 0
DIR_RIGHT = 1
DIR_DOWN  = 2
DIR_LEFT  = 3

BOARD_W = 30
BOARD_H = 18
BOARD_SIZE = BOARD_W * BOARD_H
BOARD_BYTES = (BOARD_SIZE + 1) / 2

.segment "HEADER"
    .byte "NES", $1A
    .byte 2, 1                 ; 32 KiB PRG, 8 KiB CHR
    .byte $00, $00             ; mapper 0, horizontal mirroring
    .res 8, $00

.segment "ZEROPAGE"
frame:          .res 1
last_frame:     .res 1
state:          .res 1
buttons:        .res 1
buttons_old:    .res 1
buttons_new:    .res 1
direction:      .res 1
next_direction: .res 1
move_timer:     .res 1
speed:          .res 1
head_index:     .res 1
head_index_hi:  .res 1
tail_index:     .res 1
tail_index_hi:  .res 1
snake_length:   .res 1
snake_length_hi:.res 1
score_lo:       .res 1
score_hi:       .res 1
score_top:      .res 1
rng_lo:         .res 1
rng_hi:         .res 1
cell_x:         .res 1
cell_y:         .res 1
board_index:    .res 1
board_index_hi: .res 1
ate_food:       .res 1
render_row:     .res 1
temp:           .res 1
dirty_count:    .res 1
redraw_pending: .res 1
dirty_x:        .res 4
dirty_y:        .res 4
dirty_tile:     .res 4
pointer:        .res 2
cell_value:     .res 1
board_nibble:   .res 1
old_head_x:     .res 1
old_head_y:     .res 1
old_direction:  .res 1
food_x:         .res 1
food_y:         .res 1
food_animation: .res 1
music_mode:     .res 1
music_step:     .res 1
music_timer:    .res 1
food_count:     .res 1
bonus_count:    .res 1
snake_color:    .res 1
bonus_active:   .res 1
bonus_x:        .res 1
bonus_y:        .res 1
bonus_timer:    .res 1
score_add_lo:   .res 1
score_add_hi:   .res 1

.segment "BSS"
board:   .res BOARD_BYTES
snake_x: .res BOARD_SIZE
snake_y: .res BOARD_SIZE

.segment "RODATA"
palette:
    .byte $0F, $30, $1A, $16, $0F, $30, $27, $16
    .byte $0F, $30, $1A, $16, $0F, $30, $27, $16
    .byte $0F, $30, $1A, $16, $0F, $16, $27, $16
    .byte $0F, $30, $1A, $16, $0F, $30, $27, $16
title_text: .byte "SOL SNAKE"
title_text_end:
help_text:  .byte "D-PAD MOVES  START PAUSES"
help_text_end:
press_text: .byte "    PRESS START    "
play_text:  .byte "                   "
pause_text: .byte "       PAUSED      "
over_text:  .byte "     GAME OVER     "
score_text: .byte "SCORE 00000"

; Note IDs index NTSC APU timer periods. Zero is a rest.
note_lo: .byte $00, $AE, $FF, $73, $F7, $AA, $7B, $52, $3F, $1C, $FD, $D4
note_hi: .byte $00, $06, $04, $04, $03, $01, $01, $01, $01, $01, $00, $00
title_melody:
    .byte 5, 7, 9, 11, 9, 7, 5, 0, 6, 8, 10, 9, 8, 6, 5, 0
    .byte 5, 8, 7, 10, 9, 11, 9, 7, 6, 8, 7, 6, 5, 0, 5, 0
game_melody:
    .byte 5, 0, 7, 8, 0, 7, 5, 0, 6, 0, 8, 9, 0, 8, 6, 0
    .byte 5, 7, 0, 8, 9, 0, 7, 0, 6, 8, 0, 7, 5, 0, 0, 0
    .byte 7, 0, 8, 10, 0, 9, 8, 0, 6, 0, 8, 9, 0, 7, 6, 0
    .byte 5, 0, 8, 7, 0, 6, 5, 0, 7, 9, 0, 8, 6, 0, 5, 0
; Indexed by incoming direction * 4 + outgoing direction.
corner_tiles:
    .byte 0, 2, 0, 4        ; up -> right/left connects from below
    .byte 14, 0, 4, 0       ; right -> up/down connects from left
    .byte 0, 3, 0, 14       ; down -> right/left connects from above
    .byte 3, 0, 2, 0        ; left -> up/down connects from right
snake_colors:
    .byte $1A, $2A, $27, $28, $25, $2C, $21, $30

.segment "CODE"
.proc Reset
    sei
    cld
    ldx #$40
    stx $4017
    ldx #$FF
    txs
    inx
    stx PPUCTRL
    stx PPUMASK
    stx $4010
    bit PPUSTATUS
@wait1:
    bit PPUSTATUS
    bpl @wait1
    txa
@clear:
    sta $0000,x
    sta $0100,x
    sta $0200,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne @clear
@wait2:
    bit PPUSTATUS
    bpl @wait2
    jsr InitializePpu
    lda #STATE_TITLE
    sta state
    jsr StartTitleMusic
    lda #$5A
    sta rng_lo
    lda #$A7
    sta rng_hi
    lda #%10000000
    sta PPUCTRL
    lda #%00011010
    sta PPUMASK
MainLoop:
    lda frame
    cmp last_frame
    beq MainLoop
    sta last_frame
    jsr ReadController
    jsr RandomStep
    jsr UpdateMusic
    lda state
    beq UpdateTitle
    cmp #STATE_OVER
    beq UpdateOver
    jsr UpdatePlaying
    jmp MainLoop
UpdateTitle:
    lda buttons_new
    and #%00010000
    beq MainLoop
    jsr NewGame
    jmp MainLoop
UpdateOver:
    lda redraw_pending
    bne MainLoop
    lda buttons_new
    and #%00010000
    beq MainLoop
    jsr NewGame
    jmp MainLoop
.endproc

.proc InitializePpu
    bit PPUSTATUS
    lda #0
    sta OAMADDR
    ldx #64
@hide_sprites:
    lda #$FF
    sta OAMDATA
    lda #0
    sta OAMDATA
    sta OAMDATA
    sta OAMDATA
    dex
    bne @hide_sprites
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #0
@palette:
    lda palette,x
    sta PPUDATA
    inx
    cpx #32
    bne @palette
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #0
    ldx #4
@page:
    ldy #0
@byte:
    sta PPUDATA
    iny
    bne @byte
    dex
    bne @page
    lda #$20
    ldx #$43
    jsr SetPpuAddressAX
    ldx #0
@title:
    lda title_text,x
    sta PPUDATA
    inx
    cpx #(title_text_end-title_text)
    bne @title
    lda #$23
    ldx #$63                ; row 27, column 3
    jsr SetPpuAddressAX
    ldx #0
@help:
    lda help_text,x
    sta PPUDATA
    inx
    cpx #(help_text_end-help_text)
    bne @help
    jsr DrawBorder
    rts
.endproc

.proc SetPpuAddressAX
    bit PPUSTATUS
    sta PPUADDR
    stx PPUADDR
    rts
.endproc

.proc DrawBorder
    lda #$20
    ldx #$C0                ; row 6, column 0
    jsr SetPpuAddressAX
    lda #15
    ldx #(BOARD_W+2)
@top:
    sta PPUDATA
    dex
    bne @top
    lda #$23
    ldx #$20                ; row 25, column 0
    jsr SetPpuAddressAX
    lda #15
    ldx #(BOARD_W+2)
@bottom:
    sta PPUDATA
    dex
    bne @bottom
    lda #$20
    sta temp
    lda #$E0                ; row 7, column 0
    sta render_row
    ldy #BOARD_H
@sides:
    lda temp
    ldx render_row
    jsr SetPpuAddressAX
    lda #15
    sta PPUDATA
    lda temp
    ldx render_row
    txa
    clc
    adc #(BOARD_W+1)
    tax
    lda temp
    adc #0
    jsr SetPpuAddressAX
    lda #15
    sta PPUDATA
    lda render_row
    clc
    adc #32
    sta render_row
    bcc :+
    inc temp
:
    dey
    bne @sides
    rts
.endproc

.proc ReadController
    lda buttons
    sta buttons_old
    lda #1
    sta JOY1
    lda #0
    sta JOY1
    ldx #8
    lda #0
    sta buttons
@loop:
    lda JOY1
    lsr a
    rol buttons
    dex
    bne @loop
    lda buttons_old
    eor #$FF
    and buttons
    sta buttons_new
    rts
.endproc

.proc NewGame
    lda #0
    sta pointer
    lda #>board
    sta pointer+1
    ldx #<board
    stx pointer
    lda #0
    ldy #0
    ldx #>BOARD_BYTES
@clear:
    sta (pointer),y
    iny
    bne @clear
    inc pointer+1
    dex
    bne @clear
    ldx #<BOARD_BYTES
    beq @cleared
@remainder:
    sta (pointer),y
    iny
    dex
    bne @remainder
@cleared:
    lda #DIR_RIGHT
    sta direction
    sta next_direction
    sta old_direction
    lda #10
    sta speed
    sta move_timer
    lda #0
    sta tail_index
    sta tail_index_hi
    sta score_lo
    sta score_hi
    sta score_top
    sta food_count
    sta bonus_count
    sta bonus_active
    sta snake_length_hi
    lda snake_colors
    sta snake_color
    lda #2
    sta head_index
    lda #0
    sta head_index_hi
    lda #3
    sta snake_length
    ldx #0
    lda #13
    sta snake_x,x
    lda #9
    sta snake_y,x
    inx
    lda #14
    sta snake_x,x
    lda #9
    sta snake_y,x
    inx
    lda #15
    sta snake_x,x
    lda #9
    sta snake_y,x
    lda #13                 ; horizontal body
    sta cell_value
    lda #13
    sta cell_x
    lda #9
    sta cell_y
    jsr GetBoardIndex
    jsr SetBoardCell
    inc cell_x
    jsr GetBoardIndex
    lda #13
    sta cell_value
    jsr SetBoardCell
    inc cell_x
    jsr GetBoardIndex
    lda #(5+DIR_RIGHT)
    sta cell_value
    jsr SetBoardCell
    lda #13
    sta cell_x
    lda #(9+DIR_LEFT)
    sta cell_value
    jsr GetBoardIndex
    jsr SetBoardCell
    lda #0
    sta dirty_count
    jsr PlaceFood
    lda #0
    sta dirty_count
    lda #BOARD_H
    sta redraw_pending
    lda #STATE_PLAY
    sta state
    jsr StartGameMusic
    rts
.endproc

.proc UpdatePlaying
    lda redraw_pending
    bne @done
    jsr UpdateBonus
    lda buttons_new
    and #%00010000
    beq @directions
    lda move_timer
    bmi @unpause
    ora #$80
    sta move_timer
    jsr PauseMusic
    rts
@unpause:
    and #$7F
    sta move_timer
    jsr ResumeMusic
    rts
@directions:
    lda move_timer
    bmi @done
    lda buttons
    and #%00001000
    beq @not_up
    lda direction
    cmp #DIR_DOWN
    beq @not_up
    lda #DIR_UP
    sta next_direction
@not_up:
    lda buttons
    and #%00000100
    beq @not_down
    lda direction
    cmp #DIR_UP
    beq @not_down
    lda #DIR_DOWN
    sta next_direction
@not_down:
    lda buttons
    and #%00000010
    beq @not_left
    lda direction
    cmp #DIR_RIGHT
    beq @not_left
    lda #DIR_LEFT
    sta next_direction
@not_left:
    lda buttons
    and #%00000001
    beq @tick
    lda direction
    cmp #DIR_LEFT
    beq @tick
    lda #DIR_RIGHT
    sta next_direction
@tick:
    dec move_timer
    bne @done
    lda speed
    sta move_timer
    jsr MoveSnake
@done:
    rts
.endproc

.proc MoveSnake
    lda direction
    sta old_direction
    lda next_direction
    sta direction
    lda head_index
    ldx head_index_hi
    jsr PointSnakeX
    ldy #0
    lda (pointer),y
    sta cell_x
    sta old_head_x
    lda head_index
    ldx head_index_hi
    jsr PointSnakeY
    ldy #0
    lda (pointer),y
    sta cell_y
    sta old_head_y
    lda direction
    cmp #DIR_UP
    bne @right
    dec cell_y
    jmp @bounds
@right:
    cmp #DIR_RIGHT
    bne @down
    inc cell_x
    jmp @bounds
@down:
    cmp #DIR_DOWN
    bne @left
    inc cell_y
    jmp @bounds
@left:
    dec cell_x
@bounds:
    lda cell_x
    cmp #BOARD_W
    bcc :+
    jmp @collision
:
    lda cell_y
    cmp #BOARD_H
    bcc :+
    jmp @collision
:
    lda cell_x
    ldx bonus_active
    beq @regular_food
    cmp bonus_x
    bne @regular_food
    lda cell_y
    cmp bonus_y
    bne @regular_food
    lda #2
    sta ate_food
    lda #0
    sta bonus_active
    jmp @not_food_tail
@regular_food:
    lda cell_x
    cmp food_x
    bne @not_food
    lda cell_y
    cmp food_y
    bne @not_food
    lda #1
    sta ate_food
    jmp @test_body
@not_food:
    lda #0
    sta ate_food
@not_food_tail:
    lda tail_index
    ldx tail_index_hi
    jsr PointSnakeY
    ldy #0
    lda (pointer),y
    sta cell_y
    ldy dirty_count
    sta dirty_y,y
    lda tail_index
    ldx tail_index_hi
    jsr PointSnakeX
    ldy #0
    lda (pointer),y
    sta cell_x
    sta dirty_x,y
    lda #0
    sta dirty_tile,y
    inc dirty_count
    jsr GetBoardIndex
    lda #0
    sta cell_value
    jsr SetBoardCell
    jsr IncrementTail
    jsr UpdateTailTip
@restore_new:
    lda head_index
    ldx head_index_hi
    jsr PointSnakeX
    ldy #0
    lda (pointer),y
    sta temp
    lda head_index
    ldx head_index_hi
    jsr PointSnakeY
    ldy #0
    lda (pointer),y
    pha
    lda cell_x
    ; cell coordinates currently contain the removed tail, restore new head below.
    lda temp
    sta cell_x
    pla
    sta cell_y
    lda direction
    cmp #DIR_UP
    bne :+
    dec cell_y
    jmp @new_index
:
    cmp #DIR_RIGHT
    bne :+
    inc cell_x
    jmp @new_index
:
    cmp #DIR_DOWN
    bne :+
    inc cell_y
    jmp @new_index
:
    dec cell_x
@new_index:
    jsr GetBoardIndex
@test_body:
    jsr GetBoardIndex
    jsr GetBoardCell
    beq @free
    jmp @collision
@free:
    lda direction
    clc
    adc #5
    sta cell_value
    jsr SetBoardCell
    ldy dirty_count
    lda cell_x
    sta dirty_x,y
    lda cell_y
    sta dirty_y,y
    lda direction
    clc
    adc #5
    sta dirty_tile,y
    inc dirty_count
    jsr IncrementHead
    lda head_index
    ldx head_index_hi
    jsr PointSnakeX
    ldy #0
    lda cell_x
    sta (pointer),y
    lda head_index
    ldx head_index_hi
    jsr PointSnakeY
    ldy #0
    lda cell_y
    sta (pointer),y
    lda old_head_x
    sta cell_x
    lda old_head_y
    sta cell_y
    jsr GetBoardIndex
    jsr GetBodyTile
    sta cell_value
    jsr SetBoardCell
    ldy dirty_count
    lda cell_x
    sta dirty_x,y
    lda cell_y
    sta dirty_y,y
    lda cell_value
    sta dirty_tile,y
    inc dirty_count
    lda ate_food
    cmp #1
    beq @regular_score
    cmp #2
    beq @bonus_score
    rts
@regular_score:
    inc snake_length
    bne :+
    inc snake_length_hi
:
    inc food_count
    inc bonus_count
    lda food_count
    and #$0F
    bne :+
    lda food_count
    lsr a
    lsr a
    lsr a
    lsr a
    and #7
    tax
    lda snake_colors,x
    sta snake_color
:
    lda #10
    sta score_add_lo
    lda #0
    sta score_add_hi
    jsr AddPoints
    lda snake_length
    and #$0F
    bne :+
    lda speed
    cmp #3
    beq :+
    dec speed
:
    jsr EatSound
    lda bonus_count
    cmp #5
    bcc :+
    lda #0
    sta bonus_count
    lda bonus_active
    bne :+
    jsr PlaceBonus
:
    lda snake_length_hi
    cmp #>BOARD_SIZE
    bne :+
    lda snake_length
    cmp #<BOARD_SIZE
    beq @collision
:
    jsr PlaceFood
@done:
    rts
@bonus_score:
    lda snake_length
    sta score_add_lo
    lda snake_length_hi
    sta score_add_hi
    jsr AddPoints
    jsr EatSound
    rts
@collision:
    lda #STATE_OVER
    sta state
    jsr StopMusic
    jsr ClearBoardDisplay
    jsr CrashSound
    rts
.endproc

.proc GetBodyTile
    lda old_direction
    cmp direction
    bne @corner
    lda direction
    and #1
    beq @vertical
    lda #13                 ; horizontal
    rts
@vertical:
    lda #1
    rts
@corner:
    lda old_direction
    asl a
    asl a
    ora direction
    tax
    lda corner_tiles,x
    rts
.endproc

.proc UpdateTailTip
    lda tail_index
    ldx tail_index_hi
    jsr PointSnakeX
    ldy #0
    lda (pointer),y
    sta cell_x
    lda tail_index
    ldx tail_index_hi
    jsr PointSnakeY
    ldy #0
    lda (pointer),y
    sta cell_y

    lda tail_index
    sta board_index
    lda tail_index_hi
    sta board_index_hi
    inc board_index
    bne :+
    inc board_index_hi
:
    lda board_index_hi
    cmp #>BOARD_SIZE
    bne @next
    lda board_index
    cmp #<BOARD_SIZE
    bne @next
    lda #0
    sta board_index
    sta board_index_hi
@next:
    lda board_index
    ldx board_index_hi
    jsr PointSnakeX
    ldy #0
    lda (pointer),y
    cmp cell_x
    beq @vertical
    bcc @points_right
    lda #12                 ; body is right, tail points left
    bne @set
@points_right:
    lda #10
    bne @set
@vertical:
    lda board_index
    ldx board_index_hi
    jsr PointSnakeY
    ldy #0
    lda (pointer),y
    cmp cell_y
    bcc @points_down
    lda #9                  ; body is below, tail points up
    bne @set
@points_down:
    lda #11
@set:
    sta cell_value
    jsr GetBoardIndex
    jsr SetBoardCell
    ldy dirty_count
    lda cell_x
    sta dirty_x,y
    lda cell_y
    sta dirty_y,y
    lda cell_value
    sta dirty_tile,y
    inc dirty_count
    rts
.endproc

.proc ClearBoardDisplay
    lda #<board
    sta pointer
    lda #>board
    sta pointer+1
    lda #0
    ldy #0
    ldx #>BOARD_BYTES
@clear:
    sta (pointer),y
    iny
    bne @clear
    inc pointer+1
    dex
    bne @clear
    ldx #<BOARD_BYTES
    beq @cleared
@remainder:
    sta (pointer),y
    iny
    dex
    bne @remainder
@cleared:
    sta dirty_count
    lda #BOARD_H
    sta redraw_pending
    rts
.endproc

.proc GetBoardIndex
    lda #0
    sta board_index
    sta board_index_hi
    ldx cell_y
@row:
    cpx #0
    beq @column
    lda board_index
    clc
    adc #BOARD_W
    sta board_index
    bcc :+
    inc board_index_hi
:
    dex
    bne @row
@column:
    lda board_index
    clc
    adc cell_x
    sta board_index
    bcc :+
    inc board_index_hi
:
    rts
.endproc

.proc PointBoard
    lda board_index
    and #1
    sta board_nibble
    lda board_index_hi
    lsr a
    sta pointer+1
    lda board_index
    ror a
    clc
    adc #<board
    sta pointer
    lda pointer+1
    adc #>board
    sta pointer+1
    rts
.endproc

.proc GetBoardCell
    jsr PointBoard
    ldy #0
    lda (pointer),y
    ldx board_nibble
    beq :+
    lsr a
    lsr a
    lsr a
    lsr a
:
    and #$0F
    rts
.endproc

.proc SetBoardCell
    jsr PointBoard
    ldy #0
    lda (pointer),y
    ldx board_nibble
    bne @high
    and #$F0
    ora cell_value
    sta (pointer),y
    rts
@high:
    and #$0F
    sta temp
    lda cell_value
    asl a
    asl a
    asl a
    asl a
    ora temp
    sta (pointer),y
    rts
.endproc

.proc PointSnakeX
    clc
    adc #<snake_x
    sta pointer
    txa
    adc #>snake_x
    sta pointer+1
    rts
.endproc

.proc PointSnakeY
    clc
    adc #<snake_y
    sta pointer
    txa
    adc #>snake_y
    sta pointer+1
    rts
.endproc

.proc IncrementHead
    inc head_index
    bne :+
    inc head_index_hi
:
    lda head_index_hi
    cmp #>BOARD_SIZE
    bne @done
    lda head_index
    cmp #<BOARD_SIZE
    bne @done
    lda #0
    sta head_index
    sta head_index_hi
@done:
    rts
.endproc

.proc IncrementTail
    inc tail_index
    bne :+
    inc tail_index_hi
:
    lda tail_index_hi
    cmp #>BOARD_SIZE
    bne @done
    lda tail_index
    cmp #<BOARD_SIZE
    bne @done
    lda #0
    sta tail_index
    sta tail_index_hi
@done:
    rts
.endproc

.proc PlaceFood
@try:
    jsr RandomStep
    lda rng_lo
    and #$1F
    cmp #BOARD_W
    bcs @try
    sta cell_x
    jsr RandomStep
    lda rng_hi
    and #$1F
    cmp #BOARD_H
    bcs @try
    sta cell_y
    jsr GetBoardIndex
    jsr GetBoardCell
    bne @try
    lda cell_x
    sta food_x
    lda cell_y
    sta food_y
    jsr RandomStep
    lda rng_lo
    and #$1C
    sta food_animation
    rts
.endproc

.proc PlaceBonus
@try:
    jsr RandomStep
    lda rng_lo
    and #$1F
    cmp #BOARD_W
    bcs @try
    sta cell_x
    jsr RandomStep
    lda rng_hi
    and #$1F
    cmp #BOARD_H
    bcs @try
    sta cell_y
    cmp food_y
    bne @board
    lda cell_x
    cmp food_x
    beq @try
@board:
    jsr GetBoardIndex
    jsr GetBoardCell
    bne @try
    lda cell_x
    sta bonus_x
    lda cell_y
    sta bonus_y
    lda #240                ; about four seconds at 60 Hz
    sta bonus_timer
    lda #1
    sta bonus_active
    rts
.endproc

.proc UpdateBonus
    lda bonus_active
    beq @done
    dec bonus_timer
    bne @done
    lda #0
    sta bonus_active
@done:
    rts
.endproc

.proc AddPoints
@point:
    lda score_add_lo
    ora score_add_hi
    beq @done
    lda score_add_lo
    bne :+
    dec score_add_hi
:
    dec score_add_lo
    inc score_lo
    lda score_lo
    and #$0F
    cmp #$0A
    bne @carry_byte
    lda score_lo
    clc
    adc #$06
    sta score_lo
@carry_byte:
    lda score_lo
    cmp #$A0
    bcc @point
    lda #0
    sta score_lo
    inc score_hi
    lda score_hi
    and #$0F
    cmp #$0A
    bne @carry_high
    lda score_hi
    clc
    adc #$06
    sta score_hi
@carry_high:
    lda score_hi
    cmp #$A0
    bcc @point
    lda #0
    sta score_hi
    inc score_top
    lda score_top
    cmp #10
    bcc @point
    lda #9
    sta score_top
    lda #$99
    sta score_hi
    sta score_lo
    lda #0
    sta score_add_lo
    sta score_add_hi
@done:
    rts
.endproc

.proc RandomStep
    lda rng_lo
    asl a
    rol rng_hi
    bcc :+
    eor #$2D
    sta rng_lo
    lda rng_hi
    eor #$A1
    sta rng_hi
:
    inc rng_lo
    rts
.endproc

.proc StartTitleMusic
    lda #1
    sta music_mode
    lda #0
    sta music_step
    sta music_timer
    lda #%00000010
    sta APUSTATUS
    rts
.endproc

.proc StartGameMusic
    lda #2
    sta music_mode
    lda #0
    sta music_step
    sta music_timer
    lda #%00000010
    sta APUSTATUS
    rts
.endproc

.proc PauseMusic
    lda #3
    sta music_mode
    lda #0
    sta APUSTATUS
    rts
.endproc

.proc ResumeMusic
    lda #2
    sta music_mode
    lda #0
    sta music_timer
    lda #%00000010
    sta APUSTATUS
    rts
.endproc

.proc StopMusic
    lda #0
    sta music_mode
    sta APUSTATUS
    rts
.endproc

.proc UpdateMusic
    lda music_mode
    beq @done
    cmp #3
    beq @done
    lda music_timer
    beq @next
    dec music_timer
    rts
@next:
    ldx music_step
    lda music_mode
    cmp #1
    bne @game
    lda title_melody,x
    jsr PlayPulse2Note
    lda #12
    bne @tempo
@game:
    lda game_melody,x
    jsr PlayPulse2Note
    lda #14
@tempo:
    sta music_timer
    inc music_step
    lda music_step
    ldx music_mode
    cpx #1
    bne @game_length
    and #$1F
    beq @store_step
@game_length:
    and #$3F
@store_step:
    sta music_step
@done:
    rts
.endproc

.proc PlayPulse2Note
    tax
    bne @note
    lda #%10110000
    sta $4004
    rts
@note:
    lda #%01110100          ; duty 1, sustained, constant volume 4
    sta $4004
    lda note_lo,x
    sta $4006
    lda note_hi,x
    ora #$F8
    sta $4007
    rts
.endproc

.proc EatSound
    lda #%00000011
    sta APUSTATUS
    lda #%10001111          ; duty 2, finite length, constant volume 15
    sta $4000
    lda #$40
    sta $4002
    lda #$18                ; two-frame length counter
    sta $4003
    rts
.endproc

.proc CrashSound
    lda #%00001000
    sta APUSTATUS
    lda #%00011111          ; finite length, constant volume 15
    sta $400C
    lda #$08
    sta $400E
    lda #$38                ; six-frame length counter
    sta $400F
    rts
.endproc

.proc Nmi
    pha
    txa
    pha
    tya
    pha
    lda pointer
    pha
    lda pointer+1
    pha
    lda board_index
    pha
    lda board_index_hi
    pha
    lda temp
    pha
    lda render_row
    pha
    lda board_nibble
    pha
    jsr RenderSnakePalette
    jsr RenderFoodSprite
    jsr RenderBonusSprite
    jsr RenderStatus
    jsr RenderScore
    lda redraw_pending
    beq @dirty
    jsr RenderBoardRow
    jmp @rendered
@dirty:
    jsr RenderDirtyCells
@rendered:
    lda #0
    sta PPUADDR
    sta PPUADDR
    inc frame
    pla
    sta board_nibble
    pla
    sta render_row
    pla
    sta temp
    pla
    sta board_index_hi
    pla
    sta board_index
    pla
    sta pointer+1
    pla
    sta pointer
    pla
    tay
    pla
    tax
    pla
    rti
.endproc

.proc RenderSnakePalette
    lda #$3F
    ldx #$02
    jsr SetPpuAddressAX
    lda snake_color
    sta PPUDATA
    rts
.endproc

.proc RenderFoodSprite
    lda #0
    sta OAMADDR
    lda state
    cmp #STATE_PLAY
    bne @hidden
    lda food_y
    asl a
    asl a
    asl a
    clc
    adc #55                 ; board row 7 starts at pixel 56; OAM Y is minus one
    sta OAMDATA
    lda frame
    lsr a
    lsr a
    lsr a
    and #3
    clc
    adc food_animation
    adc #128
    sta OAMDATA
    lda #0                  ; regular food uses white sprite palette 0
    sta OAMDATA
    lda food_x
    asl a
    asl a
    asl a
    clc
    adc #8                  ; board column 1 starts at pixel 8
    sta OAMDATA
    rts
@hidden:
    lda #$FF
    sta OAMDATA
    lda #16
    sta OAMDATA
    lda #0
    sta OAMDATA
    sta OAMDATA
    rts
.endproc

.proc RenderBonusSprite
    lda #4
    sta OAMADDR
    lda state
    cmp #STATE_PLAY
    bne @hidden
    lda bonus_active
    beq @hidden
    lda bonus_timer
    cmp #60
    bcs @visible
    and #8
    beq @hidden
@visible:
    lda bonus_y
    asl a
    asl a
    asl a
    clc
    adc #55
    sta OAMDATA
    lda frame
    lsr a
    lsr a
    lsr a
    and #3
    clc
    adc #128
    sta OAMDATA
    lda #1                  ; sprite palette 1 uses bright red
    sta OAMDATA
    lda bonus_x
    asl a
    asl a
    asl a
    clc
    adc #8
    sta OAMDATA
    rts
@hidden:
    lda #$FF
    sta OAMDATA
    lda #128
    sta OAMDATA
    lda #0
    sta OAMDATA
    sta OAMDATA
    rts
.endproc

.proc RenderBoardRow
    lda #BOARD_H
    sec
    sbc redraw_pending
    sta render_row
    lda #0
    ldx render_row
@board_address:
    cpx #0
    beq @board_address_done
    clc
    adc #(BOARD_W/2)
    dex
    bne @board_address
@board_address_done:
    clc
    adc #<board
    sta pointer
    lda #>board
    adc #0
    sta pointer+1
    lda #$20
    sta temp
    lda #$E1                ; row 7, column 1
    ldx render_row
@ppu_address:
    cpx #0
    beq @write
    clc
    adc #32
    bcc :+
    inc temp
:
    dex
    bne @ppu_address
@write:
    tax
    lda temp
    jsr SetPpuAddressAX
    ldy #0
    ldx #(BOARD_W/2)
@tile:
    lda (pointer),y
    pha
    and #$0F
    sta PPUDATA
    pla
    lsr a
    lsr a
    lsr a
    lsr a
    sta PPUDATA
    iny
    dex
    bne @tile
    dec redraw_pending
    rts
.endproc

.proc RenderDirtyCells
    ldy #0
@cell:
    cpy dirty_count
    beq @done
    lda #$20
    sta temp
    lda #$E1
    clc
    adc dirty_x,y
    ldx dirty_y,y
@row:
    cpx #0
    beq @address
    clc
    adc #32
    bcc :+
    inc temp
:
    dex
    bne @row
@address:
    tax
    lda temp
    jsr SetPpuAddressAX
    lda dirty_tile,y
    sta PPUDATA
    iny
    bne @cell
@done:
    lda #0
    sta dirty_count
    rts
.endproc

.proc RenderStatus
    lda #$20
    ldx #$A6                ; row 5, column 6
    jsr SetPpuAddressAX
    lda state
    beq @title
    cmp #STATE_OVER
    beq @over
    lda move_timer
    bmi @paused
    ldx #0
@play_loop:
    lda play_text,x
    sta PPUDATA
    inx
    cpx #19
    bne @play_loop
    rts
@title:
    ldx #0
@title_loop:
    lda press_text,x
    sta PPUDATA
    inx
    cpx #19
    bne @title_loop
    rts
@paused:
    ldx #0
@pause_loop:
    lda pause_text,x
    sta PPUDATA
    inx
    cpx #19
    bne @pause_loop
    rts
@over:
    ldx #0
@over_loop:
    lda over_text,x
    sta PPUDATA
    inx
    cpx #19
    bne @over_loop
    rts
.endproc

.proc RenderScore
    lda #$20
    ldx #$69                ; row 3, column 9
    jsr SetPpuAddressAX
    ldx #0
@label:
    lda score_text,x
    sta PPUDATA
    inx
    cpx #6
    bne @label
    lda score_top
    ora #'0'
    sta PPUDATA
    lda score_hi
    lsr a
    lsr a
    lsr a
    lsr a
    ora #'0'
    sta PPUDATA
    lda score_hi
    and #$0F
    ora #'0'
    sta PPUDATA
    lda score_lo
    lsr a
    lsr a
    lsr a
    lsr a
    ora #'0'
    sta PPUDATA
    lda score_lo
    and #$0F
    ora #'0'
    sta PPUDATA
    rts
.endproc

.proc Irq
    rti
.endproc

.segment "CHR"
    .incbin "build/graphics.chr"

.segment "VECTORS"
    .word Nmi, Reset, Irq
