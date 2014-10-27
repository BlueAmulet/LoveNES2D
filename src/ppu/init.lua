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
	VRam[i] = 0xFF
end

local Buffer = {}

local PalRam = {}
for i = 0,31 do	
	PalRam[i] = 0
end

local OAMRam = {}
for i = 0,255 do
	OAMRam[i] = 0
end

local function readPalRam(address)
	if address == 0x10 or address == 0x14 or address == 0x18 or address == 0x1C then
		address = address - 0x10
	end
	return PalRam[address]
end
local function writePalRam(address,value)
	if address == 0x10 or address == 0x14 or address == 0x18 or address == 0x1C then
		address = address - 0x10
	end
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
		-- Clear Latch
		_ppu.camwrite = false
		_ppu.ppuwrite = false
		return stat
	elseif address == 4 then -- OAM data
		return OAMRam[_ppu.oamaddr]
	elseif address == 7 then -- Data
		-- TODO: Non-VBlank Glitchy Read?
		local value = NES.pbus.readByte(_ppu.ppuaddr)
		local ppuaddr = _ppu.ppuaddr
		if _ppu.ctrl.increment == 0 then
			_ppu.ppuaddr = (_ppu.ppuaddr+1)%16384
		else
			_ppu.ppuaddr = (_ppu.ppuaddr+32)%16384
		end
		if ppuaddr < 0x3F00 then
			if Buffer[ppuaddr] == nil then
				Buffer[ppuaddr] = math.random(0,255)
			end
			local cache = Buffer[ppuaddr]
			Buffer[ppuaddr] = value
			return cache
		else
			return value
		end
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

local function writeDMA(address,value)
	local base = value * 256
	for i = 0,255 do
		OAMRam[_ppu.oamaddr] = NES.bus.readByte(base+i)
		_ppu.oamaddr = (_ppu.oamaddr + 1)%256
	end
end

local function drawCHR(addr,x,y,pal,hflip,vflip)
	local p1 = palette[NES.pbus.readByte(pal)]
	local p2 = palette[NES.pbus.readByte(pal+1)]
	local p3 = palette[NES.pbus.readByte(pal+2)]
	for i=0, 7 do
		for n=0, 7 do
			--c = ((chr[addr+i] & (1 << n)) >> n) | ((chr[addr+i+8] & (1 << n)) >> (n-1))
			local c = bit.band(bit.rshift(NES.pbus.readByte(addr+i),n),1)+bit.band(n > 0 and bit.rshift(NES.pbus.readByte(addr+i+8),n-1) or bit.lshift(NES.pbus.readByte(addr+i+8),1),2)
			if c ~= 0 then
				love.graphics.setColor(c == 1 and p1 or c == 2 and p2 or p3)
				local sx = hflip and 0.5+n or 7.5-n
				local sy = vflip and 7.5-i or 0.5+i
				love.graphics.point(sx+x,sy+y)
			end
		end
	end
end

NES.ppu = {
	run = function()
		local lX = (_ppu.lastcycle*3)%341
		local lY = math.floor(262-((_ppu.lastcycle*3)/341))
	
		local cX = (NES.cycles*3)%341
		local cY = math.floor(262-((NES.cycles*3)/341))
		
		local set = 2065 -- Determined by vbl_clear_time.nes
		if _ppu.lastcycle > set and NES.cycles <= set then -- VBlank start
			vbstart = true
			if _ppu.ctrl.nmi ~= 0 then
				NES.cpu.cpu.ninterrupt = true
			end
		end
		if _ppu.lastcycle <= set and NES.cycles > set then -- VBlank ended
			vbstart = false
		end
		_ppu.lastcycle = NES.cycles
	end,
	draw = function()
		love.graphics.setColor(palette[NES.pbus.readByte(0x3F00)])
		love.graphics.rectangle("fill",0,0,256,240)
		for i = 63,0,-1 do -- Sprites draw backwards
			local base = i*4
			if OAMRam[base] < 0xEF then
				if bit.band(OAMRam[base+2],32) == 32 then -- Behind BG
					if _ppu.ctrl.spritesize == 0 then -- 8x8 sprites
						drawCHR((OAMRam[base+1]*16)+_ppu.ctrl.spta,OAMRam[base+3],OAMRam[base]+1,((OAMRam[base+2]%4)*4)+0x3F11,bit.band(OAMRam[base+2],64)>0,bit.band(OAMRam[base+2],128)>0)
					else -- 8x16 sprites
						local tile = (math.floor(OAMRam[base+1]/2)*8)+((OAMRam[base+1]%2)*4096)
						-- TODO: 8x16 sprites
					end
				end
			end
		end
		local xscroll = (_ppu.ctrl.xscroll*256)+_ppu.camx
		local yscroll = (_ppu.ctrl.yscroll*120)+_ppu.camy
		-- TODO: Only draw visible tiles
		love.graphics.translate(-xscroll,-yscroll)
		for by = 0,1 do
			for bx = 0,1 do
				local base = 0x2000 + (bx*0x400) + (by*0x800)
				for y = 0,29 do
					for x = 0,31 do
						local atx = math.floor(x/4)
						local aty = math.floor(y/4)
						local amx = math.floor((x-(atx*4))/2)
						local amy = math.floor((y-(aty*4))/2)
						local atb = 0x3C0
						local atr = NES.pbus.readByte(base+atb+(aty*8)+atx)
						local sa = amy == 0 and (amx == 0 and 0 or 2) or (amx == 0 and 4 or 6)
						local attr = bit.band(bit.rshift(atr,sa),0x3)
						drawCHR((NES.pbus.readByte(base+(y*32)+x)*16)+NES.ppu.ppu.ctrl.bpta,(x*8)+(bx*256),(y*8)+(by*240),(attr*4)+0x3F01,false,false)
					end
				end
			end
		end
		love.graphics.translate(xscroll,yscroll)
		for i = 63,0,-1 do -- Sprites draw backwards
			local base = i*4
			if OAMRam[base] < 0xEF then
				if bit.band(OAMRam[base+2],32) == 0 then -- Infront of BG
					if _ppu.ctrl.spritesize == 0 then -- 8x8 sprites
						drawCHR((OAMRam[base+1]*16)+_ppu.ctrl.spta,OAMRam[base+3],OAMRam[base]+1,((OAMRam[base+2]%4)*4)+0x3F11,bit.band(OAMRam[base+2],64)>0,bit.band(OAMRam[base+2],128)>0)
					else -- 8x16 sprites
						local tile = (math.floor(OAMRam[base+1]/2)*8)+((OAMRam[base+1]%2)*4096)
						print("Warning, 8x16 sprite")
						-- TODO: 8x16 sprites
					end
				end
			end
		end
		love.graphics.setColor(255, 255, 255, 255)
	end,
	reset = function()
		-- TODO: Reset stuff
	end,
	ppu = _ppu,
	VRam = VRam,
}

-- Register ROM in bus
NES.bus.register(0x2000, 0x2000, readCtrl, writeCtrl, 7)

-- OAM DMA
NES.bus.register(0x4014, 1, function() return NES.bus.bus.last end, writeDMA, 0)

-- Register Memory in ppu-bus
NES.pbus.register(0x3F00, 0x00FF, readPalRam, writePalRam, 0x1F)
