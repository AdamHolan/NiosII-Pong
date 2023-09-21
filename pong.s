    .equ    SCREENBUFFER,   0x09000000
    .equ    PIXELBUFFER,    0x08000000      # only vsync should touch this
    .equ    PIXELS,         8192
    .equ    BALL_SIZE,      3
    .equ    SCREEN_W,       128
    .equ    SCREEN_H,       96
	.equ    PADDLE_LENGTH,  14
    .equ    WAIT_LENGTH,    50000
    .equ    BOARD_OFFSET,   1
    
    .text
	.global	_start
	.org	0
#=======================================
# r3 = Colour
# r4 = loop N
# r5 = Screenbuffer location pointer
#========================================
_start:
	movia 	sp, 0x7FFFFC
    movia   r3, 0x00
	movia 	r5, SCREENBUFFER
    movia   r9, 40               # ball position x
    movia   r10, 30              # ball position y
    movia   r11, 1              # ball change_x
    movia   r12, 1              # ball change_y
    movia   r13, 80-BALL_SIZE
    movia   r14, 60-BALL_SIZE


init_variables:
    call ClearScreen
    stw     r3, COLOUR(r0)
    stw     r5, PIXEL_LOCATION(r0)
    stw     r0, PIXEL_X(r0)
    stw     r0, PIXEL_Y(r0)
    stw     r9,  BALL_X(r0)
    stw     r10, BALL_Y(r0)
    stw     r11, BALL_CHANGE_X(r0)
    stw     r12, BALL_CHANGE_Y(r0)
    stw     r0, RECT_W(r0)
    stw     r0, RECT_H(r0)    
    stw     r10, P1_Y(r0)
    stw     r0, P1_CHANGE_Y(r0)
    stw     r0, P2_Y(r0)
    stw     r0, P2_CHANGE_Y(r0)
    stw     r0, RESET_FLAG(r0)

main:
    ldw    r3, RESET_FLAG(r0)
    bgt    r3, r0, init_variables
    # this clears the previous screen efficiently by only clearing drawn areas
    movia  r3, 0x00
    stw    r3, COLOUR(r0) 
    call drawBall
    call drawP1
    call drawP2
    # after cleared, new calculations can begin
    call GetJTAG
    call HandleInput
    call CheckCollisions
    call GameLoop
    movia   r3, 0xff
    stw     r3, COLOUR(r0)
    call drawBall
    call drawP1
    call drawP2
    call vsync
    call wait

    br main

# one iteration of game calculations
# handle input?
# move ball
# move paddles

HandleInput:
    subi    sp, sp, 4
    stw     r3, 0(sp)
hi_check_up:
    movia   r3, 0x77
    beq     r2, r3, hi_move_up
    br hi_check_down
hi_move_up:
    movia   r3, -1
    stw     r3, P1_CHANGE_Y(r0)
    br hi_clear_stack
hi_check_down:
    movia   r3, 0x73
    beq     r2, r3, hi_move_down
    br hi_clear_stack
hi_move_down:
    movia   r3, 1
    stw     r3, P1_CHANGE_Y(r0)
hi_clear_stack:
    ldw     r3, 0(sp)
    addi    sp, sp, 4

GameLoop:
gl_init_stack:
    subi    sp, sp, 44
    stw     ra, 0(sp)
    stw     r3, 4(sp)
    stw     r4, 8(sp)
    stw     r5, 12(sp)
    stw     r6, 16(sp)
    stw     r7, 20(sp)
    stw     r8, 24(sp)
    stw     r9,  28(sp)
    stw     r10, 32(sp)
    stw     r11, 36(sp)
    stw     r12, 40(sp)

gl_init_registers:
    ldw     r3, BALL_X(r0)               # position change x
    ldw     r4, BALL_Y(r0)               # position change y
    ldw     r5, BALL_CHANGE_X(r0)                       # ball change_x
    ldw     r6, BALL_CHANGE_Y(r0)                        # ball change_y
    movia   r7, 80-BALL_SIZE-BOARD_OFFSET
    movia   r8, 60-BALL_SIZE
    ldw     r9, P2_Y(r0)
    movia   r10, 0
    ldw     r11, P1_Y(r0)
    movia   r12, 0
gl_advance_ball:
    add    r3, r3, r5         # update screen position using x change
    add    r4, r4, r6        # update screen position using y change

    bgt     r3, r7, flip_x_change
    blt     r3, r0,  flip_x_change
    bgt     r4, r8, flip_y_change
    blt     r4, r0, flip_y_change 
gl_flip_then:
    stw     r3, BALL_X(r0)     # store ball x and y in memory 
    stw     r4, BALL_Y(r0) 

gl_move_p2:
    blt     r4, r9, gl_p2_move_up
    movia   r10, 2
    stw     r10, P2_CHANGE_Y(r0)
    br      gl_add_p2

gl_p2_move_up:
    movia   r10, -2
    stw     r10, P2_CHANGE_Y(r0)

gl_add_p2:
    movia   r8, 60-PADDLE_LENGTH
    add     r9, r9, r10
    blt     r9, r0, gl_move_p2
    bgt     r9, r8, gl_p2_move_up
    stw     r9, P2_Y(r0)
gl_move_p1:
    ldw     r9, P1_Y(r0)
    ldw     r10, P1_CHANGE_Y(r0)
    blt     r9, r0, gl_stop_p1_top
    bgt     r9, r8, gl_stop_p1_bot
    add     r9, r9, r10
    stw     r9, P1_Y(r0)
    br gl_p1_end

gl_stop_p1_top:
    movia   r10, 0
    stw     r10, P1_Y(r0)
    br gl_p1_end

gl_stop_p1_bot:
    movia   r10, 60-PADDLE_LENGTH
    stw     r10, P1_Y(r0)
    br gl_p1_end

gl_p1_end:
    br gl_clear_stack

# after flip, loop to make sure the ball is in bounds 
flip_x_change:
    muli    r5, r5, -1
    stw     r5, BALL_CHANGE_X(r0)
advance_x_pos:
    add    r3, r3, r5         # update screen position using x change
    bgt     r3, r7, advance_x_pos
    blt     r3, r0, advance_x_pos
    br gl_flip_then
flip_y_change:
    muli    r6, r6, -1
    stw     r6, BALL_CHANGE_Y(r0)
advance_y_pos:              
    add    r4, r4, r6         # update screen position using x change
    bgt    r4, r8, advance_y_pos
    blt    r4, r0, advance_y_pos
    br gl_flip_then    

gl_clear_stack:
    ldw     ra, 0(sp)
    ldw     r3, 4(sp)
    ldw     r4, 8(sp)
    ldw     r5, 12(sp)
    ldw     r6, 16(sp)
    ldw     r7, 20(sp)
    ldw     r8, 24(sp)
    ldw     r9, 28(sp)
    ldw     r10, 32(sp)
    ldw     r11, 36(sp)
    ldw     r12, 40(sp)
    addi    sp, sp, 44
    ret


CheckCollisions:
cc_init_stack:
    subi    sp, sp, 16
    stw     r3, 0(sp)
    stw     r4, 4(sp)
    stw     r5, 8(sp)
    stw     r6, 12(sp)

cc_player_check:
    # check whick player should have score deducted based on ballx
    movia   r3, 5
    ldw     r4, BALL_X(r0)

    # if ballx is less than 5, player 1 is losing
    bgt     r4, r3, cc_player2
    br cc_player1

# (Py + P) - By || (By + B) - Py < 0
# (r3 + r4) - r5, (r5+r6) - r3
# r4 <= r3 + r4 || r5 <= r5 + r6 - r3
# r4 OR r5 < 0 gives scoring area
cc_player1:     
    ldw     r3, P1_Y(r0)
    movia   r4, PADDLE_LENGTH
    ldw     r5, BALL_Y(r0)
    movia   r6, BALL_SIZE
    add     r4, r4, r3
    sub     r4, r4, r5  # Prepare (Py+P)-By into r4 since it is unused
    add     r5, r5, r6  # prepare (By + B) - Py into r5 for shits
    sub     r5, r5, r3
    or      r5, r4, r5
    blt     r5, r0, cc_increment_score
    br cc_clear_stack

cc_increment_score:
    movia   r5, 0x10001000
    # movia   r6, 'z'
    # stwio   r6, 0(r5)
    stw     r5, RESET_FLAG(r0)
    
cc_player2:
    # not possible for p2 to lose but maybe ill change that one day

cc_clear_stack:
    ldw     r3, 0(sp)
    ldw     r4, 4(sp)
    ldw     r5, 8(sp)
    ldw     r6, 12(sp)
    addi    sp, sp, 16
    ret

drawBall:
    subi    sp, sp, 8
    stw     r3, 0(sp)
    stw     ra, 4(sp)
    
    ldw     r3, BALL_X(r0)
    stw     r3, PIXEL_X(r0)

    ldw     r3, BALL_Y(r0)
    stw     r3, PIXEL_Y(r0)

    movia   r3, BALL_SIZE
    stw     r3, RECT_H(r0)
    stw     r3, RECT_W(r0)
    
    call DrawRect

    ldw     r3, 0(sp)
    ldw     ra, 4(sp)
    addi    sp, sp, 8   
    ret

drawP1:
    subi    sp, sp, 8
    stw     r3, 0(sp)
    stw     ra, 4(sp)

    movia   r3, BOARD_OFFSET
    stw     r3, PIXEL_X(r0)

    ldw     r3, P1_Y(r0)
    stw     r3, PIXEL_Y(r0)

    movia   r3, 2
    stw     r3, RECT_W(r0)

    movia   r3, PADDLE_LENGTH
    stw     r3, RECT_H(r0)

    call DrawRect

    ldw     r3, 0(sp)
    ldw     ra, 4(sp)
    addi    sp, sp, 8
    ret

drawP2:
    subi    sp, sp, 8
    stw     r3, 0(sp)
    stw     ra, 4(sp)

    movia   r3, 80-2-BOARD_OFFSET
    stw     r3, PIXEL_X(r0)

    ldw     r3, P2_Y(r0)
    stw     r3, PIXEL_Y(r0)

    movia   r3, 2
    stw     r3, RECT_W(r0)

    movia   r3, PADDLE_LENGTH
    stw     r3, RECT_H(r0)

    call DrawRect

    ldw     r3, 0(sp)
    ldw     ra, 4(sp)
    addi    sp, sp, 8
    ret


DrawRect:
dr_init_stack:
    subi    sp, sp, 32          # claim stack space
    
    stw     ra, 28(sp)
    stw     r9, 24(sp)          # math var
    stw     r3, 20(sp)          # rect X
    stw     r4, 16(sp)          # rect Y
    stw     r5, 12(sp)          # length       
    stw     r6, 8(sp)           # colour
    stw     r7, 4(sp)           # counter x
    stw     r8, 0(sp)           # counter y

dr_init_registers:
    ldw     r3, PIXEL_X(r0)     # init x
    ldw     r4, PIXEL_Y(r0)     # init y
    ldw     r5, RECT_W(r0)      # init width
    ldw     r6, RECT_H(r0)      # init length
    movi    r7, 0               # x(width) counter
    movi    r8, 0               # y(height) counter    

# basically
# for y < h:
#   for x < w:
#       plotpixel(screenpos, colour)
# PIXEL_LOCATION = (xpos + wcounter) + (ypos + hcounter) * w
draw_rect_h:
draw_rect_w:
    # reset changed registers
    movia   r9, SCREENBUFFER        # move base adress to r9
    ldw     r4, PIXEL_Y(r0)         
    ldw     r3, PIXEL_X(r0)    

    # find (y+ycounter)*w
    add     r4, r4, r8
    muli    r4, r4, SCREEN_W
	

    #find (x+xcounter) + (y+ycounter)*w 
    add     r9, r9, r3                  # adding pixel x
    add     r9, r9, r4                  # adding previous height term
    add     r9, r9, r7                  # adding x counter (rect width offset)

    stw     r9, PIXEL_LOCATION(r0)      # store pixel location to send into plotpixel
    call PlotPixel

    addi    r7, r7, 1                   # increment loop counter
    blt     r7, r5, draw_rect_w         # if loop counter exceeds length, proceed to next y

    movi    r7, 0                       # reset next loop counter

    addi    r8, r8, 1                   # increment y loop counter
    blt     r8, r6, draw_rect_h         # repeat for each row
    br      draw_end

draw_end:
dr_clear_stack:
    ldw     ra, 28(sp)
    ldw     r9, 24(sp)
    ldw     r3, 20(sp)
    ldw     r4, 16(sp)
    ldw     r5, 12(sp)
    ldw     r6, 8(sp)
    ldw     r7, 4(sp)
    ldw     r8, 0(sp)
    addi    sp, sp, 32
    ret

PlotPixel:
    subi    sp, sp, 12
    stw     ra, 8(sp)
    stw     r3, 4(sp)
    stw     r4, 0(sp)

    ldw     r3, COLOUR(r0)
    ldw     r4, PIXEL_LOCATION(r0)
    stbio   r3, 0(r4)           # write to screenbuffer
    
    ldw     ra, 8(sp)
    ldw     r3, 4(sp)
    ldw     r4, 0(sp)
    addi    sp, sp, 12
    ret

ClearScreen:
cs_init_stack:
    subi    sp, sp, 16
    stw     r3, 0(sp)
    stw     r4, 4(sp)
    stw     r5, 8(sp)
    stw     ra, 12(sp)
cs_init_registers:
    movia   r3, SCREENBUFFER    # pixel location
    movia   r4, PIXELS               # loop counter 
    movia   r5, 0x00               #colour
    stw     r5, COLOUR(r0)          # i store it once here to save instructions
cs_loop:
    stw     r3, PIXEL_LOCATION(r0)
    call PlotPixel
    subi    r4, r4, 1
    addi    r3, r3, 1
    bgt     r4, r0, cs_loop
cs_clear_stack:
    ldw     r3, 0(sp)
    ldw     r4, 4(sp)
    ldw     r5, 8(sp)
    ldw     ra, 12(sp)
    addi    sp, sp, 16
    ret

vsync:
v_init_stack:
    subi    sp, sp, 16
    stw     r3, 0(sp)
    stw     r4, 4(sp)
    stw     r5, 8(sp)
    stw     r6, 12(sp)
v_init_registers:
    movia   r3, PIXELBUFFER
    movia   r4, SCREENBUFFER
    movia   r5, PIXELS
    movia   r6, 0
v_loop:
    ldbio   r6, 0(r4)
    stbio   r6, 0(r3)
    addi    r3, r3, 1
    addi    r4, r4, 1
    subi    r5, r5, 1
    bgt     r5, r0, v_loop
v_clear_stack:
    ldw     r3, 0(sp)
    ldw     r4, 4(sp)
    ldw     r5, 8(sp)
    ldw     r6, 12(sp)
    addi    sp, sp, 16
    ret

GetJTAG:
gj_init_stack:
	subi	sp, sp, 8			
	stw		r3, 4(sp)			
	stw		r4, 0(sp)	
gj_load:
	movia	r3, 0x10001000
	ldwio	r2, 0(r3)	
gj_clear_stack:
	ldw		r3, 4(sp)				
	ldw		r4, 0(sp)				
	addi	sp, sp, 8				
	ret	

wait:
    subi    sp, sp, 4
    stw     r3, 0(sp)
    movia   r3, WAIT_LENGTH
wait_loop:
    subi    r3, r3, 1
    bgt     r3, r0, wait_loop

    ldw     r3, 0(sp)
    addi    sp, sp, 4
    ret

#======================= vars
    .org 0x1000

PIXEL_LOCATION: .skip 4
COLOUR:         .skip 4
PIXEL_X:        .skip 4
PIXEL_Y:        .skip 4
BALL_X:         .skip 4
BALL_Y:         .skip 4
BALL_CHANGE_X:  .skip 4
BALL_CHANGE_Y:  .skip 4
P1_Y:           .skip 4
P1_CHANGE_Y:    .skip 4
P2_Y:           .skip 4
P2_CHANGE_Y:    .skip 4
RECT_W:         .skip 4
RECT_H:         .skip 4
RESET_FLAG:     .skip 4
