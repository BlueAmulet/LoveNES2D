--[[
Nintendo Entertainment System emulator for Love2D
PPU Memory Map Emulation

By Gamax92
--]]

local _pbus = {
	map = {
	},
	last = 0xFF,
}

NES.pbus = {
	-- Read from "Device"
	readByte = function(address)
		address = address % 16384
		for i = 1,#_pbus.map do
			map = _pbus.map[i]
			if map[1] <= address and map[1] + map[2] > address then
				_pbus.last = map[3](bit.band(address, map[5]))
				return _pbus.last
			end
		end
		return _pbus.last
	end,
	-- Write to "Device"
	writeByte = function(address, value)
		address = address % 16384
		value = value % 256
		for i = 1,#_pbus.map do
			map = _pbus.map[i]
			if map[1] <= address and map[1] + map[2] > address then
				map[4](bit.band(address, map[5]), value)
				break
			end
		end
	end,
	-- Add "Device" to map
	register = function(address, length, read, write, mask)
		_pbus.map[#_pbus.map + 1] = {address, length, read, write, mask}
	end,
	pbus = _pbus
}
