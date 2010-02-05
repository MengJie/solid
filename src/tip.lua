require "storage"

clsTip = {}
clsTip.__index = clsTip

function clsTip:New(tipname, store)
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

function clsTip:Commit(value, message)
	local id = self.store:Save(value)
	local commit = {
		parents = {
			self.tip,
		},
		ref = id,
		time = os.time(),
		user = self.tipname,
		message = message,
	}
	local ntip = self.store:SaveCommit(commit)
	local isok, msg = self.store:UpdateTip(self.tipname, self.tip, ntip)
	if not isok then
		error(msg)
	end
	self.tip = ntip
	return self.tip
end

function clsTip:ShowCommit(commit, id)
	print("commit: "..id)
	for i, v in ipairs(commit.parents) do
		print("parent: "..v)
	end
	print("ref:    "..commit.ref)
	print("user:   "..commit.user)
	print("date:   "..os.date("%D %T", commit.time))
	print("")
	print(commit.message)
	print("")
end

function clsTip:Log(count)
	local tipqueue = {self.tip}
	while #tipqueue > 0 and count > 0 do
		local tip = table.remove(tipqueue, 1)
		if tip == "0" then return end
		local commit = self.store:Load(tip)
		for i, v in ipairs(commit.parents) do
			table.insert(tipqueue, v)
		end
		self:ShowCommit(commit, tip)
		count = count - 1
	end
end

function clsTip:CheckOut(commitid)
	commitid = commitid or self.tip
	local commit = self.store:Load(commitid)
	local value = self.store:Load(commit.ref)
	return value
end

function clsTip:Diff(base, cur)
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

function clsTip:Show(id)
	local val, tp = self.store:Load(id)
	if tp == 'string' then
		print(val)
	elseif tp == 'table' then
		print(repr(val))
	elseif tp == 'list' then
		print(repr(val))
	elseif tp == 'commit' then
		self:ShowCommit(val, id)
		-- TODO: add diff
	end
end

