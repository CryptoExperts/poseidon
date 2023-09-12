CC = gcc
CFLAGS = -Wall -O3 -fPIC
CFLAGS_ASM = -DASSEMBLY
DEPS = f251.h poseidon_rc.h poseidon.h

OBJ_C   = f251.o poseidon_rc.o poseidon.o
OBJ_ASM = f251_c.o f251_asm.o poseidon_rc.o poseidon_asm.o
SO_C    = lib_pos.so 
SO_ASM  = lib_pos_asm.so

all: $(OBJ_C) $(OBJ_ASM) $(OBJ_AVX) $(SO_C) $(SO_ASM) test test_asm # $(SO_AVX)

only_c: $(OBJ_C) $(SO_C) 

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

poseidon_asm.o: poseidon.c
	$(CC) $(CFLAGS) $(CFLAGS_ASM) -c -o $@ $^

f251_c.o: f251.c
	$(CC) $(CFLAGS) $(CFLAGS_ASM) -c -o $@ $^

f251_asm.o: f251_asm.S
	$(CC) -c -o $@ $^ $(CFLAGS)

lib_pos.so:
	$(CC) $(CFLAGS) -shared -o $@ poseidon.o poseidon_rc.o f251.o

lib_pos_asm.so:
	$(CC) $(CFLAGS) $(CFLAGS_ASM) -shared -o $@ poseidon_asm.o poseidon_rc.o f251_c.o f251_asm.o

test: test.c f251.o poseidon_rc.o poseidon.o
	$(CC) $(CFLAGS) -fPIE -o $@ $^ 

test_asm: test.c f251_c.o f251_asm.o poseidon_rc.o poseidon_asm.o
	$(CC) $(CFLAGS) $(CFLAGS_ASM) -fPIE -o $@ $^ 

clean:
	rm -f *.o *.so test test_asm
