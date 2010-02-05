clsTableDB = {}
clsTableDB.__index = clsTableDB

function clsTableDB:New()
	local obj = {}
	setmetatable(obj, self)
	obj.store = {}
	return obj
end

function clsTableDB:Put(key, value)
	self.store[key] = value
end

function clsTableDB:Get(key)
	return self.store[key]
end

function clsTableDB:Out(key)
	self.store[key] = nil
end

