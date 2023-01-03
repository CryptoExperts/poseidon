CC = gcc
CFLAGS = -Wall -O0 -mno-avx -mno-sse
DEPS = f251.h poseidon_rc.h poseidon.h

OBJ_C   = f251.o poseidon_rc.o poseidon.o 
OBJ_ASM = f251_c.o f251_asm.o poseidon_asm.o
SO_C    = lib_pos.so 
SO_ASM  = lib_pos_asm.so

all: $(OBJ_C) $(OBJ_ASM) $(SO_C) $(SO_ASM)

only_c: $(OBJ_C) $(SO_C) 

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

poseidon_asm.o: poseidon.c
	$(CC) -DASSEMBLY -c -o $@ $^ $(CFLAGS)

f251_c.o: f251.c
	$(CC) -DASSEMBLY -c -o $@ $^ $(CFLAGS)

f251_asm.o: f251_asm.s
	$(CC) -c -o $@ $^ $(CFLAGS)

lib_pos.so:
	$(CC) $(CFLAGS) -shared -o $@ poseidon.o poseidon_rc.o f251.o

lib_pos_asm.so:
	$(CC) $(CFLAGS) -DASSEMBLY -shared -o $@ poseidon_asm.o poseidon_rc.o f251_c.o f251_asm.o

clean:
	rm -f *.o *.so
