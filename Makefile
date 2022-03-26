.phony: all
all:
	nasm -f bin -o tictac.com tictac.asm
	wc -c tictac.com
