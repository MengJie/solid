
INC=-I../include

LIBPATH=-L/usr/lib

HASH_LIB=-lmhash -lstdc++
HASH_OBJ=hash.o

hash.so: $(HASH_OBJ)
	$(CC) -g -shared $(LIBPATH) $(HASH_OBJ) $(HASH_LIB) -o $@

.cpp.o:
	$(CC) -g -c $(INC) $< -o $@

clean:
	rm -f *.o
	rm hash.so
