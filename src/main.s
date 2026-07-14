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
dirty_x:        .res 3
dirty_y:        .res 3
dirty_tile:     .res 3
pointer:        .res 2
cell_value:     .res 1
board_nibble:   .res 1

.segment "BSS"
board:   .res BOARD_BYTES
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
    lda #3
    ldx #(BOARD_W+2)
@top:
    sta PPUDATA
    dex
    bne @top
    lda #$23
    ldx #$20                ; row 25, column 0
    jsr SetPpuAddressAX
    lda #3
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
    lda #3
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
    lda #10
    sta speed
    sta move_timer
    lda #0
    sta tail_index
    sta tail_index_hi
    sta score_lo
    sta score_hi
    sta snake_length_hi
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
    lda #1
    sta cell_value
    lda #13
    sta cell_x
    lda #9
    sta cell_y
    jsr GetBoardIndex
    jsr SetBoardCell
    inc cell_x
    jsr GetBoardIndex
    jsr SetBoardCell
    inc cell_x
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
    rts
.endproc

.proc UpdatePlaying
    lda redraw_pending
    bne @done
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
    lda head_index
    ldx head_index_hi
    jsr PointSnakeX
    ldy #0
    lda (pointer),y
    sta cell_x
    lda head_index
    ldx head_index_hi
    jsr PointSnakeY
    ldy #0
    lda (pointer),y
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
    jsr GetBoardCell
    cmp #2
    bne @not_food
    lda #1
    sta ate_food
    jmp @test_body
@not_food:
    lda #0
    sta ate_food
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
    jsr GetBoardCell
    cmp #1
    bne :+
    jmp @collision
:
    lda #1
    sta cell_value
    jsr SetBoardCell
    ldy dirty_count
    lda cell_x
    sta dirty_x,y
    lda cell_y
    sta dirty_y,y
    lda #1
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
    lda ate_food
    beq @done
    inc snake_length
    bne :+
    inc snake_length_hi
:
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
@collision:
    lda #STATE_OVER
    sta state
    jsr ClearBoardDisplay
    jsr CrashSound
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
    lda #2
    sta cell_value
    jsr SetBoardCell
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

.proc Irq
    rti
.endproc

.segment "CHR"
    .incbin "build/graphics.chr"

.segment "VECTORS"
    .word Nmi, Reset, Irq
