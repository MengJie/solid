//
// hasp.cpp 2010/01/30 mengjie
//

#include <mhash.h>
#include "hash.hpp"

static int hash_repr(lua_State * L)
{
	size_t buflen;
	const char * buffer = luaL_checklstring(L, 1, &buflen);

	char * ret = new char[2*buflen+1];
	char * start = ret;

	for (int i = 0; i < buflen; ++i) {
		ret += sprintf(ret, "%.2x", 0xff & buffer[i]);
	}

	lua_pushlstring(L, start, 2*buflen);

	return 1;
}

static int hash_md5(lua_State * L)
{
	size_t buflen;
	const char * buffer = luaL_checklstring(L, 1, &buflen);

	MHASH td = mhash_init(MHASH_MD5);
	if (td == MHASH_FAILED)
		return luaL_error(L, "init MHASH for md5 failed.");

	mhash(td, buffer, buflen);

	char hash[16]; /* only for md5 */
	mhash_deinit(td, hash);

	lua_pushlstring(L, hash, 16);

	return 1;
}

static int hash_sha1(lua_State * L)
{
	size_t buflen;
	const char * buffer = luaL_checklstring(L, 1, &buflen);

	MHASH td = mhash_init(MHASH_SHA1);
	if (td == MHASH_FAILED)
		return luaL_error(L, "init MHASH for md5 failed.");

	mhash(td, buffer, buflen);

	char hash[20]; /* only for md5 */
	mhash_deinit(td, hash);

	lua_pushlstring(L, hash, 20);

	return 1;
}

static const luaL_Reg hashlib[] = {
  {"repr", hash_repr},
  {"md5", hash_md5},
  {"sha1", hash_sha1},
  {NULL, NULL}
};

extern "C" int luaopen_hash(lua_State * L)
{
	luaL_register(L, "hash", hashlib);
	return 1;
}

