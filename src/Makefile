
INC=-I../include \
	-I/usr/local/include \
	-I/usr/local/include/lua51

LIBPATH=-L/usr/lib \
		-L/usr/local/lib

HASH_LIB=-lmhash -lstdc++
HASH_OBJ=hash.o

hash.so: $(HASH_OBJ)
	$(CC) -g -shared $(LIBPATH) $(HASH_OBJ) $(HASH_LIB) -o $@

.cpp.o:
	$(CC) -g -c $(INC) $< -o $@

clean:
	rm -f *.o
	rm hash.so
