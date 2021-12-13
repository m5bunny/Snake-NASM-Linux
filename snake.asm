
global _start

section .rodata
; System calls
sys_exit	EQU 0x01  ;Input - exit status. Ends the process.
sys_read	EQU 0x03  ;Input - fd, buf, count. Reads 'count' bytes from file 'fd' to 'buf'.
sys_write	EQU 0x04  ;Input - fd, buf, count. Writes 'count' bytes from 'buf' to file 'fd'.
sys_poll	EQU 0xA8  ;Input - pollfd. Checks status of 'event' in file 'fd'. Return - 0 < on success.
sys_nanosleep	EQU 0xA2  ;Input - timespec. Sleep duration specified in timespec.
sys_ioctl	EQU 0x36  ;Input - fd, request, args. Sets or reads 'args' from 'fd'.
sys_getrandom	EQU 0x163 ;Input - buf, buflen. Writes 'buflen' random bytes to 'buf'.

; Playing field range
f_width 	EQU 60
f_height	EQU 28
f_length	EQU 1680

; Game objects chars
s_char		EQU '@'
a_char		EQU 'o'
w_char		EQU '#'
e_char		EQU ' '

; Control chars
u_char		EQU 'w'
d_char		EQU 's'
l_char		EQU 'a'
r_char		EQU 'd'
q_char		EQU 'q'

section .data

s_len		DW  0

field:  	TIMES	1680 DB w_char,
		DB 	0x00

; System calls variables
pollfd:
	fd 	DD 0
	event	DW 1
	revent	DW 0

clr_scr 	DB 27, "[2J", 27, "[0;0H", 0
clr_scr_len 	EQU $-clr_scr

timespec:
	sleep_sec	DD 0
	sleep_usec	DD 100000000

canon		EQU 0x02
echo		EQU 0x08

; Game object positions
head_x		DW 30
head_y		DW 14

apl_x		DW 0
apl_y		DW 0

direct		DD 0

; Game events flags
gm_ovr 		DB 0
eaten_apl	DB 0

section .bss

; System call variables
input	RESB	1
args	RESB	36
random	RESB	2

; Snake segment positions
s_coors:
	TIMES	1680 RESW 1



section .text

fill_field:
; Fills the playing field with e_char and new line characters
	MOV	eax, f_width
	SUB	eax, 1
	MOV	ecx, f_length
	SUB	ecx, 1
	do_fill_nl:
	MOV	BYTE [field+eax], 0x0A
	ADD	eax, f_width
	CMP	eax, ecx
	JNZ	do_fill_nl
	MOV	BYTE [field+eax], 0x0A

	MOV	eax, f_width
	ADD	eax, 1
	MOV	ebx, f_width
	ADD	ebx, f_width
	SUB	ebx, 2
	MOV	ecx, f_length
	SUB	ecx, 2
	do_fill_line:
	do_fill_char:
	MOV	BYTE[field+eax], e_char
	ADD	eax, 1
	CMP	eax, ebx
	JNZ	do_fill_char
	ADD	eax, 3
	ADD	ebx, f_width	      	;;30
	CMP	ebx, ecx		;;418
	JNZ	do_fill_line
	RET

off_can_echo:
; Disables canonical terminal input and echo
	MOV	eax, sys_ioctl
	MOV	ebx, 0x00
	MOV	ecx, 0x5401
	MOV	edx, args
	INT	0x80

	AND 	DWORD[args+12], ~canon
	AND	DWORD[args+12], ~echo

	MOV	eax, sys_ioctl
	MOV	ebx, 0x00
	MOV	ecx, 0x5402
	MOV	edx, args
	INT	0x80
	RET

on_can_echo:
; Enables canonical terminal input and echo
	MOV	eax, sys_ioctl
	MOV	ebx, 0x00
	MOV	ecx, 0x5401
	MOV	edx, args
	INT	0x80

	OR 	DWORD[args+12], canon
	OR	DWORD[args+12], echo

	MOV	eax, sys_ioctl
	MOV	ebx, 0x00
	MOV	ecx, 0x5402
	MOV	edx, args
	INT	0x80
	RET

show_field:
; Outputs the field string on stdout
        MOV     eax, sys_write
        MOV     ebx, 0x01
        MOV     ecx, field
        MOV     edx, f_length
        INT     0x80
        RET

get_input:
; Gets one character from stdin to 'input' variable
	MOV	eax, sys_read
	MOV	ebx, 0x00
	MOV	ecx, input
	MOV	edx, 0x01
	INT	0x80
	RET

sleep:
; Sleeps during the period of time entered in 'timespec'
	MOV	eax, sys_nanosleep
	MOV	ebx, timespec
	MOV	ecx, 0
	INT	0x80
	RET

clear_screen:
; Clears screen by outputting a string with the control characters on stdout
	MOV 	eax, sys_write
	MOV	ebx, 0x01
	MOV	ecx, clr_scr
	MOV	edx, clr_scr_len
	INT	0x80
	RET

handle_input:
; Checks if stdin is empty by 'sys_poll'
; if not, gets an input character from 'get_input' till stdin gets empty
; and uses the last character from the input to change the direction
	handle_next:
	MOV	eax, sys_poll
	MOV	ebx, pollfd
	MOV	ecx, 0x01
	MOV	edx, 0x00
	INT	0x80
	CMP	eax, 0x00
	JZ	handle_end
	CALL	get_input

	MOV	ecx,  u_char
	CMP	cl,  BYTE[input]
	JNZ	nb1
	CMP	WORD[direct+16], 1
	JZ	handle_next
	MOV	WORD[direct], 0
	MOV	WORD[direct+16], -1
	JMP	handle_next

	nb1:
	MOV	ecx,  l_char
	CMP	cl,  BYTE[input]
	JNZ	nb2
	CMP	WORD[direct], 1
	JZ	handle_next
	MOV	WORD[direct], -1
	MOV	WORD[direct+16], 0
	JMP	handle_next

	nb2:
	MOV	ecx,  d_char
	CMP	cl,  BYTE[input]
	JNZ	nb3
	CMP	WORD[direct+16], -1
	JZ	handle_next
	MOV	WORD[direct], 0
	MOV	WORD[direct+16], 1
	JMP	handle_next

	nb3:
	MOV	ecx,  r_char
	CMP	cl,  BYTE[input]
	JNZ	nb4
	CMP	WORD[direct], -1
	JZ	handle_next
	MOV	WORD[direct], 1
	MOV	WORD[direct+16], 0
	JMP	handle_next

	nb4:
	MOV	ecx, q_char
	CMP	cl, BYTE[input]
	JNZ	handle_next
	MOV	BYTE[gm_ovr], 1
	JMP	handle_next
	handle_end:
	RET

update_snake:
; Changes the position of each snake's segments to the position
; of the previous one.
; Gets the new head position from 'get_head_coors' and adds 's_char' into it.
; If an apple hasn't been eaten deletes 's_char' in the tail by adding 'e_char' on its coordinates
; If an apple has been eaten increments snake length and generetes a new apple position by 'set_apl'
	CMP	BYTE[eaten_apl], 0
	JZ	apple_no_eaten
	ADD	WORD[s_len], 1
	CALL	set_apl
	apple_no_eaten:
	MOV 	eax, 0
	JNZ	apple_eaten
	MOV	ax, WORD[s_len]
	MOV	ebx, 16
	MUL	ebx
	MOV	ebx, 0
	MOV	bx, WORD[s_coors+eax]
	CMP	BYTE[eaten_apl], 0
	JNZ	apple_eaten
	MOV	BYTE[field+ebx], e_char

	apple_eaten:
	MOV	BYTE[eaten_apl], 0
	update_loop:
	CMP	eax, 0
	JZ	update_head
	SUB	eax, 16
	MOV	ebx, 0
	MOV	bx, WORD[s_coors+eax]
	MOV	WORD[s_coors+eax+16], bx
	JMP	update_loop
	update_head:
	CALL	get_head_coors
	MOV	WORD[s_coors], bx

	MOV	bx, WORD[s_coors]
	MOV	BYTE[field+ebx], s_char
	RET

get_head_coors:
; Gets xy position of the head by adding direction to the current position
; then converts xy position to the field array index
; checks if the new position filled with 'e_char' if not, checks which type of characters it's filled:
; if it's filled with 's_char' sets 'gm_ovr' flag to true
; if it's filled with 'w_char' sets the new position of the head to the opposite side
; if it's filled with 'a_char' sets the 'apl_eaten' flag to true
	get_head_start:
	MOV	ax, [head_x]
	ADD	ax, WORD[direct]
	MOV	[head_x], ax
	MOV	ax, [head_y]
	ADD	ax, WORD[direct+16]
	MOV	[head_y], ax
	MOV	ax, [head_y]
	MOV	ebx, f_width
	MUL	ebx
	ADD	ax, [head_x]
	CMP	BYTE[field+eax], e_char
	JZ	get_head_end
	CMP	BYTE[field+eax], s_char
	JNZ	nc1
	MOV	ecx, 0
	MOV	cx, WORD[direct]
	ADD	cx, WORD[direct+16]
	CMP	ecx, 0
	JZ	get_head_end
	MOV	BYTE[gm_ovr], 1

	nc1:
	CMP	BYTE[field+eax], w_char
	JNZ	nc2
	CMP	WORD[direct], 1
	JNZ	nch1
	MOV	WORD[head_x], 0
	JMP	get_head_start
	nch1:
	CMP	WORD[direct+16], 1
	JNZ	nch2
	MOV	WORD[head_y], 0
	JMP	get_head_start
	nch2:
	CMP	WORD[direct], -1
	JNZ 	nch3
	MOV 	cx, f_width
	SUB	cx, 2
	MOV	WORD[head_x], cx
	JMP	get_head_start
	nch3:
	CMP	WORD[direct+16], -1
	JNZ	get_head_end
	MOV	cx, f_height
	SUB	cx, 1
	MOV	WORD[head_y], cx
	JMP	get_head_start

	nc2:
	CMP	BYTE[field+eax], a_char
	JNZ	get_head_end
	MOV	BYTE[eaten_apl], 1
	get_head_end:
	MOV	ebx, eax
	RET

set_apl:
; Generate the xy position of the head
; then converts it to field array index
; checks if the position filled with 'e_char'
; if not repeat the procedure again
	rand:
	MOV	eax, sys_getrandom
	MOV	ebx, random
	MOV	ecx, 2
	MOV	edx, 0
	INT	0x80

	XOR	edx, edx
	MOV	ax,  WORD[random]
	MOV	ecx, f_width
	SUB	ecx, 2
	DIV	ecx
	MOV	WORD[apl_x], dx

	MOV	eax, sys_getrandom
	MOV	ebx, random
	MOV	ecx, 2
	MOV	edx, 0
	INT	0x80

	XOR	edx, edx
	MOV	ax, WORD[random]
	MOV	ecx, f_height
	SUB	ecx, 1
	DIV	ecx
	MOV	WORD[apl_y], dx

        XOR     eax, eax
	MOV	ax, WORD[apl_y]
	MOV	ebx, f_width
	MUL	ebx
	ADD	ax, WORD[apl_x]
	CMP	BYTE[field+eax], e_char
	JNZ	rand
	MOV	BYTE[field+eax], a_char
	RET

init:
;Initiates the game information
	MOV	BYTE[gm_ovr], 0
	CALL	off_can_echo
	CALL	fill_field
	CALL	get_head_coors
	MOV	WORD[s_coors], bx
        CALL     set_apl
	RET

_start:
	CALL	init

	game_loop:
	CALL	update_snake
	CALL	show_field
	CALL	handle_input
	CALL	sleep
	CALL	clear_screen
	CMP	BYTE[gm_ovr], 1
	JNZ	game_loop

	CALL	on_can_echo
	MOV	eax, sys_exit
	MOV	ebx, 0x00
	INT	0x80

