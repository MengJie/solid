/*
   Copyright (c) 2009, Phoenix Sol - http://github.com/phoenixsol

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
   */

#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <lua.h>
#include <lauxlib.h>
#include <tcrdb.h>
#define LIB_NAME "tokyotyrant"
#define MT_NAME "RDB_MT"

enum {
	RDBPUT, // overwrite existing value (default)
	RDBPUTKEEP, // keep existing value
	RDBPUTCAT, // concatenate value to exisiting
	RDBPUTSHL, // concatenate value to existing, shifting to left by specified width
	RDBPUTNR // put and expect no response from server
};

typedef struct{
	TCRDB *rdb;
	bool is_open;
} RDBDATA;

static TCLIST*
array2tclist(lua_State *L, int index){
	int len = lua_objlen(L, index);
	TCLIST *list = tclistnew2(len);
	int i;
	for(i=1; i<=len; i++){
		lua_rawgeti(L, index, i);
		size_t vsiz;
		const char *vbuf = lua_tolstring(L, -1, &vsiz);
		if(vbuf) tclistpush(list, vbuf, vsiz);
		lua_pop(L, 1);
	}
	return list;
}

static TCLIST*
hash2tclist(lua_State *L, int index){
	int len = 0;
	lua_pushnil(L);
	while(lua_next(L, index) != 0){ len++; lua_pop(L, 1); }
	TCLIST *list = tclistnew2(len);
	lua_pushnil(L);
	while(lua_next(L, index) != 0){
		const char *key, *value;
		size_t ksize, vsize;

		if(lua_type(L, -2)==LUA_TNUMBER){
			lua_pushvalue(L, -2);
			key = lua_tolstring(L, -1, &ksize);
			lua_pop(L, 1);
		} else {
			key = lua_tolstring(L, -2, &ksize);
		}
		tclistpush(list, key, ksize);

		if(lua_type(L, -1)==LUA_TNUMBER){
			lua_pushvalue(L, -1);
			value = lua_tolstring(L, -1, &vsize);
			lua_pop(L, 1);
		} else {
			value = lua_tolstring(L, -1, &vsize);
		}
		tclistpush(list, value, vsize);
		lua_pop(L, 1);
	}
	return list;
}

static void
tclist2array(lua_State *L, TCLIST *list){
	int num = tclistnum(list);
	lua_createtable(L, num, 0);
	int i;
	for(i=0; i<num; i++){
		int size;
		const char *buf = tclistval(list, i, &size);
		lua_pushlstring(L, buf, size);
		lua_rawseti(L, -2, i + 1);
	}
}

static void
tclist2hash(lua_State *L, TCLIST *list){
	int num = tclistnum(list);
	lua_createtable(L, 0, num/2);
	int i;
	for(i=0; i<num-1; i+=2){
		int ksize, vsize;
		const char *key = tclistval(list, i, &ksize);
		const char *value = tclistval(list, i+1, &vsize);
		lua_pushlstring(L, value, vsize);
		lua_setfield(L, -2, key);
	}
}

static int
nil_error(lua_State *L, int code, const char *msg){
	lua_pushnil(L);
	lua_pushstring(L, msg);
	lua_pushinteger(L, code);
	return 3;
}

static int
bool_error(lua_State *L, int code, const char *msg){
	lua_pushboolean(L, 0);
	lua_pushstring(L, msg);
	lua_pushinteger(L, code);
	return 3;
}

static int
default_error(lua_State *L){
	return nil_error(L, errno, strerror(errno));
}

static int
rdb_error(lua_State *L, TCRDB *rdb){
	int ecode = tcrdbecode(rdb);
	return bool_error(L, ecode, tcrdberrmsg(ecode));
}

TCRDB*
rdb_getrdb(lua_State *L, int index){
	RDBDATA *data = luaL_checkudata(L, index, MT_NAME);
	return (TCRDB *)data->rdb;
}

static int
rdb_open(lua_State *L){
	const char *host = luaL_optstring(L, 1, "localhost");
	int port = luaL_optint(L, 2, 1978);
	RDBDATA *data = lua_newuserdata(L, sizeof(*data));
	if(!data) return default_error(L);
	data->rdb = tcrdbnew();
	if(!tcrdbopen(data->rdb, host, port)) return rdb_error(L, data->rdb);
	data->is_open = true;
	luaL_getmetatable(L, MT_NAME);
	lua_setmetatable(L, -2);
	return 1;
}

static int
rdb_close(lua_State *L){
	RDBDATA *data = luaL_checkudata(L, 1, MT_NAME);
	if(data->is_open){
		if(!tcrdbclose(data->rdb)) return rdb_error(L, data->rdb);
		data->is_open = false;
		tcrdbdel(data->rdb);
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int
rdb_tune(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	int opts = luaL_checkint(L, 2);
	double timeout = luaL_optnumber(L, 3, 0);
	bool result = tcrdbtune(rdb, timeout, opts);
	lua_pushboolean(L, result);
	return 1;
}

const char*
rdb_getarg(lua_State *L, int index, size_t *siz){
	const char *arg = NULL;
	switch(lua_type(L, index)){
		case LUA_TSTRING:
			arg = lua_tolstring(L, index, siz);
			break;
		case LUA_TNUMBER:
			lua_pushvalue(L, index); // convert a copy of the number
			arg = lua_tolstring(L, -1, siz);
			lua_pop(L, -1);
			break;
		default: luaL_argerror(L, index, "must be number or string");
	}
	return arg;
}

static int
rdb_put(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	int type = lua_type(L, 2);
	if(type==LUA_TSTRING || type==LUA_TNUMBER){
		size_t ksiz = 0; size_t vsiz = 0;
		const char *key = rdb_getarg(L, 2, &ksiz);
		const char *value = rdb_getarg(L, 3, &vsiz);
		int width;
		// get option & hit db
		switch(luaL_optint(L, 4, RDBPUT)){
			case RDBPUT:
				if(!tcrdbput(rdb, key, ksiz, value, vsiz)) return rdb_error(L, rdb);
				break;
			case RDBPUTKEEP:
				if(!tcrdbputkeep(rdb, key, ksiz, value, vsiz)) return rdb_error(L, rdb);
				break;
			case RDBPUTCAT:
				if(!tcrdbputcat(rdb, key, ksiz, value, vsiz)) return rdb_error(L, rdb);
				break;
			case RDBPUTSHL:
				width = luaL_checknumber(L, 4);
				if(!tcrdbputshl(rdb, key, ksiz, value, vsiz, width)) return rdb_error(L, rdb);
				break;
			case RDBPUTNR:
				if(!tcrdbputnr(rdb, key, ksiz, value, vsiz)) return rdb_error(L, rdb);
				break;
		}
	} else if(type==LUA_TTABLE){
		TCLIST *list = hash2tclist(L, 2);
		int opts = luaL_optint(L, 3, 0);
		TCLIST *useless = tcrdbmisc(rdb, "putlist", opts, list);
		tclistdel(list);
		tclistdel(useless);
	} else return luaL_argerror(L, 2, "must be table, string, or number");
	lua_pushboolean(L, 1);
	return 1;
}

static int
rdb_out(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	int type = lua_type(L, 2);
	if(type==LUA_TSTRING || type==LUA_TNUMBER){
		size_t ksiz = 0;
		const char *key = rdb_getarg(L, 2, &ksiz);
		if(!tcrdbout(rdb, key, ksiz)) return rdb_error(L, rdb);
	} else if(type==LUA_TTABLE){
		TCLIST *list = array2tclist(L, 2);
		int opts = luaL_optint(L, 3, 0);
		TCLIST *useless = tcrdbmisc(rdb, "outlist", opts, list);
		tclistdel(list);
		tclistdel(useless);
	} else return luaL_argerror(L, 2, "must be table, string, or number");
	lua_pushboolean(L, 1);
	return 1;
}

static int
rdb_get(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	int type = lua_type(L, 2);
	if(type==LUA_TSTRING || type==LUA_TNUMBER){
		size_t ksiz = 0;
		const char *key = rdb_getarg(L, 2, &ksiz);
		int sp;
		char *value = tcrdbget(rdb, key, ksiz, &sp);
		if(value){
			lua_pushlstring(L, value, sp);
			free(value);
		} else lua_pushnil(L);
	} else if(type==LUA_TTABLE){
		TCLIST *list = array2tclist(L, 2);
		int opts = luaL_optint(L, 3, 0);
		TCLIST *pairs = tcrdbmisc(rdb, "getlist", opts, list);
		tclist2hash(L, pairs);
		tclistdel(list);
		tclistdel(pairs);
	} else return luaL_argerror(L, 2, "must be table, string, or number");
	return 1;
}

static int
rdb_vsiz(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	size_t ksiz = 0;
	const char *key = rdb_getarg(L, 2, &ksiz);
	int vsiz = tcrdbvsiz(rdb, key, ksiz);
	lua_pushnumber(L, vsiz);
	return 1;
}

static int
rdb_addnum(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	size_t ksiz = 0;
	const char *key = rdb_getarg(L, 2, &ksiz);
	double num = luaL_checknumber(L, 3);
	double result = tcrdbadddouble(rdb, key, ksiz, num);
	lua_pushnumber(L, result);
	return 1;
}

static int
rdb_nextkey(lua_State *L){
	RDBDATA *data = (RDBDATA *)lua_touserdata(L, lua_upvalueindex(1));
	int sp;
	void *key = tcrdbiternext(data->rdb, &sp);
	if(key){
		lua_pushlstring(L, (char *)key, sp);
		free(key);
	} else lua_pushnil(L);
	return 1;
}

static int
rdb_keys(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	bool init = tcrdbiterinit(rdb);
	if(init){
		lua_pushcclosure(L, rdb_nextkey, 1);
	} else luaL_error(L, "unable to initialize iterator");
	return 1;
}

static int
rdb_fwmkeys(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	size_t psiz = 0;
	const char *prefix = rdb_getarg(L, 2, &psiz);
	int max = luaL_optint(L, 3, -1);
	TCLIST *keys = tcrdbfwmkeys(rdb, prefix, psiz, max);
	tclist2array(L, keys);
	tclistdel(keys);
	return 1;
}

static int
rdb_ext(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	size_t nsiz = 0;
	size_t ksiz = 0;
	size_t vsiz = 0;
	int sp;
	const char *name = rdb_getarg(L, 2, &nsiz);
	const char *key = rdb_getarg(L, 3, &ksiz);
	const char *value = rdb_getarg(L, 4, &vsiz);
	int opts = luaL_optint(L, 5, 0);
	char *res = (char*)tcrdbext(rdb, name, opts, key, ksiz, value, vsiz, &sp);
	lua_pushlstring(L, res, sp);
	free(res);
	return 1;
}

static int
rdb_sync(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	lua_pushboolean(L, tcrdbsync(rdb));
	return 1;
}

static int
rdb_optimize(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	const char *params = luaL_optstring(L, 2, NULL);
	lua_pushboolean(L, tcrdboptimize(rdb, params));
	return 1;
}

static int
rdb_vanish(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	lua_pushboolean(L, tcrdbvanish(rdb));
	return 1;
}

static int
rdb_copy(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	const char *path = luaL_checkstring(L, 2);
	lua_pushboolean(L, tcrdbcopy(rdb, path));
	return 1;
}

static int
rdb_restore(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	const char *path = luaL_checkstring(L, 2);
	uint64_t tstamp = (uint64_t)luaL_checkinteger(L, 3); // x_x
	int opts = luaL_optint(L, 4, 0);
	lua_pushboolean(L, tcrdbrestore(rdb, path, tstamp, opts));
	return 1;
}

static int
rdb_setmst(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	const char *host = luaL_checkstring(L, 2);
	int port = luaL_checkinteger(L, 3);
	uint64_t tstamp = (uint64_t)luaL_checkinteger(L, 4); // x_x
	int opts = luaL_optint(L, 5, 0);
	lua_pushboolean(L, tcrdbsetmst(rdb, host, port, tstamp, opts));
	return 1;
}

static int
rdb_rnum(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	lua_pushnumber(L, (double)tcrdbrnum(rdb)); // x_x
	return 1;
}

static int
rdb_size(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	lua_pushnumber(L, (double)tcrdbsize(rdb)); // x_x
	return 1;
}

static int
rdb_stat(lua_State *L){
	TCRDB *rdb = rdb_getrdb(L, 1);
	char *status = tcrdbstat(rdb);
	lua_pushstring(L, status);
	free(status);
	return 1;
}

static luaL_reg pfuncs[] = { {"open", rdb_open}, {NULL, NULL} };
static luaL_reg mmethods[] = {
	{"close", rdb_close},
	{"tune", rdb_tune},
	{"put", rdb_put},
	{"out", rdb_out},
	{"del", rdb_out},
	{"get", rdb_get},
	{"vsize", rdb_vsiz},
	{"keys", rdb_keys},
	{"fwmkeys", rdb_fwmkeys},
	{"addnum", rdb_addnum},
	{"ext", rdb_ext},
	{"sync", rdb_sync},
	{"optimize", rdb_optimize},
	{"vanish", rdb_vanish},
	{"copy", rdb_copy},
	{"restore", rdb_restore},
	{"setmaster", rdb_setmst},
	{"rnum", rdb_rnum},
	{"size", rdb_size},
	{"status", rdb_stat},
	{NULL, NULL}
};

#define register_constant(s) lua_pushinteger(L,s); lua_setfield(L, -2, #s);

int luaopen_tokyotyrant(lua_State *L){
	luaL_newmetatable(L, MT_NAME);
	lua_createtable(L, 0, sizeof(mmethods) / sizeof(luaL_reg) -1);
	luaL_register(L, NULL, mmethods);
	lua_setfield(L, -2, "__index");

	lua_pushcfunction(L, rdb_rnum);
	lua_setfield(L, -2, "__len");

	lua_pushcfunction(L, rdb_close);
	lua_setfield(L, -2, "__gc");
	lua_pop(L, 1);

	luaL_register(L, LIB_NAME, pfuncs);

	register_constant(RDBTRECON);
	register_constant(RDBXOLCKREC);
	register_constant(RDBXOLCKGLB);
	register_constant(RDBROCHKCON);
	register_constant(RDBMONOULOG);

	register_constant(RDBPUT);
	register_constant(RDBPUTKEEP);
	register_constant(RDBPUTCAT);
	register_constant(RDBPUTSHL);
	register_constant(RDBPUTNR);

	return 1;
}

