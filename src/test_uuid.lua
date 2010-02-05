require 'uuid'

arg = {...}
math.randomseed(os.time())
local sum = 0
local min = 999999999
local times = 1

for j = 1, times do
	local mem = {}
	local p
	for i = 1, 10 do
		--local ret = math.random(tonumber(arg[1]))
		local ret = uuid.new()
		--print(ret)
		if mem[ret] then
			--print('collision@'..i)
			p = i
			break
		end
		mem[ret] = true
		p = i
	end
	if p < min then min = p end
	sum = sum + p
end

print('average is '..sum/times)
print('min is '..min)

id = uuid.new('t')
print(id)

print(uuid.time(id))

