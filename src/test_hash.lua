#!/usr/bin/lua
require 'hash'

--ret = hash.repr(hash.md5(arg[1]))
--print(string.format('md5("%s") = %s', arg[1], ret))
--
--ret = hash.repr(hash.sha1(arg[1]))
--print(string.format('sha1("%s") = %s', arg[1], ret))
--
data = string.rep("abcdefghij", 1024 * 1024 * 10)

--local file = io.open("tmp.data", "w")
--file:write(data)
--file:close()

print(hash.repr(hash.sha1(data)))

print(os.clock())

