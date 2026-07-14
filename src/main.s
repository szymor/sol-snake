.setcpu "6502"

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
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

BOARD_W = 14
BOARD_H = 12
BOARD_SIZE = BOARD_W * BOARD_H

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
tail_index:     .res 1
snake_length:   .res 1
score_lo:       .res 1
score_hi:       .res 1
rng_lo:         .res 1
rng_hi:         .res 1
cell_x:         .res 1
cell_y:         .res 1
board_index:    .res 1
ate_food:       .res 1
render_row:     .res 1
temp:           .res 1
dirty_count:    .res 1
dirty_x:        .res 3
dirty_y:        .res 3
dirty_tile:     .res 3

.segment "BSS"
board:   .res BOARD_SIZE
snake_x: .res BOARD_SIZE
snake_y: .res BOARD_SIZE

.segment "RODATA"
palette:
    .byte $0F, $30, $1A, $16, $0F, $30, $27, $16
    .byte $0F, $30, $1A, $16, $0F, $30, $27, $16
    .byte $0F, $30, $1A, $16, $0F, $30, $27, $16
    .byte $0F, $30, $1A, $16, $0F, $30, $27, $16
title_text: .byte "SOL SNAKE"
title_text_end:
help_text:  .byte "D-PAD MOVES  START PAUSES"
help_text_end:
press_text: .byte "    PRESS START    "
play_text:  .byte "                   "
pause_text: .byte "       PAUSED      "
over_text:  .byte "  GAME OVER START  "
score_text: .byte "SCORE 00000"

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
    lda #$5A
    sta rng_lo
    lda #$A7
    sta rng_hi
    lda #%10000000
    sta PPUCTRL
    lda #%00001010
    sta PPUMASK
MainLoop:
    lda frame
    cmp last_frame
    beq MainLoop
    sta last_frame
    jsr ReadController
    jsr RandomStep
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
    lda buttons_new
    and #%00010000
    beq MainLoop
    jsr NewGame
    jmp MainLoop
.endproc

.proc InitializePpu
    bit PPUSTATUS
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
    lda #$22
    ldx #$E3
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
    ldx #$E8                ; row 7, column 8
    jsr SetPpuAddressAX
    lda #3
    ldx #16
@top:
    sta PPUDATA
    dex
    bne @top
    lda #$22
    ldx #$88                ; row 20, column 8
    jsr SetPpuAddressAX
    lda #3
    ldx #16
@bottom:
    sta PPUDATA
    dex
    bne @bottom
    lda #$21
    sta temp
    lda #$08                ; row 8, column 8
    sta render_row
    ldy #12
@sides:
    lda temp
    ldx render_row
    jsr SetPpuAddressAX
    lda #3
    sta PPUDATA
    lda temp
    ldx render_row
    txa
    clc
    adc #15
    tax
    lda temp
    jsr SetPpuAddressAX
    lda #3
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
    ldx #0
@clear:
    sta board,x
    inx
    cpx #BOARD_SIZE
    bne @clear
    lda #DIR_RIGHT
    sta direction
    sta next_direction
    lda #10
    sta speed
    sta move_timer
    lda #0
    sta tail_index
    sta score_lo
    sta score_hi
    lda #2
    sta head_index
    lda #3
    sta snake_length
    ldx #0
    lda #5
    sta snake_x,x
    lda #6
    sta snake_y,x
    inx
    lda #6
    sta snake_x,x
    lda #6
    sta snake_y,x
    inx
    lda #7
    sta snake_x,x
    lda #6
    sta snake_y,x
    lda #89
    ; The three initial body cells occupy row 6.
    lda #1
    sta board+84+5
    sta board+84+6
    sta board+84+7
    lda #0
    sta dirty_count
    jsr PlaceFood
    lda #0
    sta PPUCTRL
    sta PPUMASK
    jsr RenderBoard
    lda #%10000000
    sta PPUCTRL
    lda #%00001010
    sta PPUMASK
    lda #STATE_PLAY
    sta state
    rts
.endproc

.proc UpdatePlaying
    lda buttons_new
    and #%00010000
    beq @directions
    lda move_timer
    bmi @unpause
    ora #$80
    sta move_timer
    rts
@unpause:
    and #$7F
    sta move_timer
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
    lda next_direction
    sta direction
    ldx head_index
    lda snake_x,x
    sta cell_x
    lda snake_y,x
    sta cell_y
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
    jsr GetBoardIndex
    ldx board_index
    lda board,x
    cmp #2
    bne @not_food
    lda #1
    sta ate_food
    jmp @test_body
@not_food:
    lda #0
    sta ate_food
    ldx tail_index
    lda snake_y,x
    sta cell_y
    ldy dirty_count
    sta dirty_y,y
    lda snake_x,x
    sta cell_x
    sta dirty_x,y
    lda #0
    sta dirty_tile,y
    inc dirty_count
    jsr GetBoardIndex
    ldx board_index
    lda #0
    sta board,x
    inc tail_index
    lda tail_index
    cmp #BOARD_SIZE
    bcc @restore_new
    lda #0
    sta tail_index
@restore_new:
    ldx head_index
    lda snake_x,x
    sta temp
    lda snake_y,x
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
    ldx board_index
    lda board,x
    cmp #1
    beq @collision
    lda #1
    sta board,x
    ldy dirty_count
    lda cell_x
    sta dirty_x,y
    lda cell_y
    sta dirty_y,y
    lda #1
    sta dirty_tile,y
    inc dirty_count
    inc head_index
    lda head_index
    cmp #BOARD_SIZE
    bcc :+
    lda #0
    sta head_index
:
    ldx head_index
    lda cell_x
    sta snake_x,x
    lda cell_y
    sta snake_y,x
    lda ate_food
    beq @done
    inc snake_length
    inc score_lo
    lda score_lo
    and #$0F
    cmp #$0A
    bne @score_carry
    lda score_lo
    clc
    adc #$06
    sta score_lo
@score_carry:
    lda score_lo
    cmp #$A0
    bcc @score_done
    lda #0
    sta score_lo
    inc score_hi
    lda score_hi
    and #$0F
    cmp #$0A
    bne @score_done
    lda score_hi
    clc
    adc #$06
    sta score_hi
@score_done:
    lda snake_length
    and #$0F
    bne :+
    lda speed
    cmp #3
    beq :+
    dec speed
:
    jsr EatSound
    lda snake_length
    cmp #BOARD_SIZE
    beq @collision
    jsr PlaceFood
@done:
    rts
@collision:
    lda #STATE_OVER
    sta state
    jsr CrashSound
    rts
.endproc

.proc GetBoardIndex
    lda #0
    ldx cell_y
@row:
    cpx #0
    beq @column
    clc
    adc #BOARD_W
    dex
    bne @row
@column:
    clc
    adc cell_x
    sta board_index
    rts
.endproc

.proc PlaceFood
@try:
    jsr RandomStep
    lda rng_lo
    and #$0F
    cmp #BOARD_W
    bcs @try
    sta cell_x
    jsr RandomStep
    lda rng_hi
    and #$0F
    cmp #BOARD_H
    bcs @try
    sta cell_y
    jsr GetBoardIndex
    ldx board_index
    lda board,x
    bne @try
    lda #2
    sta board,x
    ldy dirty_count
    lda cell_x
    sta dirty_x,y
    lda cell_y
    sta dirty_y,y
    lda #2
    sta dirty_tile,y
    inc dirty_count
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

.proc EatSound
    lda #%00000001
    sta APUSTATUS
    lda #%10111111
    sta $4000
    lda #$40
    sta $4002
    lda #$08
    sta $4003
    rts
.endproc

.proc CrashSound
    lda #%00001000
    sta APUSTATUS
    lda #%00111111
    sta $400C
    lda #$08
    sta $400E
    lda #$18
    sta $400F
    rts
.endproc

.proc Nmi
    pha
    txa
    pha
    tya
    pha
    jsr RenderStatus
    jsr RenderScore
    jsr RenderDirtyCells
    lda #0
    sta PPUADDR
    sta PPUADDR
    inc frame
    pla
    tay
    pla
    tax
    pla
    rti
.endproc

.proc RenderDirtyCells
    ldy #0
@cell:
    cpy dirty_count
    beq @done
    lda #$21
    sta temp
    lda #$09
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
    lda #'0'
    sta PPUDATA
    rts
.endproc

.proc RenderBoard
    lda #$21
    sta temp
    lda #$09                ; row 8, column 9
    sta render_row
    ldx #0
    ldy #BOARD_H
@row:
    lda temp
    pha
    txa
    pha
    ldx render_row
    jsr SetPpuAddressAX
    pla
    tax
    pla
    lda #BOARD_W
    sta board_index
@cell:
    lda board,x
    sta PPUDATA
    inx
    dec board_index
    bne @cell
    lda render_row
    clc
    adc #32
    sta render_row
    bcc :+
    inc temp
:
    dey
    bne @row
    rts
.endproc

.proc Irq
    rti
.endproc

.segment "CHR"
    .incbin "build/graphics.chr"

.segment "VECTORS"
    .word Nmi, Reset, Irq
