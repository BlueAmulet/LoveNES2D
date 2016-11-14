--[[
Nintendo Entertainment System emulator for Love2D
Memory Emulation

By Gamax92
--]]

local memory = {}
for i = 0, 2047 do
	memory[i] = i % 8 < 4 and 0 or 255
end

local function readRam(address)
	return memory[address]
end

local function writeRam(address, value)
	memory[address] = value
end

NES.ram = {
}

NES.bus.register(0, 0x2000, readRam, writeRam, 0x7FF)
