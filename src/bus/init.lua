--[[
Nintendo Entertainment System emulator for Love2D
Memory Map Emulation

By Gamax92
--]]

local _bus = {
	map = {
	},
	last = 0xFF
}

NES.bus = {
	-- Read from "Device"
	readByte = function(address)
		address = address % 65536
		for i = 1,#_bus.map do
			map = _bus.map[i]
			if map[1] <= address and map[1] + map[2] > address then
				_bus.last = map[3](bit.band(address, map[5]))
				if type(_bus.last) ~= "number" then
					print("Warning: Read a " .. type(_bus.last) .. " on " .. string.format("b%04X a%04X l%04X", map[1], address, map[2]))
					print("We will likely crash now ... Bye!")
				end
				return _bus.last
			end
		end
		return _bus.last
	end,
	-- Write to "Device"
	writeByte = function(address, value)
		address = address % 65536
		value = value % 256
		for i = 1,#_bus.map do
			map = _bus.map[i]
			if map[1] <= address and map[1] + map[2] > address then
				map[4](bit.band(address, map[5]), value)
				break
			end
		end
	end,
	-- Add "Device" to map
	register = function(address, length, read, write, mask)
		_bus.map[#_bus.map + 1] = {address, length, read, write, mask}
	end,
	bus = _bus
}
