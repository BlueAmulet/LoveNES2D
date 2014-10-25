--[[
Nintendo Entertainment System emulator for Love2D
Pixel Processing Unit Emulation

By Gamax92
--]]

local _ppu = {
	last = 0,
	lastcycle = 0,
	vbstart = false,
	ctrl = {
		baseaddr = 0,
		xscroll = 0,
		yscroll = 0,
		increment = 0,
		spta = 0,
		bpta = 0,
		spritesize = 0,
		mode = 0,
		nmi = 0,
	},
	mask = {
		grayscale = 0,
		bgeight = 0,
		spriteeight = 0,
		bgshow = 0,
		spritesshow = 0,
		intensered = 0,
		intensegreen = 0,
		intenseblue = 0,
	},
	camx = 0,
	camy = 0,
	oamaddr = 0,
	ppuaddr = 0,
	camwrite = false,
	ppuwrite = false,
}

local VRam = {}
for i = 0,2047 do
	VRam[i] = 0
end

local PalRam = {}
for i = 0,31 do	
	PalRam[i] = 0
end

local OAMRam = {}
for i = 0,255 do
	OAMRam[i] = 0
end

local function readPalRam(address)
	return PalRam[address]
end
local function writePalRam(address,value)
	PalRam[address] = value
end

local palette = {}
local palfile,err = love.filesystem.newFile("ppu/palette.act","r")
if not palfile then
	error("[NES.ppu] Failed to load palette\n" .. err)
end
for i = 0,63 do
	palette[i] = { palfile:read(3):byte(1,-1) }
end
palfile:close()

local function readCtrl(address)
	--print("[PPU:GET] " .. address)
	if address == 2 then -- Status
		local stat = _ppu.last + (vbstart and 128 or 0)
		vbstart = false
		return stat
	elseif address == 4 then -- OAM data
		-- TODO: Faulty Increment?
		local value = OAMRam[_ppu.oamaddr]
		_ppu.oamaddr = (_ppu.oamaddr + 1)%256
		return value
	elseif address == 7 then -- Data
		-- TODO: Non-VBlank Glitchy Read?
		local value = NES.pbus.readByte(_ppu.ppuaddr)
		if _ppu.ctrl.increment == 0 then
			_ppu.ppuaddr = (_ppu.ppuaddr+1)%16384
		else
			_ppu.ppuaddr = (_ppu.ppuaddr+32)%16384
		end
		return value
	else
		return NES.bus.bus.last
	end
end

local function writeCtrl(address,value)
	--print("[PPU:SET] " .. address .. " " .. value)
	_ppu.last = bit.band(value,31)
	if address == 0 then
		_ppu.ctrl.baseaddr   = bit.band(value,  3)
		_ppu.ctrl.xscroll    = bit.band(value,  1)
		_ppu.ctrl.yscroll    = bit.band(value,  2)
		_ppu.ctrl.increment  = bit.band(value,  4)
		_ppu.ctrl.spta       = bit.band(value,  8) * 512
		_ppu.ctrl.bpta       = bit.band(value, 16) * 256
		_ppu.ctrl.spritesize = bit.band(value, 32)
		_ppu.ctrl.mode       = bit.band(value, 64)
		_ppu.ctrl.nmi        = bit.band(value,128)
	elseif address == 1 then
		_ppu.mask.grayscale    = bit.band(value,  1)
		_ppu.mask.bgeight      = bit.band(value,  2)
		_ppu.mask.spriteeight  = bit.band(value,  4)
		_ppu.mask.bgshow       = bit.band(value,  8)
		_ppu.mask.spritesshow  = bit.band(value, 16)
		_ppu.mask.intensered   = bit.band(value, 32)
		_ppu.mask.intensegreen = bit.band(value, 64)
		_ppu.mask.intenseblue  = bit.band(value,128)
	elseif address == 3 then
		_ppu.oamaddr = value
	elseif address == 4 then
		-- TODO: Faulty Increment?
		-- TODO: Faulty Writes?
		OAMRam[_ppu.oamaddr] = value
		_ppu.oamaddr = (_ppu.oamaddr + 1)%256
	elseif address == 5 then
		if not _ppu.camwrite then -- X Address
			_ppu.camx = value
		else -- Y Address
			_ppu.camy = value
		end
		_ppu.camwrite = not _ppu.camwrite
	elseif address == 6 then
		if not _ppu.ppuwrite then -- High Byte
			_ppu.ppuaddr = (value*256) + (_ppu.ppuaddr%256)
		else -- Low Byte
			_ppu.ppuaddr = bit.band(_ppu.ppuaddr,0xFF00) + value
		end
		_ppu.ppuwrite = not _ppu.ppuwrite
	elseif address == 7 then
		-- TODO: Non-VBlank Glitchy Write?
		NES.pbus.writeByte(_ppu.ppuaddr, value)
		if _ppu.ctrl.increment == 0 then
			_ppu.ppuaddr = (_ppu.ppuaddr+1)%16384
		else
			_ppu.ppuaddr = (_ppu.ppuaddr+32)%16384
		end
	end
end

NES.ppu = {
	run = function()
		local lX = (_ppu.lastcycle*3)%341
		local lY = math.floor(262-((_ppu.lastcycle*3)/341))
	
		local cX = (NES.cycles*3)%341
		local cY = math.floor(262-((NES.cycles*3)/341))
		
		if _ppu.lastcycle > 2273 and NES.cycles <= 2273 then -- VBlank start
			vbstart = true
		end
		if _ppu.lastcycle <= 2273 and NES.cycles > 2273 then -- VBlank ended
			vbstart = false
		end
		_ppu.lastcycle = NES.cycles
	end,
	reset = function()
	end,
	ppu = _ppu,
	VRam = VRam,
	palette = palette,
}

-- Register ROM in bus
NES.bus.register(0x2000, 0x2000, readCtrl, writeCtrl, 7)

-- Register Memory in ppu-bus
NES.pbus.register(0x3F00, 0x00FF, readPalRam, writePalRam, 0x1F)
