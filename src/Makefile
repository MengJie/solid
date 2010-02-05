
INC=-I../include \
	-I/usr/local/include \
	-I/usr/local/include/lua51

LIBPATH=-L/usr/lib \
		-L/usr/local/lib

.PHONY: all
all: hash.so uuid.so

HASH_LIB=-lmhash -lstdc++
HASH_OBJ=hash.o
hash.so: $(HASH_OBJ)
	$(CC) -g -shared $(LIBPATH) $(HASH_OBJ) $(HASH_LIB) -o $@

UUID_LIB=-luuid
UUID_OBJ=luuid.o
uuid.so: $(UUID_OBJ)
	$(CC) -g -shared $(LIBPATH) $(UUID_OBJ) $(UUID_LIB) -o $@

.cpp.o:
	$(CC) -g -c $(INC) $< -o $@

.c.o:
	$(CC) -g -c $(INC) $< -o $@

clean:
	rm -f *.o
	rm hash.so
	rm uuid.so

