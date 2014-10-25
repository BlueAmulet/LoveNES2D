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
	require("cpu")
	
	NES.rom.reset()
	NES.ppu.reset()
	NES.cpu.reset()
	
	canvas = love.graphics.newCanvas(240,256)
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

local function drawCHR(addr,x,y,pal)
	local p1 = NES.ppu.palette[NES.pbus.readByte(pal)]
	local p2 = NES.ppu.palette[NES.pbus.readByte(pal+1)]
	local p3 = NES.ppu.palette[NES.pbus.readByte(pal+2)]
	for i=0, 7 do
		for n=0, 7 do
			--c = ((chr[addr+i] & (1 << n)) >> n) | ((chr[addr+i+8] & (1 << n)) >> (n-1))
			local c = bit.bor(bit.rshift(bit.band(NES.pbus.readByte(addr+i),bit.lshift(1,n)),n),bit.rshift(bit.band(NES.pbus.readByte(addr+i+8),bit.lshift(1,n)),n-1))
			if c ~= 0 then
				love.graphics.setColor(c == 1 and p1 or c == 2 and p2 or p3)
				love.graphics.point((7-n)+x,i+y)
			end
		end
	end
end

function love.draw()
	love.graphics.translate(0.5,0.5)
	love.graphics.setColor(255,255,255)
	local y = 10
	love.graphics.print("Frame #" .. framecount .. " at " .. os.date(),10,y) y=y+40
	love.graphics.print("A: " .. string.format("%02X",NES.cpu.cpu.registers.A),10,y) y=y+20
	love.graphics.print("X: " .. string.format("%02X",NES.cpu.cpu.registers.X),10,y) y=y+20
	love.graphics.print("Y: " .. string.format("%02X",NES.cpu.cpu.registers.Y),10,y) y=y+20
	love.graphics.print("SP: " .. string.format("$01%02X",NES.cpu.cpu.registers.SP),10,y) y=y+20
	love.graphics.print("PC: " .. string.format("$%04X",NES.cpu.cpu.registers.PC),10,y) y=y+20
	local by = y
	
	love.graphics.translate(0, 128)
	love.graphics.setColor(NES.ppu.palette[NES.pbus.readByte(0x3F00)])
	love.graphics.rectangle("fill",0,0,240,256)
	for y = 0,29 do
		for x = 0,31 do
			local amx = x%2
			local amy = y%2
			local attr = bit.band(bit.rshift(NES.ppu.VRam[math.floor(0x3C0+((y/2)*8)+(x/2))],amy == 0 and (amx == 0 and 0 or 2) or (amx == 0 and 4 or 6)),0x3)
			drawCHR(NES.ppu.VRam[(y*32)+x]*16,x*8,y*8,(attr*4)+0x3F01)
		end
	end
end
