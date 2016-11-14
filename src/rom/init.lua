--[[
Nintendo Entertainment System emulator for Love2D
Cartridge Emulation and Mapper Redirector

By Gamax92
--]]

-- Open ROM
local fileobj, err
if NES.lfs then -- love.filesystem.newFile
	fileobj, err = love.filesystem.newFile(NES.file, "r")
	if not fileobj then
		error("[NES.rom] " .. err)
	end
else -- lua io.open
	fileobj = io.open(NES.file, "rb")
	if not fileobj then
		error("[NES.rom] Failed to open '" .. NES.file .. "'")
	end
end

-- Parse header
local data = fileobj:read(16)
local header = {
	magic = data:sub(1, 4),
	prgsize = data:byte(5) * 16384,
	chrsize = data:byte(6) * 8192,
	flag6 = bit.band(data:byte(7), 0xF),
	flag7 = bit.band(data:byte(8), 0xF),
	prgram = math.max(data:byte(9), 1) * 8192,
	flag9 = data:byte(10),
	flag10 = data:byte(11),
	-- Helpers
	trainer = bit.band(data:byte(7), 4) > 0,
	mirror = bit.band(data:byte(7), 9),
}

-- Specific Header formats
if data:sub(13, 16) ~= "\0\0\0\0" and bit.band(header.flag7, 12) ~= 8 then -- Junk Mapper
	header.mapper = bit.band(data:byte(7), 0xF0)/16
elseif data:sub(13, 16) ~= "\0\0\0\0" and bit.band(header.flag7, 12) == 8 then -- NES 2.0
	error("NES 2.0 format unsupported, yet")
else -- Okay mapper
	header.mapper = bit.band(data:byte(8), 0xF0) + (bit.band(data:byte(7), 0xF0)/16)
end

-- Store Trainer/PRG/CHR blocks
local blocks = {}
if header.trainer then
	if fileobj.tell then -- LFS fileobj
		fileobj:seek(16)
	else
		fileobj:seek("set", 16)
	end
	blocks.trainer = { fileobj:read(512):byte(1, -1) }
else
	blocks.trainer = {}
end
local romaddress = 16 + (trainer and 512 or 0)
if fileobj.tell then -- LFS fileobj
	fileobj:seek(romaddress)
else
	fileobj:seek("set", romaddress)
end
blocks.prg = {}
for i = 1, header.prgsize, 512 do
	local tmp = { fileobj:read(512):byte(1, -1) }
	for i = 1, 512 do
		blocks.prg[#blocks.prg + 1] = tmp[i]
	end
end
blocks.chr = {}
if header.chrsize > 0 then
	local romaddress = 16 + (trainer and 512 or 0) + header.prgsize
	if fileobj.tell then -- LFS fileobj
		fileobj:seek(romaddress)
	else
		fileobj:seek("set", romaddress)
	end
	for i = 1, header.chrsize, 512 do
		local tmp = { fileobj:read(512):byte(1, -1) }
		for i = 1, 512 do
			blocks.chr[#blocks.chr + 1] = tmp[i]
		end
	end
end

-- Add to Emulator
NES.rom = {
	fileobj = fileobj,
	header = header,
	blocks = blocks,
}

local mirrorName = {
	[0] = "horizontal",
	[1] = "vertical",
	[8] = "4 screen",
	[9] = "4 screen",
}

print("[NES.rom] PRG size " .. header.prgsize .. " found")
if header.chrsize == 0 then
	print("[NES.rom] CHR memory found")
else
	print("[NES.rom] CHR size " .. header.chrsize .. " found")
end
print("[NES.rom] Mirroring " .. mirrorName[header.mirror] .. " ")

print("[NES.rom] Loading rom of mapper " .. header.mapper)

require("rom.mapper." .. header.mapper)
