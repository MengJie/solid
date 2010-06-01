require "hash"

local string = string
local table = table
local hash = hash
local coroutine = coroutine
local insert = table.insert
local format = string.format

-- This function is used for serialize a lua table to a string
-- and vice verse.

local function record_node(ids, nodes, node)
	if ids[node] ~= nil then
		return
	end
	local id = #nodes + 1
	nodes[id] = node
	ids[node] = id
	if type(node) == "table" then
		for k, v in pairs(node) do
			record_node(ids, nodes, k)
			record_node(ids, nodes, v)
		end
	end
end

local function link_node(ids, nodes, links)
	for i, v in ipairs(nodes) do
		if type(v) == 'table' then
			local tbl_id = ids[v]
			for kk, vv in pairs(v) do
				key_id = ids[kk]
				val_id = ids[vv]
				links[#links + 1] = {tbl_id, key_id, val_id}
			end
		end
	end
end

local function serialize(nodes, links)
	local buf = {}
	buf[#buf + 1] = "{{"
	for i, v in ipairs(nodes) do
		if type(v) == 'table' then
			buf[#buf + 1] = "{},"
		elseif type(v) == 'number' then
			buf[#buf + 1] = v..","
		elseif type(v) == 'boolean' then
			buf[#buf + 1] = tostring(v)..","
		else
			buf[#buf + 1] = string.format("%q", v) .. ','
		end
	end
	buf[#buf + 1] = "},{"
	for i, v in ipairs(links) do
		buf[#buf + 1] = "{" .. v[1] ..","..v[2]..","..v[3].."},"
	end
	buf[#buf + 1] = "},}"
	return table.concat(buf)
end

function save_table(tbl)
	local ids = {}
	local nodes = {}
	local links = {}

	record_node(ids, nodes, tbl)
	link_node(ids, nodes, links, tbl)
	return serialize(nodes, links)
end

function load_table(str)
	local result = assert(loadstring('return '..str))()
	local nodes = result[1]
	local links = result[2]
	for i, v in ipairs(links) do
		nodes[v[1]][nodes[v[2]]] = nodes[v[3]]
	end
	return nodes[1]
end

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
	return _repr(tbl, key, 0, fun)
end

function calchash(value)
	return hash.repr(hash.md5(value))
end

