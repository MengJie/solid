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

function calchash(value)
	return hash.repr(hash.md5(value))
end

function repr(tbl, key, level)
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
			table.insert(ret, repr(v, k, level + 1))
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
		ref = {},
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
	local id = calchash(value)
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
	local id = calchash(value)
	self.storage[id] = value
	return id
end

function clsStorage:SaveString(value)
	local content = {
		"string",
		value,
	}
	local value = table.concat(content, "\n")
	local id = calchash(value)
	self.storage[id] = value
	return id
end

--	local commit = {
--		parents = {
--			self.tip,
--		},
--		ref = id,
--		message = message,
--		time = time,
--	}
function clsStorage:SaveCommit(value)
	local msgid = self:SaveString(value.message)
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
	insert(commit, format("m:%s", msgid))

	local str = table.concat(commit, "\n")
	local id = calchash(str)
	self.storage[id] = str
	return id
end

function clsStorage:Load(id)
	local content = self.storage[id]
	local sep = string.find(content, "\n")
	local head, body
	if sep then
		head = string.sub(content, 1, sep-1)
		body = string.sub(content, sep+1)
	else
		head, body = content, ""
	end
	if head == "string" then
		return body
	elseif head == "table" then
		return self:LoadTable(id, body)
	elseif head == "list" then
		return self:LoadList(id, body)
	elseif head == "commit" then
		return self:LoadCommit(id, body)
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
	self.ref[name] = "0"
	return self:GetTip(name)
end

function clsStorage:GetTip(name)
	return self.ref[name]
end

function clsStorage:UpdateTip(name, old, new)
	if old ~= self.ref[name] then
		return false, 'need update'
	end
	self.ref[name] = new
	return new
end

function clsStorage:Lock(tip)
end
function clsStorage:Unlock(tip)
end

clsRepos = {}
clsRepos.__index = clsRepos

function clsRepos:New(tipname, store)
	local obj = {}
	setmetatable(obj, self)
	obj.store = store
	obj.tipname = tipname
	obj.tip = store:GetTip(tipname)
	if obj.tip == nil then
		obj.tip = store:NewTip(tipname)
	end
	return obj
end

function clsRepos:Commit(value, message)
	local id = self.store:Save(value)
	local commit = {
		parents = {
			self.tip,
		},
		ref = id,
		message = message,
		time = os.time(),
	}
	local ntip = self.store:SaveCommit(commit)
	local isok, msg = self.store:UpdateTip(self.tipname, self.tip, ntip)
	if not isok then
		error(msg)
	end
	self.tip = ntip
	return self.tip
end

function clsRepos:Log(count)
	local tipqueue = {self.tip}
	while #tipqueue > 0 do
		local tip = table.remove(tipqueue, 1)
		if tip == "0" then return end
		local commit = self.store:Load(tip)
		for i, v in ipairs(commit.parents) do
			table.insert(tipqueue, v)
		end
		print("commit: "..tip)
		for i, v in ipairs(commit.parents) do
			print("parent: "..v)
		end
		print("ref:    "..commit.ref)
		print("user:   "..self.tipname)
		print("date:   "..os.date("%D %T", commit.time))
		print("")
		print(commit.message)
		print("")
	end
end

function clsRepos:CheckOut(commitid)
	commitid = commitid or self.tip
	local commit = self.store:Load(commitid)
	local value = self.store:Load(commit.ref)
	return value
end

function clsRepos:Diff(base, cur)
	local basev = self:CheckOut(base)
	local curv = self:CheckOut(cur)
	local path = ""
	local ret = {
		new = {},
		delete = {},
		change = {},
	}
	self.store:DiffValue(basev, curv, path, ret)
	return ret
end

local store = clsStorage:New()
local repos = clsRepos:New("inmouse@gmail.com", store)

local user = {
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
v1 = repos:Commit(user, "create user.")

user.name = 'sss'
v2 = repos:Commit(user, "change name.")

user.items[1].name = 'sword'
v3 = repos:Commit(user, "change item name.")

user.items = "name"
v4 = repos:Commit(user, "error operation.")

user.items = { __data = 'list' }
v5 = repos:Commit(user, "recover item package.")

repos:Log(5)
print(repr(repos:CheckOut(v1), "v1"))
print(repr(repos:CheckOut(v2), "v2"))
print(repr(repos:CheckOut(v3), "v3"))
print(repr(repos:CheckOut(v4), "v4"))
print(repr(repos:CheckOut(v5), "v5"))

print(repr(repos:Diff(v4, v2)))

--print(repr(store.storage))
--local id1 = store:Save(user1)
--local id2 = store:Save(user2)
--local id3 = store:Save(user3)
--
local count = 0
for k, v in pairs(store.storage) do
	count = count + #k + #v
	--print(k)
	--print('--------')
	--print(v)
	--print('--------')
end
print('save used: '..count .. ' bytes')
--
--print('load ..........')
--
--local luser1 = store:Load(id1)
--print(repr(luser1, 'user1'))
--
--local luser2 = store:Load(id2)
--print(repr(luser2, 'user2'))
--
--local luser3 = store:Load(id3)
--print(repr(luser3, 'user3'))
--
--local ret = store:Diff(id1, id3)
--print(repr(ret))
