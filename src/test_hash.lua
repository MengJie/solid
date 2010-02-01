#!/usr/bin/lua
require 'hash'

ret = hash.repr(hash.md5(arg[1]))
print(string.format('md5("%s") = %s', arg[1], ret))

ret = hash.repr(hash.sha1(arg[1]))
print(string.format('sha1("%s") = %s', arg[1], ret))

