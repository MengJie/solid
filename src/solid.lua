require "hash"

local string = string
local table = table
local hash = hash
local coroutine = coroutine

function indent(level)
	return string.rep("    ", level)
end

function keystr(key)
	if type(key) == 'number' then
		return '['..tostring(key)..']'
	else
		return key
	end
end

function repr(tbl, level, key)
	level = level or 0
	key = key or ""
	local ret = {}
	if key == "" then
		table.insert(ret, string.format("%s{", indent(level)))
	else
		table.insert(ret, string.format("%s%s = {", indent(level), keystr(key)))
	end
	for k, v in clsStorage:StoragePairs(tbl) do
		if type(v) == 'table' then
			table.insert(ret, repr(v, level + 1, k))
		elseif type(v) == 'number' then
			table.insert(ret, string.format("%s%s = %s,",
				indent(level+1), keystr(k), tostring(v)))
		elseif type(v) == 'string' then
			table.insert(ret, string.format("%s%s = %q,",
				indent(level+1), keystr(k), v))
		elseif type(v) == 'boolean' then
			table.insert(ret, string.format("%s%s = %s,",
				indent(level+1), keystr(k), tostring(v)))
		else
			error('unsupport type ' .. type(v))
		end
	end
	table.insert(ret, string.format("%s},", indent(level)))
	return table.concat(ret, '\n')
end

clsStorage = {}
clsStorage.__index = clsStorage

function clsStorage:New()
	local obj = {
		storage = {},
	}
	setmetatable(obj, self)
	return obj
end

function clsStorage:Save(value)
	if type(value) == 'table' then
		return self:SaveTable(value)
	elseif type(value) == 'string' then
		return self:SaveString(value)
	else
		error("can't directly save "..type(value))
	end
end

function clsStorage:SaveTable(value)
	assert(value.__data)
	if value.__data == 'list' then
		return self:SaveList(value)
	end
	local content = {}
	table.insert(content, "table")
	for i, k in ipairs(value.__data) do
		v = value[k]
		if type(v) == "table" then
			local id = self:SaveTable(v)
			table.insert(content, string.format("t:%s=%s", k, id))
		elseif type(v) == "number" then
			table.insert(content, string.format("n:%s=%s", k, tostring(v)))
		elseif type(v) == "boolean" then
			table.insert(content, string.format("b:%s=%s", k, tostring(v)))
		elseif type(v) == "string" then
			local id = self:SaveString(v)
			table.insert(content, string.format("s:%s=%s", k, id))
		end
	end
	local value = table.concat(content, "\n")
	local id = hash.repr(hash.md5(value))
	self.storage[id] = value
	return id
end

function clsStorage:SaveList(value)
	local content = {}
	table.insert(content, "list")
	for i, v in ipairs(value) do
		if type(v) == "table" then
			local id = self:SaveTable(v)
			table.insert(content, string.format("t:%s", id))
		elseif type(v) == "number" then
			table.insert(content, string.format("n:%s", tostring(v)))
		elseif type(v) == "boolean" then
			table.insert(content, string.format("b:%s", tostring(v)))
		elseif type(v) == "string" then
			local id = self:SaveString(v)
			table.insert(content, string.format("s:%s", id))
		end
	end
	local value = table.concat(content, "\n")
	local id = hash.repr(hash.md5(value))
	self.storage[id] = value
	return id
end

function clsStorage:SaveString(value)
	local content = {
		"string",
		value,
	}
	local value = table.concat(content, "\n")
	local id = hash.repr(hash.md5(value))
	self.storage[id] = value
	return id
end

function clsStorage:Load(id)
	local content = self.storage[id]
	local sep = string.find(content, "\n")
	local head = string.sub(content, 1, sep-1)
	local body = string.sub(content, sep+1)
	if head == "string" then
		return body
	elseif head == "table" then
		return self:LoadTable(id, body)
	elseif head == "list" then
		return self:LoadList(id, body)
	else
		error("unknow head: "..head)
	end
end

function clsStorage:LoadTable(id, body)
	local ret = {}
	local data = {}
	for line in body:gmatch("([^\n]+)\n?") do
		local t,k,v = line:match("(%a):(%w+)=(%w+)")
		if t == "t" then
			ret[k] = self:Load(v)
		elseif t == "s" then
			ret[k] = self:Load(v)
		elseif t == "n" then
			ret[k] = tonumber(v)
		elseif t == "b" then
			ret[k] = (v == "true")
		else
			error("unknow type " .. t)
		end
		table.insert(data, k)
	end
	ret.__data = data
	ret.__id = id
	return ret
end

function clsStorage:LoadList(id, body)
	local ret = {}
	local idx = 1
	for line in body:gmatch("([^\n]+)\n?") do
		local t,v = line:match("(%a):(%w+)")
		if t == "t" then
			ret[idx] = self:Load(v)
		elseif t == "s" then
			ret[idx] = self:Load(v)
		elseif t == "n" then
			ret[idx] = tonumber(v)
		elseif t == "b" then
			ret[idx] = (v == "true")
		else
			error("unknow type " .. t)
		end
		idx = idx + 1
	end
	ret.__data = 'list'
	ret.__id = id
	return ret
end

function clsStorage:StoragePairs(tbl)
	return coroutine.wrap(function()
		for k, v in pairs(tbl) do
			if not (type(k) == 'string' and k:find('^__')) then
				coroutine.yield(k, v)
			end
		end
	end)
end

function clsStorage:KeyRepr(k)
	if type(k) == 'number' then
		return '[' .. k .. ']'
	else
		return '.' .. k
	end
end

function clsStorage:IncPath(path, key)
	return path .. self:KeyRepr(key)
end

function clsStorage:DiffDelete(val, path, ret)
	assert(path)
	assert(path)
	if type(val) == 'table' then
		for k, v in self:StoragePairs(val) do
			self:DiffDelete(val[k], self:IncPath(path,k), ret)
		end
	else
		table.insert(ret.delete, {path, val})
	end
end

function clsStorage:DiffNew(val, path, ret)
	assert(path)
	assert(ret)
	if type(val) == 'table' then
		for k, v in self:StoragePairs(val) do
			self:DiffNew(val[k], self:IncPath(path,k), ret)
		end
	else
		table.insert(ret.new, {path, val})
	end
end

function clsStorage:DiffValue(base, val, path, ret)
	assert(path)
	assert(ret)
	if val == nil then
		self:DiffDelete(base, path, ret)
	end
	if type(base) == type(val) then
		if type(base) == 'table' then
			if base.__id == val.__id then return end
			for k, v in self:StoragePairs(base) do
				self:DiffValue(base[k], val[k], self:IncPath(path,k), ret)
				val[k] = nil
			end
			for k, v in self:StoragePairs(val) do
				self:DiffNew(val[k], self:IncPath(path,k), ret)
			end
		elseif type(base) == 'string' then
			if base == val then return end
			table.insert(ret.change, {path, base, val})
		elseif type(base) == 'number' then
			if base == val then return end
			table.insert(ret.change, {path, base, val})
		elseif type(base) == 'boolean' then
			if base == val then return end
			table.insert(ret.change, {path, base, val})
		end
	else
		self:DiffNew(val, path, ret)
		self:DiffDelete(base, path, ret)
	end
end

function clsStorage:Diff(id1, id2)
	local base = self:Load(id1)
	local val = self:Load(id2)
	local path = ""
	local ret = {
		new = {},
		delete = {},
		change = {},
	}
	self:DiffValue(base, val, path, ret)
	return ret
end

local store = clsStorage:New()

local user1 = {
	__data = {'age', 'name', 'married', 'items' },
	age = 13,
	name = "fff",
	married = false,
	items = {
		__data = 'list',
		[1] = {
			__data = {'name'},
			name = "blade",
		},
		[2] = {
			__data = {'name'},
			name = "armor",
		},
	},
}
local user2 = {
	__data = {'age', 'name', 'married', 'items' },
	age = 13,
	name = "sss",
	married = false,
	items = {
		__data = 'list',
		[1] = {
			__data = {'name'},
			name = "sword",
		},
		[2] = {
			__data = {'name'},
			name = "armor",
		},
	},
}
local user3 = {
	__data = {'age', 'name', 'married', 'items' },
	age = 13,
	name = "sss",
	married = false,
	items = "name",
}
local id1 = store:Save(user1)
local id2 = store:Save(user2)
local id3 = store:Save(user3)

local count = 0
for k, v in pairs(store.storage) do
	count = count + #k + #v
	--print(k)
	--print('--------')
	--print(v)
	--print('--------')
end
print('save used: '..count)

print('load ..........')

local luser1 = store:Load(id1)
print(repr(luser1))

local luser2 = store:Load(id2)
print(repr(luser2))

local ret = store:Diff(id1, id3)
print(repr(ret))