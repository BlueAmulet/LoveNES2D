--[[
Nintendo Entertainment System emulator for Love2D
Mapper 0 Emulation

By Gamax92
--]]

--print("Mapper 0 Emulation loaded")

local header = NES.rom.header
local blocks = NES.rom.blocks

-- Verify PRG size
if header.prgsize ~= 8192 and header.prgsize ~= 16384 and header.prgsize ~= 32768 then
	error("[NES.rom.mapper.0] PRG size " .. header.prgsize .. " unsupported")
end

-- Verify CHR size
if header.chrsize ~= 0 and header.chrsize ~= 8192 then
	error("[NES.rom.mapper.0] CHR size " .. header.chrsize .. " unsupported")
end

local function readRom(address)
	return blocks.prg[address+1]
end

-- We don't do anything on "RESET"
NES.rom.reset = function()
end

-- CHR Mapping
local readCHR, writeCHR

if header.chrsize == 0 then
	local CHR_RAM = {}
	for i = 0, 8191 do
		CHR_RAM[i] = 0
	end
	function readCHR(address)
		return CHR_RAM[address]
	end
	function writeCHR(address, value)
		CHR_RAM[address] = value
	end
else
	function readCHR(address)
		return blocks.chr[address+1]
	end

	function writeCHR(address, value)
		-- ROM is not writable
	end
end

-- NameTable Mapping
local readNT, writeNT
if header.mirror == 0 then -- Horizontal Mirroring
	function readNT(address)
		if address >= 2048 then
			address = address - 1024
		end
		return NES.ppu.VRam[address]
	end
	function writeNT(address, value)
		if address >= 2048 then
			address = address - 1024
		end
		NES.ppu.VRam[address] = value
	end
elseif header.mirror == 1 then -- Vertical Mirroring
	function readNT(address)
		return NES.ppu.VRam[address]
	end
	function writeNT(address, value)
		NES.ppu.VRam[address] = value
	end
else -- 4 Screen Mirroring
	local ENTRam = {}
	for i = 0, 2047 do
		ENTRam[i] = 0
	end
	function readNT(address)
		if address >= 2048 then
			return ENTRam[address-2048]
		else
			return NES.ppu.VRam[address]
		end
	end
	function writeNT(address, value)
		if address >= 2048 then
			ENTRam[address-2048]=value
		else
			NES.ppu.VRam[address]=value
		end
	end
end


-- Register ROM in bus
NES.bus.register(0x8000, 0x8000, readRom, function() end, header.prgsize - 1)

-- Register CHR ROM in ppu-bus
NES.pbus.register(0x0000, 0x2000, readCHR, writeCHR, 0x1FFF)
if header.mirror == 0 then -- Horizontal Mirroring
	NES.pbus.register(0x2000, 0x1000, readNT, writeNT, 0xBFF)
elseif header.mirror == 1 then -- Vertical Mirroring
	NES.pbus.register(0x2000, 0x1000, readNT, writeNT, 0x7FF)
else -- 4 Screen Mirroring
	NES.pbus.register(0x2000, 0x1000, readNT, writeNT, 0xFFF)
end
