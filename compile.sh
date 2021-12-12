#!/bin/bash

is=`find ./$1.asm 2> /dev/null | wc -l`

if [ $is = 0 ]
then
	echo "Print file title"
	exit
fi

nasm -f elf32 -o  ./$1.o ./$1.asm
ld -m elf_i386 -o ./$1  ./$1.o
