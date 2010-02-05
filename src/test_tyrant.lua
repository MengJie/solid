require 'tokyotyrant'

local db = tokyotyrant.open('localhost', 20027)
for k in db:keys() do
	print(k)
end
