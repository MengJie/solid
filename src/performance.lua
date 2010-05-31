require 'tip'
require 'profiler'

local tbl = {
	__data = {}
}

for i = 1, 100 do
	tbl['field'..i] = {
		__data = {}
	}
	table.insert(tbl.__data, 'field'..i)
	for j = 1, 10 do
		tbl['field'..i][j] = 'dsdlfkjaldjfadsjfalksdjaksdjfaksdjfkadsjkadslfjasdljfasdjfaata'..i..j
		table.insert(tbl['field'..i].__data, j)
	end
	for k = 11, 20 do
		tbl['field'..i][k] = k
		table.insert(tbl['field'..i].__data, k)
	end
end

local db = clsTableDB:New()
local store = clsStorage:New(db)
local id
--[[
	100 : 4.15s
--]]
profiler.start('result.out')
for i = 1, 10 do
	id = store:Save(tbl)
	local aaa = store:Load(id)
	--print(repr(aaa))
end
profiler.stop()

print(id)
print(os.clock())
local count = db:Size()
print('save used: '..count .. ' bytes')

