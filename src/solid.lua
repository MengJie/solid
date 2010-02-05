require 'tip'

local store = clsStorage:New()
local repos = clsTip:New("inmouse@gmail.com", store)

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

print(repr(repos:Diff(v2, v3)))

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
