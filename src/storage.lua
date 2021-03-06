require 'common'
require 'tabledb'

local table = table
local string = string

clsStorage = {}
clsStorage.__index = clsStorage

function clsStorage:New(db)
	local obj = { }
	setmetatable(obj, self)
	obj.db = db
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
		local v = value[k]
		local Type = type(v)
		if Type == "table" then
			local id = self:SaveTable(v)
			table.insert(content, string.format("t:%s=%s", k, id))
		elseif Type == "number" then
			table.insert(content, string.format("n:%s=%s", k, v))
		elseif Type == "boolean" then
			table.insert(content, string.format("b:%s=%s", k, v and 't' or 'f'))
		elseif Type == "string" then
			local id = self:SaveString(v)
			table.insert(content, string.format("s:%s=%s", k, id))
		end
	end
	local value = table.concat(content, "\n")
	local id = calchash(value)
	self.db:Put(id, value)
	return id
end

function clsStorage:SaveList(value)
	local content = {}
	table.insert(content, "list")
	for i, v in ipairs(value) do
		local Type = type(v)
		if Type == "table" then
			local id = self:SaveTable(v)
			table.insert(content, string.format("t:%s", id))
		elseif Type == "number" then
			table.insert(content, string.format("n:%s", v))
		elseif Type == "boolean" then
			table.insert(content, string.format("b:%s", v and 't' or 'f'))
		elseif Type == "string" then
			local id = self:SaveString(v)
			table.insert(content, string.format("s:%s", id))
		end
	end
	local value = table.concat(content, "\n")
	local id = calchash(value)
	self.db:Put(id, value)
	return id
end

function clsStorage:SaveString(value)
	local content = {
		"string",
		value,
	}
	local value = table.concat(content, "\n")
	local id = calchash(value)
	self.db:Put(id, value)
	return id
end

--	local commit = {
--		parents = {
--			self.tip,
--		},
--		ref = id,
--		user = username,
--		message = message,
--		time = time,
--	}
function clsStorage:SaveCommit(value)
	local msgid = self:SaveString(value.message)
	local userid = self:SaveString(value.user)
	local insert = table.insert
	local format = string.format
	local commit = {
		"commit",
	}
	for i, v in ipairs(value.parents) do
		insert(commit, format("p:%s",v))
	end
	insert(commit, format("r:%s", value.ref))
	insert(commit, format("t:%s", tostring(os.time())))
	insert(commit, format("u:%s", userid))
	insert(commit, format("m:%s", msgid))

	local str = table.concat(commit, "\n")
	local id = calchash(str)
	self.db:Put(id, str)
	return id
end

function clsStorage:Load(id)
	local content = self.db:Get(id)
	local sep = string.find(content, "\n")
	local head, body
	if sep then
		head = string.sub(content, 1, sep-1)
		body = string.sub(content, sep+1)
	else
		head, body = content, ""
	end
	if head == "string" then
		return body, head
	elseif head == "table" then
		return self:LoadTable(id, body), head
	elseif head == "list" then
		return self:LoadList(id, body), head
	elseif head == "commit" then
		return self:LoadCommit(id, body), head
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
			ret[k] = (v == "t")
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
			ret[idx] = (v == "t")
		else
			error("unknow type " .. t)
		end
		idx = idx + 1
	end
	ret.__data = 'list'
	ret.__id = id
	return ret
end

--	local commit = {
--		parents = {
--			self.tip,
--		},
--		ref = id,
--		message = message,
--		time = time,
--	}
function clsStorage:LoadCommit(id, body)
	local ret = {
		parents = {}
	}
	for line in body:gmatch("([^\n]+)\n?") do
		local t,v = line:match("(%a):(%w+)")
		if t == "p" then
			table.insert(ret.parents, v)
		elseif t == "r" then
			ret.ref = v
		elseif t == "t" then
			ret.time = tonumber(v)
		elseif t == "m" then
			ret.message = self:Load(v)
		elseif t == "u" then
			ret.user = self:Load(v)
		else
			error("unknow type of commit " .. t)
		end
	end
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
		table.insert(ret.delete, {path})
	else
		table.insert(ret.delete, {path, val})
	end
end

function clsStorage:DiffNew(val, path, ret)
	assert(path)
	assert(ret)
	if type(val) == 'table' then
		table.insert(ret.new, {path})
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
	elseif type(base) == type(val) then
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

function clsStorage:NewTip(name)
	self.db:Put(name, "0")
	return self:GetTip(name)
end

function clsStorage:GetTip(name)
	return self.db:Get(name)
end

function clsStorage:UpdateTip(name, old, new)
	if old ~= self.db:Get(name) then
		return false, 'need update'
	end
	self.db:Put(name, new)
	return new
end

function clsStorage:Lock(tip)
end
function clsStorage:Unlock(tip)
end

