local nlog = {}
local olog = {}
local args = { ... }
if #args ~= 2 then
	print("Usage: compare.lua file1 file2")
end

for line in io.lines(args[1]) do
	nlog[#nlog + 1] = line
end
for line in io.lines(args[2]) do
	olog[#olog + 1] = line
end
local min = math.min(#nlog,#olog)
for i = 1,min do
	local l1 = nlog[i]:sub(1,16) .. " " .. nlog[i]:sub(48,73)
	local l2 = olog[i]:sub(1,16) .. " " .. olog[i]:sub(48,73)
	if l1 ~= l2 then
		for j = math.max(i-10,1),math.max(i-1,1) do
			print(nlog[j])
		end
		print("----")
		print("N: " .. nlog[i])
		print("O: " .. olog[i])
		print("i: " .. i)
		break
	end
end

