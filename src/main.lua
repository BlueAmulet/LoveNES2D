--[[
Nintendo Entertainment System emulator for Love2D
By Gamax92
--]]

-- Modules will attach to here
NES = {
	file = "Zelda.NES",
	lfs = true,
	cycles = 0,
}

local framecount = 0

function love.load()
	-- Load modules
	require("bus")
	require("pbus")
	require("ram")
	require("rom")
	require("apu")
	require("ppu")
	require("joy")
	require("cpu")
	
	NES.rom.reset()
	NES.ppu.reset()
	NES.cpu.reset()
	
	NES.screen = love.image.newImageData(256, 240)
	NES.image = love.graphics.newImage(NES.screen)
end

-- Emulate one PPU frame
function love.update()
	NES.cycles = NES.cycles + 29781
	local crun = NES.cpu.run
	local prun = NES.ppu.run
	while (NES.cycles > 0) do
		-- Emulate CPU
		crun()
		-- Emulate PPU
		prun()
	end
	framecount = framecount + 1
end

function love.draw()
	love.graphics.setColor(255, 255, 255)
	local y = 10
	love.graphics.print("Frame #" .. framecount .. " at " .. os.date(), 10, y) y=y+20
	love.graphics.print("FPS: " .. love.timer.getFPS(), 10, y) y=y+40
	love.graphics.print("A: " .. string.format("%02X", NES.cpu.cpu.registers.A), 10, y) y=y+20
	love.graphics.print("X: " .. string.format("%02X", NES.cpu.cpu.registers.X), 10, y) y=y+20
	love.graphics.print("Y: " .. string.format("%02X", NES.cpu.cpu.registers.Y), 10, y) y=y+20
	love.graphics.print("SP: " .. string.format("$01%02X", NES.cpu.cpu.registers.SP), 10, y) y=y+20
	love.graphics.print("PC: " .. string.format("$%04X", NES.cpu.cpu.registers.PC), 10, y) y=y+20

	NES.ppu.draw()

	NES.image:refresh()
	love.graphics.draw(NES.image, 8, y)
end
