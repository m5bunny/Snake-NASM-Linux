
global _start

section .data
;; System calls
sys_exit	EQU 0x01
sys_read	EQU 0x03
sys_write	EQU 0x04
sys_poll	EQU 0xA8
sys_nanosleep	EQU 0xA2
sys_ioctl	EQU 0x36
sys_getrandom	EQU 0x163

;; Game objects
f_width 	EQU 60
f_height	EQU 28
f_length	EQU 1680

s_char 		EQU '@'
s_len		DW  0

field:
	TIMES	1680  DB '#'
	DB 	0x00

input_stat:
	fd 	DD 0
	events	DW 1
	revents	DW 0

clr_scr 	DB 27, "[2J", 27, "[0;0H", 0
clr_scr_len 	EQU $-clr_scr

time_val:
	sleep_sec	DD 0
	sleep_usec	DD 100000000

head_x	DW 30
head_y	DW 14

apl_x	DW 0
apl_y	DW 0

direct	DD 0

gm_ovr 		DB 0
eaten_apl	DB 0

section .bss
input	RESB	4
tms	RESB	36
canon	EQU	0x02
echo	EQU	0x08


random	RESB	4
s_coors:
	TIMES	1680 RESW 1	;	TODO	FIX FUCKING RANDOM

section .text

fill_field:
	MOV	eax, f_width
	SUB	eax, 1			;;29
	MOV	ecx, f_length
	SUB	ecx, 1
	do_fill_nl:
	MOV	BYTE [field+eax], 0x0A
	ADD	eax, f_width		;;30
	CMP	eax, ecx		;;419
	JNZ	do_fill_nl
	MOV	BYTE [field+eax], 0x0A

	MOV	eax, f_width		;;31
	ADD	eax, 1
	MOV	ebx, f_width
	ADD	ebx, f_width
	SUB	ebx, 2			;;58
	MOV	ecx, f_length
	SUB	ecx, 2			;;418
	do_fill_line:
	do_fill_char:
	MOV	BYTE[field+eax], ' '
	ADD	eax, 1
	CMP	eax, ebx
	JNZ	do_fill_char
	ADD	eax, 3
	ADD	ebx, f_width	      	;;30
	CMP	ebx, ecx		;;418
	JNZ	do_fill_line
	RET

off_can_echo:
	MOV	eax, sys_ioctl
	MOV	ebx, 0x00
	MOV	ecx, 0x5401
	MOV	edx, tms
	INT	0x80

	AND 	DWORD [tms+12], ~canon
	AND	DWORD [tms+12], ~echo

	MOV	eax, sys_ioctl
	MOV	ebx, 0x00
	MOV	ecx, 0x5402
	MOV	edx, tms
	INT	0x80
	RET

on_can_echo:
	MOV	eax, sys_ioctl
	MOV	ebx, 0x00
	MOV	ecx, 0x5401
	MOV	edx, tms
	INT	0x80

	OR 	DWORD [tms+12], canon
	OR	DWORD [tms+12], echo

	MOV	eax, sys_ioctl
	MOV	ebx, 0x00
	MOV	ecx, 0x5402
	MOV	edx, tms
	INT	0x80
	RET

show_field:
        MOV     eax, sys_write
        MOV     ebx, 0x01
        MOV     ecx, field
        MOV     edx, f_length
        INT     0x80
        RET

get_input:
	MOV	eax, sys_read
	MOV	ebx, 0x00
	MOV	ecx, input
	MOV	edx, 0x01
	INT	0x80
	RET

sleep:
	MOV	eax, sys_nanosleep
	MOV	ebx, time_val
	MOV	ecx, 0
	INT	0x80
	RET

clear_screen:
	MOV 	eax, sys_write
	MOV	ebx, 0x01
	MOV	ecx, clr_scr
	MOV	edx, clr_scr_len
	INT	0x80
	RET

handle_input:
	handle_next:
	MOV	eax, sys_poll
	MOV	ebx, input_stat
	MOV	ecx, 0x01
	MOV	edx, 0x00
	INT	0x80
	TEST	eax, eax
	JZ	handle_end
	CALL	get_input

	MOV	ecx,  'w'
	CMP	cl,  BYTE[input]
	JNZ	nb1
	CMP	WORD[direct+16], 1
	JZ	handle_next
	MOV	WORD[direct], 0
	MOV	WORD[direct+16], -1
	JMP	handle_next

	nb1:
	MOV	ecx,  'a'
	CMP	cl,  BYTE[input]
	JNZ	nb2
	CMP	WORD[direct], 1
	JZ	handle_next
	MOV	WORD[direct], -1
	MOV	WORD[direct+16], 0
	JMP	handle_next

	nb2:
	MOV	ecx,  's'
	CMP	cl,  BYTE[input]
	JNZ	nb3
	CMP	WORD[direct+16], -1
	JZ	handle_next
	MOV	WORD[direct], 0
	MOV	WORD[direct+16], 1
	JMP	handle_next

	nb3:
	MOV	ecx,  'd'
	CMP	cl,  BYTE[input]
	JNZ	nb4
	CMP	WORD[direct], -1
	JZ	handle_next
	MOV	WORD[direct], 1
	MOV	WORD[direct+16], 0
	JMP	handle_next

	nb4:
	MOV	ecx, 'q'
	CMP	cl, BYTE[input]
	JNZ	handle_next
	MOV	BYTE[gm_ovr], 1
	JMP	handle_next
	handle_end:
	RET

update_snake:
	MOV 	eax, 0
	CMP	BYTE[eaten_apl], 0
	JNZ	apple_eaten
	MOV	ax, WORD[s_len]
	MOV	ebx, 16
	MUL	ebx
	MOV	ebx, 0
	MOV	bx, WORD[s_coors+eax]
	MOV	BYTE[field+ebx], ' '
	JMP	apple_no_eaten

	apple_eaten:
	ADD	WORD[s_len], 1
	MOV	ax, WORD[s_len]
	MOV	ebx, 16
	MUL	ebx
	PUSH 	eax
	CALL	set_apl
	POP	eax
	SUB	BYTE[eaten_apl], 1

	apple_no_eaten:
	MOV 	ecx, eax

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
	MOV	BYTE[field+ebx], '@'
	RET

get_head_coors:
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
	CMP	BYTE[field+eax], ' '
	JZ	get_head_end
	CMP	BYTE[field+eax], '@'
	JNZ	nc1
	MOV	ecx, 0
	MOV	cx, WORD[direct]
	ADD	cx, WORD[direct+16]
	CMP	ecx, 0
	JZ	get_head_end
	MOV	BYTE[gm_ovr], 1

	nc1:
	CMP	BYTE[field+eax], '#'
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
	CMP	BYTE[field+eax], '*'
	JNZ	get_head_end
	MOV	BYTE[eaten_apl], 1
	get_head_end:
	MOV	ebx, eax
	RET

set_apl:
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
	MOV	ecx, 3
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
	CMP	BYTE[field+eax], ' '
	JNZ	rand
	MOV	BYTE[field+eax], '*'
	RET

init:
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

