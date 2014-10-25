--[[
Nintendo Entertainment System emulator for Love2D
By Gamax92
--]]

-- Modules will attach to here
NES = {
	file = "nestest.nes",
	lfs = true,
	cycles = 0,
}

local framecount = 0

local start = 0

function love.load()
	-- Load modules
	require("bus")
	require("pbus")
	require("ram")
	require("rom")
	require("apu")
	require("ppu")
	require("cpu")
	
	NES.rom.reset()
	NES.ppu.reset()
	NES.cpu.reset()
	
	start = love.timer.getTime()
end

-- Emulate one PPU frame
function love.update()
	NES.cycles = NES.cycles + 29781
	while (NES.cycles > 0) do
		-- Emulate CPU
		NES.cpu.run()
		-- Emulate PPU
		NES.ppu.run()
	end
	framecount = framecount + 1
	if framecount == 60 then
		print(love.timer.getTime() - start)
	end
end

function love.draw()
	local y = 6
	love.graphics.print("Frame #" .. framecount .. " at " .. os.date(),6,y) y=y+24
	love.graphics.print("A: " .. string.format("%02X",NES.cpu.cpu.registers.A),6,y) y=y+12
	love.graphics.print("X: " .. string.format("%02X",NES.cpu.cpu.registers.X),6,y) y=y+12
	love.graphics.print("Y: " .. string.format("%02X",NES.cpu.cpu.registers.Y),6,y) y=y+12
	love.graphics.print("SP: " .. string.format("$01%02X",NES.cpu.cpu.registers.SP),6,y) y=y+12
	love.graphics.print("PC: " .. string.format("$%04X",NES.cpu.cpu.registers.PC),6,y) y=y+24
	local by = y
	
	for y = 0,29 do
		for x = 0,31 do
			love.graphics.print(string.format("%02X",NES.ppu.VRam[(y*32)+x]),(x*15)+6,(y*10)+by)
		end
	end
end
