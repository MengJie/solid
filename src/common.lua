require "hash"

local string = string
local table = table
local hash = hash
local coroutine = coroutine
local insert = table.insert
local format = string.format

local function indent(level)
	return string.rep("    ", level)
end

local function keystr(key)
	if type(key) == 'number' then
		return '['..tostring(key)..']'
	else
		return key
	end
end

local function _repr(tbl, key, level, pairsfun)
	level = level or 0
	key = key or ""
	local ret = {}

	local head = (key == "") and
		format("%s{", indent(level)) or
		format("%s%s = {", indent(level), keystr(key))
	insert(ret, head)

	for k, v in pairsfun(tbl) do
		if type(v) == 'table' then
			insert(ret, _repr(v, k, level + 1, pairsfun))
		elseif type(v) == 'number' then
			insert(ret, format("%s%s = %s,",
				indent(level+1), keystr(k), tostring(v)))
		elseif type(v) == 'string' then
			insert(ret, format("%s%s = %q,",
				indent(level+1), keystr(k), v))
		elseif type(v) == 'boolean' then
			insert(ret, format("%s%s = %s,",
				indent(level+1), keystr(k), tostring(v)))
		else
			error('unsupport type ' .. type(v))
		end
	end

	local tail = (level == 0) and
		format("%s}", indent(level)) or
		format("%s},", indent(level))
	insert(ret, tail)

	return table.concat(ret, '\n')
end

function repr(tbl, keyfun, funkey)
	local key, fun = keyfun, funkey
	if type(key) == 'function' then
		key, fun = fun, key
	end
	fun = fun or pairs
	return _repr(tbl, "", 0, fun)
end

function calchash(value)
	return hash.repr(hash.md5(value))
end

