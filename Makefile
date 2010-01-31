
INC=-I.

LIB=mhash.so

hash.so: $(HASH_OBJ)
	$(CC) -shared $(HASH_OBJ) $(LIB) -o $<

.c.o:
	$(CC) $(INC) $@ -o $<

