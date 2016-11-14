--[[
Nintendo Entertainment System emulator for Love2D
CPU Emulation

By Gamax92
--]]

-- Emulate Decimal mode? (NES doesn't)
_decimal = false

-- Stores CPU things like flags/registers/vectors
local _cpu
_cpu = {
	running = false,
	registers = {
		A  = 0x00,
		X  = 0x00,
		Y  = 0x00,
		SP = 0xFF,
		PC = 0x0000,
		flags = {
			C = false,
			Z = false,
			I = true,
			D = false,
			V = false,
			N = false,
		},
	},
	interrupt = false,
	ninterrupt = false,
	cycles = 0,
	getFlags = function()
		return 32 +
		(_cpu.registers.flags.C and 1 or 0) +
		(_cpu.registers.flags.Z and 2 or 0) +
		(_cpu.registers.flags.I and 4 or 0) +
		(_cpu.registers.flags.D and 8 or 0) +
		(_cpu.registers.flags.V and 64 or 0) +
		(_cpu.registers.flags.N and 128 or 0)
	end,
	setFlags = function(flags)
		_cpu.registers.flags.C = bit.band(flags, 1) ~= 0
		_cpu.registers.flags.Z = bit.band(flags, 2) ~= 0
		_cpu.registers.flags.I = bit.band(flags, 4) ~= 0
		_cpu.registers.flags.D = bit.band(flags, 8) ~= 0
		_cpu.registers.flags.V = bit.band(flags, 64) ~= 0
		_cpu.registers.flags.N = bit.band(flags, 128) ~= 0
	end,
}

local AM_IMPLIED = 1
local AM_IMMEDIATE = 2
local AM_ABSOLUTE = 3
local AM_ZEROPAGE = 4 
local AM_ACCUMULATOR = 5
local AM_ABSOLUTE_INDEXED_X = 6
local AM_ABSOLUTE_INDEXED_Y = 7
local AM_ZEROPAGE_INDEXED_X = 8
local AM_ZEROPAGE_INDEXED_Y = 9
local AM_INDIRECT = 10
local AM_PREINDEXED_INDIRECT = 11
local AM_POSTINDEXED_INDIRECT = 12
local AM_RELATIVE = 13

-- Borrowed from nesicide:
local opcode_size =
{
   1, -- AM_IMPLIED
   2, -- AM_IMMEDIATE
   3, -- AM_ABSOLUTE
   2, -- AM_ZEROPAGE
   1, -- AM_ACCUMULATOR
   3, -- AM_ABSOLUTE_INDEXED_X
   3, -- AM_ABSOLUTE_INDEXED_Y
   2, -- AM_ZEROPAGE_INDEXED_X
   2, -- AM_ZEROPAGE_INDEXED_Y
   3, -- AM_INDIRECT
   2, -- AM_PREINDEXED_INDIRECT
   2, -- AM_POSTINDEXED_INDIRECT
   2  -- AM_RELATIVE
}

local function unsigned2signed(value)
	if value >= 128 then
		value = value - 256
	end
	return value
end

local function signed2unsigned(value)
	if value < 0 then
		value = value + 256
	end
	return value
end

local function readOpcodeData(mode)
	    if mode == AM_IMPLIED then
	    error("[NES.cpu] Attempted to get data for Implied")
	elseif mode == AM_IMMEDIATE then
		return NES.bus.readByte(_cpu.registers.PC + 1)
	elseif mode == AM_ABSOLUTE then
		return bit.lshift(NES.bus.readByte(_cpu.registers.PC + 2), 8) + NES.bus.readByte(_cpu.registers.PC + 1)
	elseif mode == AM_ZEROPAGE then
		return NES.bus.readByte(_cpu.registers.PC + 1)
	elseif mode == AM_ACCUMULATOR then
		return _cpu.registers.A
	elseif mode == AM_ABSOLUTE_INDEXED_X then
		return bit.lshift(NES.bus.readByte(_cpu.registers.PC + 2), 8) + NES.bus.readByte(_cpu.registers.PC + 1) + _cpu.registers.X
	elseif mode == AM_ABSOLUTE_INDEXED_Y then
		return bit.lshift(NES.bus.readByte(_cpu.registers.PC + 2), 8) + NES.bus.readByte(_cpu.registers.PC + 1) + _cpu.registers.Y
	elseif mode == AM_ZEROPAGE_INDEXED_X then
		return bit.band(NES.bus.readByte(_cpu.registers.PC + 1) + _cpu.registers.X, 0xFF)
	elseif mode == AM_ZEROPAGE_INDEXED_Y then
		return bit.band(NES.bus.readByte(_cpu.registers.PC + 1) + _cpu.registers.Y, 0xFF)
	elseif mode == AM_INDIRECT then
		local address = bit.lshift(NES.bus.readByte(_cpu.registers.PC + 2), 8) + NES.bus.readByte(_cpu.registers.PC + 1)
		local base = bit.band(address, 0xFF00)
		return bit.lshift(NES.bus.readByte(base+(bit.band(address+1, 0xFF))), 8) + NES.bus.readByte(address)
	elseif mode == AM_PREINDEXED_INDIRECT then
		local address = NES.bus.readByte(_cpu.registers.PC + 1) + _cpu.registers.X
		return bit.lshift(NES.bus.readByte(bit.band(address+1, 0xFF)), 8) + NES.bus.readByte(bit.band(address, 0xFF))
	elseif mode == AM_POSTINDEXED_INDIRECT then
		local address = NES.bus.readByte(_cpu.registers.PC + 1)
		return bit.lshift(NES.bus.readByte(bit.band(address+1, 0xFF)), 8) + NES.bus.readByte(bit.band(address, 0xFF)) + _cpu.registers.Y
	elseif mode == AM_RELATIVE then
		return unsigned2signed(NES.bus.readByte(_cpu.registers.PC + 1))
	end
end

local function wrap8(value)
	while value < 0 do
		value = value + 256
	end
	return bit.band(value, 0xFF)
end

-- Opcodes
local op = {}

function op.ADC(mode)
	if _decimal and _cpu.registers.flags.D then
		error("Decimal mode unimplemented")
	else
		local tosum
		if mode == AM_IMMEDIATE then
			tosum = readOpcodeData(mode)
		else
			tosum = NES.bus.readByte(readOpcodeData(mode))
		end
		local value2 = _cpu.registers.A + tosum + (_cpu.registers.flags.C and 1 or 0)
		tosum = unsigned2signed(tosum)
		local value = unsigned2signed(_cpu.registers.A) + tosum + (_cpu.registers.flags.C and 1 or 0)
		_cpu.registers.A = bit.band(signed2unsigned(value), 0xFF)
		_cpu.registers.flags.C = value2 >= 256
		_cpu.registers.flags.Z = _cpu.registers.A == 0
		_cpu.registers.flags.V = value > 127 or value < -128
		_cpu.registers.flags.N = _cpu.registers.A >= 128
	end
end

function op.ANC(mode)
	local toand = readOpcodeData(mode)
	_cpu.registers.A = bit.band(_cpu.registers.A, toand)
	_cpu.registers.flags.C = _cpu.registers.A >= 128
	_cpu.registers.flags.Z = _cpu.registers.A == 0
	_cpu.registers.flags.N = _cpu.registers.A >= 128
end

function op.AND(mode)
	local toand
	if mode == AM_IMMEDIATE then
		toand = readOpcodeData(mode)
	else
		toand = NES.bus.readByte(readOpcodeData(mode))
	end
	_cpu.registers.A = bit.band(_cpu.registers.A, toand)
	_cpu.registers.flags.Z = _cpu.registers.A == 0
	_cpu.registers.flags.N = _cpu.registers.A >= 128
end

function op.ALR(mode)
	op.AND(mode)
	op.LSR(AM_ACCUMULATOR)
end

function op.ARR(mode)
	op.AND(mode)
	op.ROR(AM_ACCUMULATOR)
	local b5 = bit.band(_cpu.registers.A, 32) > 0
	local b6 = bit.band(_cpu.registers.A, 64) > 0
	if b5 and b6 then
		_cpu.registers.flags.C = true
		_cpu.registers.flags.V = false
	elseif not b5 and not b6 then
		_cpu.registers.flags.C = false
		_cpu.registers.flags.V = false
	elseif b5 and not b6 then
		_cpu.registers.flags.C = false
		_cpu.registers.flags.V = true
	elseif not b5 and b6 then
		_cpu.registers.flags.C = true
		_cpu.registers.flags.V = true
	end
end

function op.ASL(mode)
	local value, addr
	if mode == AM_ACCUMULATOR then
		value = _cpu.registers.A
	else
		addr = readOpcodeData(mode)
		value = NES.bus.readByte(addr)
	end
	local oldseven = value >= 128
	value = bit.band(value*2, 0xFF)
	if mode == AM_ACCUMULATOR then
		_cpu.registers.A = value
	else
		NES.bus.writeByte(addr, value)
	end
	_cpu.registers.flags.C = oldseven
	_cpu.registers.flags.Z = value == 0
	_cpu.registers.flags.N = value >= 128
end

function op.AXS(mode)
	-- TODO: FAIL
	local value = bit.band(_cpu.registers.A, _cpu.registers.X) - readOpcodeData(mode)
	_cpu.registers.X = bit.band(signed2unsigned(value), 0xFF)
	_cpu.registers.flags.C = value >= 0
end

function op.BCC(mode)
	local pos = readOpcodeData(mode)
	if not _cpu.registers.flags.C then
		_cpu.registers.PC = _cpu.registers.PC + pos
	end
end

function op.BCS(mode)
	local pos = readOpcodeData(mode)
	if _cpu.registers.flags.C then
		_cpu.registers.PC = _cpu.registers.PC + pos
	end
end

function op.BEQ(mode)
	local pos = readOpcodeData(mode)
	if _cpu.registers.flags.Z then
		_cpu.registers.PC = _cpu.registers.PC + pos
	end
end

function op.BIT(mode)
	local totest = NES.bus.readByte(readOpcodeData(mode))
	local value = bit.band(_cpu.registers.A, totest)

	_cpu.registers.flags.Z = value == 0
	_cpu.registers.flags.V = bit.band(totest, 64) ~= 0
	_cpu.registers.flags.N = bit.band(totest, 128) ~= 0
end

function op.BMI(mode)
	local pos = readOpcodeData(mode)
	if _cpu.registers.flags.N then
		_cpu.registers.PC = _cpu.registers.PC + pos
	end
end

function op.BNE(mode)
	local pos = readOpcodeData(mode)
	if not _cpu.registers.flags.Z then
		_cpu.registers.PC = _cpu.registers.PC + pos
	end
end

function op.BPL(mode)
	local pos = readOpcodeData(mode)
	if not _cpu.registers.flags.N then
		_cpu.registers.PC = _cpu.registers.PC + pos
	end
end

function op.BRK(mode)
	local tojump = NES.bus.readByte(0xFFFE) + bit.lshift(NES.bus.readByte(0xFFFF), 8)
	local retaddr = _cpu.registers.PC + 2
	NES.bus.writeByte(wrap8(_cpu.registers.SP-0)+256, math.floor(retaddr/256))
	NES.bus.writeByte(wrap8(_cpu.registers.SP-1)+256, bit.band(retaddr, 0xFF))
	NES.bus.writeByte(wrap8(_cpu.registers.SP-2)+256, _cpu.getFlags() + 16)
	_cpu.registers.flags.I = true
	_cpu.registers.SP = wrap8(_cpu.registers.SP-3)
	_cpu.registers.PC = tojump - 1
end

function op.BVC(mode)
	local pos = readOpcodeData(mode)
	if not _cpu.registers.flags.V then
		_cpu.registers.PC = _cpu.registers.PC + pos
	end
end

function op.BVS(mode)
	local pos = readOpcodeData(mode)
	if _cpu.registers.flags.V then
		_cpu.registers.PC = _cpu.registers.PC + pos
	end
end

function op.CLC(mode)
	_cpu.registers.flags.C = false
end

function op.CLD(mode)
	_cpu.registers.flags.D = false
end

function op.CLI(mode)
	_cpu.registers.flags.I = false
end

function op.CLV(mode)
	_cpu.registers.flags.V = false
end

function op.CMP(mode)
	local tocompare
	if mode == AM_IMMEDIATE then
		tocompare = readOpcodeData(mode)
	else
		tocompare = NES.bus.readByte(readOpcodeData(mode))
	end
	local value = wrap8(_cpu.registers.A-tocompare)
	_cpu.registers.flags.C = _cpu.registers.A >= tocompare
	_cpu.registers.flags.Z = _cpu.registers.A == tocompare
	_cpu.registers.flags.N = value >= 128
end

function op.CPX(mode)
	local tocompare
	if mode == AM_IMMEDIATE then
		tocompare = readOpcodeData(mode)
	else
		tocompare = NES.bus.readByte(readOpcodeData(mode))
	end
	local value = wrap8(_cpu.registers.X-tocompare)
	_cpu.registers.flags.C = _cpu.registers.X >= tocompare
	_cpu.registers.flags.Z = _cpu.registers.X == tocompare
	_cpu.registers.flags.N = value >= 128
end

function op.CPY(mode)
	local tocompare
	if mode == AM_IMMEDIATE then
		tocompare = readOpcodeData(mode)
	else
		tocompare = NES.bus.readByte(readOpcodeData(mode))
	end
	local value = wrap8(_cpu.registers.Y-tocompare)
	_cpu.registers.flags.C = _cpu.registers.Y >= tocompare
	_cpu.registers.flags.Z = _cpu.registers.Y == tocompare
	_cpu.registers.flags.N = value >= 128
end

function op.DCP(mode)
	op.DEC(mode)
	op.CMP(mode)
end

function op.DEC(mode)
	local addr = readOpcodeData(mode)
	local value = wrap8(NES.bus.readByte(addr) - 1)
	NES.bus.writeByte(addr, value)
	_cpu.registers.flags.Z = value == 0
	_cpu.registers.flags.N = value >= 128
end

function op.DEX(mode)
	_cpu.registers.X = _cpu.registers.X - 1
	if _cpu.registers.X < 0 then
		_cpu.registers.X = _cpu.registers.X + 256
	end
	_cpu.registers.flags.Z = _cpu.registers.X == 0
	_cpu.registers.flags.N = _cpu.registers.X >= 128
end

function op.DEY(mode)
	_cpu.registers.Y = _cpu.registers.Y - 1
	if _cpu.registers.Y < 0 then
		_cpu.registers.Y = _cpu.registers.Y + 256
	end
	_cpu.registers.flags.Z = _cpu.registers.Y == 0
	_cpu.registers.flags.N = _cpu.registers.Y >= 128
end

function op.DOP(mode)
end

function op.EOR(mode)
	local toxor
	if mode == AM_IMMEDIATE then
		toxor = readOpcodeData(mode)
	else
		toxor = NES.bus.readByte(readOpcodeData(mode))
	end
	_cpu.registers.A = bit.bxor(_cpu.registers.A, toxor)
	_cpu.registers.flags.Z = _cpu.registers.A == 0
	_cpu.registers.flags.N = _cpu.registers.A >= 128
end

function op.INC(mode)
	local address = readOpcodeData(mode)
	local value = NES.bus.readByte(address)
	value = bit.band(value + 1, 0xFF)
	NES.bus.writeByte(address, value)
	_cpu.registers.flags.Z = value == 0
	_cpu.registers.flags.N = value >= 128
end

function op.ISB(mode)
	op.INC(mode)
	op.SBC(mode)
end

function op.INX(mode)
	_cpu.registers.X = bit.band(_cpu.registers.X + 1, 0xFF)
	_cpu.registers.flags.Z = _cpu.registers.X == 0
	_cpu.registers.flags.N = _cpu.registers.X >= 128
end

function op.INY(mode)
	_cpu.registers.Y = bit.band(_cpu.registers.Y + 1, 0xFF)
	_cpu.registers.flags.Z = _cpu.registers.Y == 0
	_cpu.registers.flags.N = _cpu.registers.Y >= 128
end

function op.JMP(mode)
	local tojump = readOpcodeData(mode)
	_cpu.registers.PC = tojump - 3 -- 3 counteracts PC increment
end

function op.JSR(mode)
	local tojump = readOpcodeData(mode)
	local retaddr = _cpu.registers.PC + 2
	NES.bus.writeByte(wrap8(_cpu.registers.SP-0)+256, math.floor(retaddr/256))
	NES.bus.writeByte(wrap8(_cpu.registers.SP-1)+256, bit.band(retaddr, 0xFF))
	_cpu.registers.SP = wrap8(_cpu.registers.SP-2)
	_cpu.registers.PC = tojump - 3 -- 3 counteracts PC increment
end

function op.KIL()
	_cpu.running = false
end

function op.LAX(mode)
	local toload
	if mode == AM_IMMEDIATE then
		toload = readOpcodeData(mode)
	else
		toload = NES.bus.readByte(readOpcodeData(mode))
	end
	_cpu.registers.A = toload
	_cpu.registers.X = toload
	_cpu.registers.flags.Z = toload == 0
	_cpu.registers.flags.N = toload >= 128
end

function op.LDA(mode)
	local toload
	if mode == AM_IMMEDIATE then
		toload = readOpcodeData(mode)
	else
		toload = NES.bus.readByte(readOpcodeData(mode))
	end
	_cpu.registers.A = toload
	_cpu.registers.flags.Z = toload == 0
	_cpu.registers.flags.N = toload >= 128
end

function op.LDX(mode)
	local toload
	if mode == AM_IMMEDIATE then
		toload = readOpcodeData(mode)
	else
		toload = NES.bus.readByte(readOpcodeData(mode))
	end
	_cpu.registers.X = toload
	_cpu.registers.flags.Z = toload == 0
	_cpu.registers.flags.N = toload >= 128
end

function op.LDY(mode)
	local toload
	if mode == AM_IMMEDIATE then
		toload = readOpcodeData(mode)
	else
		toload = NES.bus.readByte(readOpcodeData(mode))
	end
	_cpu.registers.Y = toload
	_cpu.registers.flags.Z = toload == 0
	_cpu.registers.flags.N = toload >= 128
end

function op.LSR(mode)
	local value, addr
	if mode == AM_ACCUMULATOR then
		value = _cpu.registers.A
	else
		addr = readOpcodeData(mode)
		value = NES.bus.readByte(addr)
	end
	local oldzero = value % 2
	value = math.floor(value/2)
	if mode == AM_ACCUMULATOR then
		_cpu.registers.A = value
	else
		NES.bus.writeByte(addr, value)
	end
	_cpu.registers.flags.C = oldzero == 1
	_cpu.registers.flags.Z = value == 0
	_cpu.registers.flags.N = value >= 128
end

function op.NOP(mode)
end

function op.OAL(mode)
	-- TODO: FAIL
	op.AND(mode)
	_cpu.registers.X = _cpu.registers.A
end

function op.ORA(mode)
	local toor
	if mode == AM_IMMEDIATE then
		toor = readOpcodeData(mode)
	else
		toor = NES.bus.readByte(readOpcodeData(mode))
	end
	_cpu.registers.A = bit.bor(_cpu.registers.A, toor)
	_cpu.registers.flags.Z = _cpu.registers.A == 0
	_cpu.registers.flags.N = _cpu.registers.A >= 128
end

function op.PHA(mode)
	NES.bus.writeByte(_cpu.registers.SP+256, _cpu.registers.A)
	_cpu.registers.SP = wrap8(_cpu.registers.SP-1)
end

function op.PHP(mode)
	NES.bus.writeByte(_cpu.registers.SP+256, _cpu.getFlags() + 16)
	_cpu.registers.SP = wrap8(_cpu.registers.SP-1)
end

function op.PLA(mode)
	_cpu.registers.A = NES.bus.readByte(wrap8(_cpu.registers.SP+1)+256)
	_cpu.registers.SP = wrap8(_cpu.registers.SP+1)
	_cpu.registers.flags.Z = _cpu.registers.A == 0
	_cpu.registers.flags.N = _cpu.registers.A >= 128
end

function op.PLP(mode)
	local flags = NES.bus.readByte(wrap8(_cpu.registers.SP+1)+256)
	_cpu.registers.SP = wrap8(_cpu.registers.SP+1)
	_cpu.setFlags(flags)
end

function op.RLA(mode)
	op.ROL(mode)
	op.AND(mode)
end

function op.ROL(mode)
	local value, addr
	if mode == AM_ACCUMULATOR then
		value = _cpu.registers.A
	else
		addr = readOpcodeData(mode)
		value = NES.bus.readByte(addr)
	end
	local oldseven = value >= 128
	value = bit.band((value*2) + (_cpu.registers.flags.C and 1 or 0), 0xFF)
	if mode == AM_ACCUMULATOR then
		_cpu.registers.A = value
	else
		NES.bus.writeByte(addr, value)
	end
	_cpu.registers.flags.C = oldseven
	_cpu.registers.flags.Z = value == 0
	_cpu.registers.flags.N = value >= 128
end

function op.ROR(mode)
	local value, addr
	if mode == AM_ACCUMULATOR then
		value = _cpu.registers.A
	else
		addr = readOpcodeData(mode)
		value = NES.bus.readByte(addr)
	end
	local oldzero = value % 2
	value = math.floor(value/2) + (_cpu.registers.flags.C and 128 or 0)
	if mode == AM_ACCUMULATOR then
		_cpu.registers.A = value
	else
		NES.bus.writeByte(addr, value)
	end
	_cpu.registers.flags.C = oldzero == 1
	_cpu.registers.flags.Z = value == 0
	_cpu.registers.flags.N = value >= 128
end

function op.RRA(mode)
	op.ROR(mode)
	op.ADC(mode)
end

function op.RTI(mode)
	local flags = NES.bus.readByte(wrap8(_cpu.registers.SP+1)+256)
	local tojump = NES.bus.readByte(wrap8(_cpu.registers.SP+2)+256) + bit.lshift(NES.bus.readByte(wrap8(_cpu.registers.SP+3)+256), 8)
	_cpu.setFlags(flags)
	_cpu.registers.SP = wrap8(_cpu.registers.SP+3)
	_cpu.registers.PC = tojump - 1 -- Counteract PC increment
end

function op.RTS(mode)
	local tojump = NES.bus.readByte(wrap8(_cpu.registers.SP+1)+256) + bit.lshift(NES.bus.readByte(wrap8(_cpu.registers.SP+2)+256), 8)
	_cpu.registers.SP = wrap8(_cpu.registers.SP+2)
	_cpu.registers.PC = tojump
end

function op.SAX(mode)
	NES.bus.writeByte(readOpcodeData(mode), bit.band(_cpu.registers.X, _cpu.registers.A))
end

function op.SBC(mode)
	if _decimal and _cpu.registers.flags.D then
		error("Decimal mode unimplemented")
	else
		local tominus
		if mode == AM_IMMEDIATE then
			tominus = readOpcodeData(mode)
		else
			tominus = NES.bus.readByte(readOpcodeData(mode))
		end
		local value2 = _cpu.registers.A - tominus - (_cpu.registers.flags.C and 0 or 1)
		tominus = unsigned2signed(tominus)
		local value = unsigned2signed(_cpu.registers.A) - tominus - (_cpu.registers.flags.C and 0 or 1)
		_cpu.registers.A = bit.band(signed2unsigned(value), 0xFF)
		_cpu.registers.flags.C = value2 >= 0
		_cpu.registers.flags.Z = _cpu.registers.A == 0
		_cpu.registers.flags.V = value > 127 or value < -128
		_cpu.registers.flags.N = _cpu.registers.A >= 128
	end
end

function op.SEC(mode)
	_cpu.registers.flags.C = true
end

function op.SED(mode)
	_cpu.registers.flags.D = true
end

function op.SEI(mode)
	_cpu.registers.flags.I = true
end

function op.SLO(mode)
	op.ASL(mode)
	op.ORA(mode)
end

function op.SRE(mode)
	op.LSR(mode)
	op.EOR(mode)
end

function op.STA(mode)
	local toload = readOpcodeData(mode)
	NES.bus.writeByte(toload, _cpu.registers.A)
end

function op.STX(mode)
	local toload = readOpcodeData(mode)
	NES.bus.writeByte(toload, _cpu.registers.X)
end

function op.STY(mode)
	local toload = readOpcodeData(mode)
	NES.bus.writeByte(toload, _cpu.registers.Y)
end

function op.TAX(mode)
	_cpu.registers.X = _cpu.registers.A
	_cpu.registers.flags.Z = _cpu.registers.X == 0
	_cpu.registers.flags.N = _cpu.registers.X >= 128
end

function op.TAY(mode)
	_cpu.registers.Y = _cpu.registers.A
	_cpu.registers.flags.Z = _cpu.registers.Y == 0
	_cpu.registers.flags.N = _cpu.registers.Y >= 128
end

function op.TOP(mode)
end

function op.TSX(mode)
	_cpu.registers.X = _cpu.registers.SP
	_cpu.registers.flags.Z = _cpu.registers.X == 0
	_cpu.registers.flags.N = _cpu.registers.X >= 128
end

function op.TXA(mode)
	_cpu.registers.A = _cpu.registers.X
	_cpu.registers.flags.Z = _cpu.registers.A == 0
	_cpu.registers.flags.N = _cpu.registers.A >= 128
end

function op.TXS(mode)
	_cpu.registers.SP = _cpu.registers.X
end

function op.TYA(mode)
	_cpu.registers.A = _cpu.registers.Y
	_cpu.registers.flags.Z = _cpu.registers.A == 0
	_cpu.registers.flags.N = _cpu.registers.A >= 128
end

function op.XAA(mode)
	op.TXA(mode)
	op.AND(mode)
end

-- Borrowed from nesicide:
local m_6502opcode =
{
[0]={0x00, "BRK", op.BRK, AM_IMPLIED             , 7, true , false, 0x00}, -- BRK
	{0x01, "ORA", op.ORA, AM_PREINDEXED_INDIRECT , 6, true , false, 0x20}, -- ORA - (Indirect,X)
	{0x02, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0x03, "SLO", op.SLO, AM_PREINDEXED_INDIRECT , 8, false, false, 0x80}, -- SLO - (Indirect,X) (undocumented)
	{0x04, "DOP", op.DOP, AM_ZEROPAGE            , 3, false, false, 0x04}, -- DOP (undocumented)
	{0x05, "ORA", op.ORA, AM_ZEROPAGE            , 3, true , false, 0x04}, -- ORA - Zero Page
	{0x06, "ASL", op.ASL, AM_ZEROPAGE            , 5, true , false, 0x10}, -- ASL - Zero Page
	{0x07, "SLO", op.SLO, AM_ZEROPAGE            , 5, false, false, 0x10}, -- SLO - Zero Page (undocumented)
	{0x08, "PHP", op.PHP, AM_IMPLIED             , 3, true , false, 0x04}, -- PHP
	{0x09, "ORA", op.ORA, AM_IMMEDIATE           , 2, true , false, 0x02}, -- ORA - Immediate
	{0x0A, "ASL", op.ASL, AM_ACCUMULATOR         , 2, true , false, 0x02}, -- ASL - Accumulator
	{0x0B, "ANC", op.ANC, AM_IMMEDIATE           , 2, false, false, 0x02}, -- ANC - Immediate (undocumented)
	{0x0C, "TOP", op.TOP, AM_ABSOLUTE            , 4, false, false, 0x08}, -- TOP (undocumented)
	{0x0D, "ORA", op.ORA, AM_ABSOLUTE            , 4, true , false, 0x08}, -- ORA - Absolute
	{0x0E, "ASL", op.ASL, AM_ABSOLUTE            , 6, true , false, 0x20}, -- ASL - Absolute
	{0x0F, "SLO", op.SLO, AM_ABSOLUTE            , 6, false, false, 0x20}, -- SLO - Absolute (undocumented)
	{0x10, "BPL", op.BPL, AM_RELATIVE            , 2, true , false, 0x0A}, -- BPL
	{0x11, "ORA", op.ORA, AM_POSTINDEXED_INDIRECT, 5, true , false, 0x10}, -- ORA - (Indirect),Y
	{0x12, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0x13, "SLO", op.SLO, AM_POSTINDEXED_INDIRECT, 8, false, true , 0x80}, -- SLO - (Indirect),Y (undocumented)
	{0x14, "DOP", op.DOP, AM_ZEROPAGE_INDEXED_X  , 4, false, false, 0x08}, -- DOP (undocumented)
	{0x15, "ORA", op.ORA, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- ORA - Zero Page,X
	{0x16, "ASL", op.ASL, AM_ZEROPAGE_INDEXED_X  , 6, true , false, 0x20}, -- ASL - Zero Page,X
	{0x17, "SLO", op.SLO, AM_ZEROPAGE_INDEXED_X  , 6, false, false, 0x20}, -- SLO - Zero Page,X (undocumented)
	{0x18, "CLC", op.CLC, AM_IMPLIED             , 2, true , false, 0x02}, -- CLC
	{0x19, "ORA", op.ORA, AM_ABSOLUTE_INDEXED_Y  , 4, true , false, 0x08}, -- ORA - Absolute,Y
	{0x1A, "NOP", op.NOP, AM_IMPLIED             , 2, false, false, 0x02}, -- NOP (undocumented)
	{0x1B, "SLO", op.SLO, AM_ABSOLUTE_INDEXED_Y  , 7, false, true , 0x40}, -- SLO - Absolute,Y (undocumented)
	{0x1C, "TOP", op.TOP, AM_ABSOLUTE_INDEXED_X  , 4, false, false, 0x08}, -- TOP (undocumented)
	{0x1D, "ORA", op.ORA, AM_ABSOLUTE_INDEXED_X  , 4, true , false, 0x08}, -- ORA - Absolute,X
	{0x1E, "ASL", op.ASL, AM_ABSOLUTE_INDEXED_X  , 7, true , true , 0x40}, -- ASL - Absolute,X
	{0x1F, "SLO", op.SLO, AM_ABSOLUTE_INDEXED_X  , 7, false, true , 0x40}, -- SLO - Absolute,X (undocumented)
	{0x20, "JSR", op.JSR, AM_ABSOLUTE            , 6, true , false, 0x20}, -- JSR
	{0x21, "AND", op.AND, AM_PREINDEXED_INDIRECT , 6, true , false, 0x20}, -- AND - (Indirect,X)
	{0x22, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0x23, "RLA", op.RLA, AM_PREINDEXED_INDIRECT , 8, false, false, 0x80}, -- RLA - (Indirect,X) (undocumented)
	{0x24, "BIT", op.BIT, AM_ZEROPAGE            , 3, true , false, 0x04}, -- BIT - Zero Page
	{0x25, "AND", op.AND, AM_ZEROPAGE            , 3, true , false, 0x04}, -- AND - Zero Page
	{0x26, "ROL", op.ROL, AM_ZEROPAGE            , 5, true , false, 0x10}, -- ROL - Zero Page
	{0x27, "RLA", op.RLA, AM_ZEROPAGE            , 5, false, false, 0x10}, -- RLA - Zero Page (undocumented)
	{0x28, "PLP", op.PLP, AM_IMPLIED             , 4, true , false, 0x08}, -- PLP
	{0x29, "AND", op.AND, AM_IMMEDIATE           , 2, true , false, 0x02}, -- AND - Immediate
	{0x2A, "ROL", op.ROL, AM_ACCUMULATOR         , 2, true , false, 0x02}, -- ROL - Accumulator
	{0x2B, "ANC", op.ANC, AM_IMMEDIATE           , 2, false, false, 0x02}, -- ANC - Immediate (undocumented)
	{0x2C, "BIT", op.BIT, AM_ABSOLUTE            , 4, true , false, 0x08}, -- BIT - Absolute
	{0x2D, "AND", op.AND, AM_ABSOLUTE            , 4, true , false, 0x08}, -- AND - Absolute
	{0x2E, "ROL", op.ROL, AM_ABSOLUTE            , 6, true , false, 0x20}, -- ROL - Absolute
	{0x2F, "RLA", op.RLA, AM_ABSOLUTE            , 6, false, false, 0x20}, -- RLA - Absolute (undocumented)
	{0x30, "BMI", op.BMI, AM_RELATIVE            , 2, true , false, 0x02}, -- BMI
	{0x31, "AND", op.AND, AM_POSTINDEXED_INDIRECT, 5, true , false, 0x10}, -- AND - (Indirect),Y
	{0x32, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0x33, "RLA", op.RLA, AM_POSTINDEXED_INDIRECT, 8, false, true , 0x80}, -- RLA - (Indirect),Y (undocumented)
	{0x34, "DOP", op.DOP, AM_ZEROPAGE_INDEXED_X  , 4, false, false, 0x08}, -- DOP (undocumented)
	{0x35, "AND", op.AND, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- AND - Zero Page,X
	{0x36, "ROL", op.ROL, AM_ZEROPAGE_INDEXED_X  , 6, true , false, 0x20}, -- ROL - Zero Page,X
	{0x37, "RLA", op.RLA, AM_ZEROPAGE_INDEXED_X  , 6, false, false, 0x20}, -- RLA - Zero Page,X (undocumented)
	{0x38, "SEC", op.SEC, AM_IMPLIED             , 2, true , false, 0x02}, -- SEC
	{0x39, "AND", op.AND, AM_ABSOLUTE_INDEXED_Y  , 4, true , false, 0x08}, -- AND - Absolute,Y
	{0x3A, "NOP", op.NOP, AM_IMPLIED             , 2, false, false, 0x02}, -- NOP (undocumented)
	{0x3B, "RLA", op.RLA, AM_ABSOLUTE_INDEXED_Y  , 7, false, true , 0x40}, -- RLA - Absolute,Y (undocumented)
	{0x3C, "TOP", op.TOP, AM_ABSOLUTE_INDEXED_X  , 4, false, false, 0x08}, -- TOP (undocumented)
	{0x3D, "AND", op.AND, AM_ABSOLUTE_INDEXED_X  , 4, true , false, 0x08}, -- AND - Absolute,X
	{0x3E, "ROL", op.ROL, AM_ABSOLUTE_INDEXED_X  , 7, true , false, 0x40}, -- ROL - Absolute,X
	{0x3F, "RLA", op.RLA, AM_ABSOLUTE_INDEXED_X  , 7, false, true , 0x40}, -- RLA - Absolute,X (undocumented)
	{0x40, "RTI", op.RTI, AM_IMPLIED             , 6, true , false, 0x20}, -- RTI
	{0x41, "EOR", op.EOR, AM_PREINDEXED_INDIRECT , 6, true , false, 0x20}, -- EOR - (Indirect,X)
	{0x42, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0x43, "SRE", op.SRE, AM_PREINDEXED_INDIRECT , 8, false, false, 0x80}, -- SRE - (Indirect,X) (undocumented)
	{0x44, "DOP", op.DOP, AM_ZEROPAGE            , 3, false, false, 0x04}, -- DOP (undocumented)
	{0x45, "EOR", op.EOR, AM_ZEROPAGE            , 3, true , false, 0x04}, -- EOR - Zero Page
	{0x46, "LSR", op.LSR, AM_ZEROPAGE            , 5, true , false, 0x10}, -- LSR - Zero Page
	{0x47, "SRE", op.SRE, AM_ZEROPAGE            , 5, false, false, 0x10}, -- SRE - Zero Page (undocumented)
	{0x48, "PHA", op.PHA, AM_IMPLIED             , 3, true , false, 0x04}, -- PHA
	{0x49, "EOR", op.EOR, AM_IMMEDIATE           , 2, true , false, 0x02}, -- EOR - Immediate
	{0x4A, "LSR", op.LSR, AM_ACCUMULATOR         , 2, true , false, 0x02}, -- LSR - Accumulator
	{0x4B, "ALR", op.ALR, AM_IMMEDIATE           , 2, false, false, 0x02}, -- ALR - Immediate (undocumented)
	{0x4C, "JMP", op.JMP, AM_ABSOLUTE            , 3, true , false, 0x04}, -- JMP - Absolute
	{0x4D, "EOR", op.EOR, AM_ABSOLUTE            , 4, true , false, 0x08}, -- EOR - Absolute
	{0x4E, "LSR", op.LSR, AM_ABSOLUTE            , 6, true , false, 0x20}, -- LSR - Absolute
	{0x4F, "SRE", op.SRE, AM_ABSOLUTE            , 6, false, false, 0x20}, -- SRE - Absolute (undocumented)
	{0x50, "BVC", op.BVC, AM_RELATIVE            , 2, true , false, 0x0A}, -- BVC
	{0x51, "EOR", op.EOR, AM_POSTINDEXED_INDIRECT, 5, true , false, 0x10}, -- EOR - (Indirect),Y
	{0x52, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0x53, "SRE", op.SRE, AM_POSTINDEXED_INDIRECT, 8, false, true , 0x80}, -- SRE - (Indirect),Y
	{0x54, "DOP", op.DOP, AM_ZEROPAGE_INDEXED_X  , 4, false, false, 0x08}, -- DOP (undocumented)
	{0x55, "EOR", op.EOR, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- EOR - Zero Page,X
	{0x56, "LSR", op.LSR, AM_ZEROPAGE_INDEXED_X  , 6, true , false, 0x20}, -- LSR - Zero Page,X
	{0x57, "SRE", op.SRE, AM_ZEROPAGE_INDEXED_X  , 6, false, false, 0x20}, -- SRE - Zero Page,X (undocumented)
	{0x58, "CLI", op.CLI, AM_IMPLIED             , 2, true , false, 0x02}, -- CLI
	{0x59, "EOR", op.EOR, AM_ABSOLUTE_INDEXED_Y  , 4, true , false, 0x08}, -- EOR - Absolute,Y
	{0x5A, "NOP", op.NOP, AM_IMPLIED             , 2, false, false, 0x02}, -- NOP (undocumented)
	{0x5B, "SRE", op.SRE, AM_ABSOLUTE_INDEXED_Y  , 7, false, true , 0x40}, -- SRE - Absolute,Y (undocumented)
	{0x5C, "TOP", op.TOP, AM_ABSOLUTE_INDEXED_X  , 4, false, false, 0x08}, -- TOP (undocumented)
	{0x5D, "EOR", op.EOR, AM_ABSOLUTE_INDEXED_X  , 4, true , false, 0x08}, -- EOR - Absolute,X
	{0x5E, "LSR", op.LSR, AM_ABSOLUTE_INDEXED_X  , 7, true , true , 0x40}, -- LSR - Absolute,X
	{0x5F, "SRE", op.SRE, AM_ABSOLUTE_INDEXED_X  , 7, false, true , 0x40}, -- SRE - Absolute,X (undocumented)
	{0x60, "RTS", op.RTS, AM_IMPLIED             , 6, true , false, 0x20}, -- RTS
	{0x61, "ADC", op.ADC, AM_PREINDEXED_INDIRECT , 6, true , false, 0x20}, -- ADC - (Indirect,X)
	{0x62, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0x63, "RRA", op.RRA, AM_PREINDEXED_INDIRECT , 8, false, false, 0x80}, -- RRA - (Indirect,X) (undocumented)
	{0x64, "DOP", op.DOP, AM_ZEROPAGE            , 3, false, false, 0x04}, -- DOP (undocumented)
	{0x65, "ADC", op.ADC, AM_ZEROPAGE            , 3, true , false, 0x04}, -- ADC - Zero Page
	{0x66, "ROR", op.ROR, AM_ZEROPAGE            , 5, true , false, 0x10}, -- ROR - Zero Page
	{0x67, "RRA", op.RRA, AM_ZEROPAGE            , 5, false, false, 0x10}, -- RRA - Zero Page (undocumented)
	{0x68, "PLA", op.PLA, AM_IMPLIED             , 4, true , false, 0x08}, -- PLA
	{0x69, "ADC", op.ADC, AM_IMMEDIATE           , 2, true , false, 0x02}, -- ADC - Immediate
	{0x6A, "ROR", op.ROR, AM_ACCUMULATOR         , 2, true , false, 0x02}, -- ROR - Accumulator
	{0x6B, "ARR", op.ARR, AM_IMMEDIATE           , 2, false, false, 0x02}, -- ARR - Immediate (undocumented)
	{0x6C, "JMP", op.JMP, AM_INDIRECT            , 5, true , false, 0x10}, -- JMP - Indirect
	{0x6D, "ADC", op.ADC, AM_ABSOLUTE            , 4, true , false, 0x08}, -- ADC - Absolute
	{0x6E, "ROR", op.ROR, AM_ABSOLUTE            , 6, true , false, 0x20}, -- ROR - Absolute
	{0x6F, "RRA", op.RRA, AM_ABSOLUTE            , 6, false, false, 0x20}, -- RRA - Absolute (undocumented)
	{0x70, "BVS", op.BVS, AM_RELATIVE            , 2, true , false, 0x0A}, -- BVS
	{0x71, "ADC", op.ADC, AM_POSTINDEXED_INDIRECT, 5, true , false, 0x10}, -- ADC - (Indirect),Y
	{0x72, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0x73, "RRA", op.RRA, AM_POSTINDEXED_INDIRECT, 8, false, true , 0x80}, -- RRA - (Indirect),Y (undocumented)
	{0x74, "DOP", op.DOP, AM_ZEROPAGE_INDEXED_X  , 4, false, false, 0x08}, -- DOP (undocumented)
	{0x75, "ADC", op.ADC, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- ADC - Zero Page,X
	{0x76, "ROR", op.ROR, AM_ZEROPAGE_INDEXED_X  , 6, true , false, 0x20}, -- ROR - Zero Page,X
	{0x77, "RRA", op.RRA, AM_ZEROPAGE_INDEXED_X  , 6, false, false, 0x20}, -- RRA - Zero Page,X (undocumented)
	{0x78, "SEI", op.SEI, AM_IMPLIED             , 2, true , false, 0x02}, -- SEI
	{0x79, "ADC", op.ADC, AM_ABSOLUTE_INDEXED_Y  , 4, true , false, 0x08}, -- ADC - Absolute,Y
	{0x7A, "NOP", op.NOP, AM_IMPLIED             , 2, false, false, 0x02}, -- NOP (undocumented)
	{0x7B, "RRA", op.RRA, AM_ABSOLUTE_INDEXED_Y  , 7, false, true , 0x40}, -- RRA - Absolute,Y (undocumented)
	{0x7C, "TOP", op.TOP, AM_ABSOLUTE_INDEXED_X  , 4, false, false, 0x08}, -- TOP (undocumented)
	{0x7D, "ADC", op.ADC, AM_ABSOLUTE_INDEXED_X  , 4, true , false, 0x08}, -- ADC - Absolute,X
	{0x7E, "ROR", op.ROR, AM_ABSOLUTE_INDEXED_X  , 7, true , true , 0x40}, -- ROR - Absolute,X
	{0x7F, "RRA", op.RRA, AM_ABSOLUTE_INDEXED_X  , 7, false, true , 0x40}, -- RRA - Absolute,X (undocumented)
	{0x80, "DOP", op.DOP, AM_IMMEDIATE           , 2, false, false, 0x02}, -- DOP (undocumented)
	{0x81, "STA", op.STA, AM_PREINDEXED_INDIRECT , 6, true , false, 0x20}, -- STA - (Indirect,X)
	{0x82, "DOP", op.DOP, AM_IMMEDIATE           , 2, false, false, 0x02}, -- DOP (undocumented)
	{0x83, "SAX", op.SAX, AM_PREINDEXED_INDIRECT , 6, false, false, 0x20}, -- SAX - (Indirect,X) (undocumented)
	{0x84, "STY", op.STY, AM_ZEROPAGE            , 3, true , false, 0x04}, -- STY - Zero Page
	{0x85, "STA", op.STA, AM_ZEROPAGE            , 3, true , false, 0x04}, -- STA - Zero Page
	{0x86, "STX", op.STX, AM_ZEROPAGE            , 3, true , false, 0x04}, -- STX - Zero Page
	{0x87, "SAX", op.SAX, AM_ZEROPAGE            , 3, false, false, 0x04}, -- SAX - Zero Page (undocumented)
	{0x88, "DEY", op.DEY, AM_IMPLIED             , 2, true , false, 0x02}, -- DEY
	{0x89, "DOP", op.DOP, AM_IMMEDIATE           , 2, false, false, 0x02}, -- DOP (undocumented)
	{0x8A, "TXA", op.TXA, AM_IMPLIED             , 2, true , false, 0x02}, -- TXA
	{0x8B, "XAA", op.XAA, AM_IMMEDIATE           , 2, false, false, 0x02}, -- XAA - Immediate (undocumented)
	{0x8C, "STY", op.STY, AM_ABSOLUTE            , 4, true , false, 0x08}, -- STY - Absolute
	{0x8D, "STA", op.STA, AM_ABSOLUTE            , 4, true , false, 0x08}, -- STA - Absolute
	{0x8E, "STX", op.STX, AM_ABSOLUTE            , 4, true , false, 0x08}, -- STX - Absolute
	{0x8F, "SAX", op.SAX, AM_ABSOLUTE            , 4, false, false, 0x08}, -- SAX - Absolulte (undocumented)
	{0x90, "BCC", op.BCC, AM_RELATIVE            , 2, true , false, 0x0A}, -- BCC
	{0x91, "STA", op.STA, AM_POSTINDEXED_INDIRECT, 6, true , true , 0x20}, -- STA - (Indirect),Y
	{0x92, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0x93, "AXA", op.AXA, AM_POSTINDEXED_INDIRECT, 6, false, true , 0x20}, -- AXA - (Indirect),Y
	{0x94, "STY", op.STY, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- STY - Zero Page,X
	{0x95, "STA", op.STA, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- STA - Zero Page,X
	{0x96, "STX", op.STX, AM_ZEROPAGE_INDEXED_Y  , 4, true , false, 0x08}, -- STX - Zero Page,Y
	{0x97, "SAX", op.SAX, AM_ZEROPAGE_INDEXED_Y  , 4, false, false, 0x08}, -- SAX - Zero Page,Y
	{0x98, "TYA", op.TYA, AM_IMPLIED             , 2, true , false, 0x02}, -- TYA
	{0x99, "STA", op.STA, AM_ABSOLUTE_INDEXED_Y  , 5, true , true , 0x10}, -- STA - Absolute,Y
	{0x9A, "TXS", op.TXS, AM_IMPLIED             , 2, true , false, 0x02}, -- TXS
	{0x9B, "TAS", op.TAS, AM_ABSOLUTE_INDEXED_Y  , 5, false, true , 0x10}, -- TAS - Absolute,Y (undocumented)
	{0x9C, "SAY", op.SAY, AM_ABSOLUTE_INDEXED_X  , 5, false, true , 0x10}, -- SAY - Absolute,X (undocumented)
	{0x9D, "STA", op.STA, AM_ABSOLUTE_INDEXED_X  , 5, true , true , 0x10}, -- STA - Absolute,X
	{0x9E, "XAS", op.XAS, AM_ABSOLUTE_INDEXED_Y  , 5, false, true , 0x10}, -- XAS - Absolute,Y (undocumented)
	{0x9F, "AXA", op.AXA, AM_ABSOLUTE_INDEXED_Y  , 5, false, true , 0x10}, -- AXA - Absolute,Y (undocumented)
	{0xA0, "LDY", op.LDY, AM_IMMEDIATE           , 2, true , false, 0x02}, -- LDY - Immediate
	{0xA1, "LDA", op.LDA, AM_PREINDEXED_INDIRECT , 6, true , false, 0x20}, -- LDA - (Indirect,X)
	{0xA2, "LDX", op.LDX, AM_IMMEDIATE           , 2, true , false, 0x02}, -- LDX - Immediate
	{0xA3, "LAX", op.LAX, AM_PREINDEXED_INDIRECT , 6, false, false, 0x20}, -- LAX - (Indirect,X) (undocumented)
	{0xA4, "LDY", op.LDY, AM_ZEROPAGE            , 3, true , false, 0x04}, -- LDY - Zero Page
	{0xA5, "LDA", op.LDA, AM_ZEROPAGE            , 3, true , false, 0x04}, -- LDA - Zero Page
	{0xA6, "LDX", op.LDX, AM_ZEROPAGE            , 3, true , false, 0x04}, -- LDX - Zero Page
	{0xA7, "LAX", op.LAX, AM_ZEROPAGE            , 3, false, false, 0x04}, -- LAX - Zero Page (undocumented)
	{0xA8, "TAY", op.TAY, AM_IMPLIED             , 2, true , false, 0x02}, -- TAY
	{0xA9, "LDA", op.LDA, AM_IMMEDIATE           , 2, true , false, 0x02}, -- LDA - Immediate
	{0xAA, "TAX", op.TAX, AM_IMPLIED             , 2, true , false, 0x02}, -- TAX
	{0xAB, "OAL", op.OAL, AM_IMMEDIATE           , 2, false, false, 0x02}, -- OAL - Immediate
	{0xAC, "LDY", op.LDY, AM_ABSOLUTE            , 4, true , false, 0x08}, -- LDY - Absolute
	{0xAD, "LDA", op.LDA, AM_ABSOLUTE            , 4, true , false, 0x08}, -- LDA - Absolute
	{0xAE, "LDX", op.LDX, AM_ABSOLUTE            , 4, true , false, 0x08}, -- LDX - Absolute
	{0xAF, "LAX", op.LAX, AM_ABSOLUTE            , 4, false, false, 0x08}, -- LAX - Absolute (undocumented)
	{0xB0, "BCS", op.BCS, AM_RELATIVE            , 2, true , false, 0x0A}, -- BCS
	{0xB1, "LDA", op.LDA, AM_POSTINDEXED_INDIRECT, 5, true , false, 0x10}, -- LDA - (Indirect),Y
	{0xB2, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0xB3, "LAX", op.LAX, AM_POSTINDEXED_INDIRECT, 5, false, false, 0x10}, -- LAX - (Indirect),Y (undocumented)
	{0xB4, "LDY", op.LDY, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- LDY - Zero Page,X
	{0xB5, "LDA", op.LDA, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- LDA - Zero Page,X
	{0xB6, "LDX", op.LDX, AM_ZEROPAGE_INDEXED_Y  , 4, true , false, 0x08}, -- LDX - Zero Page,Y
	{0xB7, "LAX", op.LAX, AM_ZEROPAGE_INDEXED_Y  , 4, false, false, 0x08}, -- LAX - Zero Page,X (undocumented)
	{0xB8, "CLV", op.CLV, AM_IMPLIED             , 2, true , false, 0x02}, -- CLV
	{0xB9, "LDA", op.LDA, AM_ABSOLUTE_INDEXED_Y  , 4, true , false, 0x08}, -- LDA - Absolute,Y
	{0xBA, "TSX", op.TSX, AM_IMPLIED             , 2, true , false, 0x02}, -- TSX
	{0xBB, "LAS", op.LAS, AM_ABSOLUTE_INDEXED_Y  , 4, false, false, 0x08}, -- LAS - Absolute,Y (undocumented)
	{0xBC, "LDY", op.LDY, AM_ABSOLUTE_INDEXED_X  , 4, true , false, 0x08}, -- LDY - Absolute,X
	{0xBD, "LDA", op.LDA, AM_ABSOLUTE_INDEXED_X  , 4, true , false, 0x08}, -- LDA - Absolute,X
	{0xBE, "LDX", op.LDX, AM_ABSOLUTE_INDEXED_Y  , 4, true , false, 0x08}, -- LDX - Absolute,Y
	{0xBF, "LAX", op.LAX, AM_ABSOLUTE_INDEXED_Y  , 4, false, false, 0x08}, -- LAX - Absolute,Y (undocumented)
	{0xC0, "CPY", op.CPY, AM_IMMEDIATE           , 2, true , false, 0x02}, -- CPY - Immediate
	{0xC1, "CMP", op.CMP, AM_PREINDEXED_INDIRECT , 6, true , false, 0x20}, -- CMP - (Indirect,X)
	{0xC2, "DOP", op.DOP, AM_IMMEDIATE           , 2, false, false, 0x02}, -- DOP (undocumented)
	{0xC3, "DCP", op.DCP, AM_PREINDEXED_INDIRECT , 8, false, false, 0x80}, -- DCP - (Indirect,X) (undocumented)
	{0xC4, "CPY", op.CPY, AM_ZEROPAGE            , 3, true , false, 0x04}, -- CPY - Zero Page
	{0xC5, "CMP", op.CMP, AM_ZEROPAGE            , 3, true , false, 0x04}, -- CMP - Zero Page
	{0xC6, "DEC", op.DEC, AM_ZEROPAGE            , 5, true , false, 0x10}, -- DEC - Zero Page
	{0xC7, "DCP", op.DCP, AM_ZEROPAGE            , 5, true , false, 0x10}, -- DCP - Zero Page (undocumented)
	{0xC8, "INY", op.INY, AM_IMPLIED             , 2, true , false, 0x02}, -- INY
	{0xC9, "CMP", op.CMP, AM_IMMEDIATE           , 2, true , false, 0x02}, -- CMP - Immediate
	{0xCA, "DEX", op.DEX, AM_IMPLIED             , 2, true , false, 0x02}, -- DEX
	{0xCB, "AXS", op.AXS, AM_IMMEDIATE           , 2, false, false, 0x02}, -- AXS - Immediate (undocumented)
	{0xCC, "CPY", op.CPY, AM_ABSOLUTE            , 4, true , false, 0x08}, -- CPY - Absolute
	{0xCD, "CMP", op.CMP, AM_ABSOLUTE            , 4, true , false, 0x08}, -- CMP - Absolute
	{0xCE, "DEC", op.DEC, AM_ABSOLUTE            , 6, true , false, 0x20}, -- DEC - Absolute
	{0xCF, "DCP", op.DCP, AM_ABSOLUTE            , 6, false, false, 0x20}, -- DCP - Absolute (undocumented)
	{0xD0, "BNE", op.BNE, AM_RELATIVE            , 2, true , false, 0x0A}, -- BNE
	{0xD1, "CMP", op.CMP, AM_POSTINDEXED_INDIRECT, 5, true , false, 0x10}, -- CMP   (Indirect),Y
	{0xD2, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0xD3, "DCP", op.DCP, AM_POSTINDEXED_INDIRECT, 8, false, true , 0x80}, -- DCP - (Indirect),Y (undocumented)
	{0xD4, "DOP", op.DOP, AM_ZEROPAGE_INDEXED_X  , 4, false, false, 0x08}, -- DOP (undocumented)
	{0xD5, "CMP", op.CMP, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- CMP - Zero Page,X
	{0xD6, "DEC", op.DEC, AM_ZEROPAGE_INDEXED_X  , 6, true , false, 0x20}, -- DEC - Zero Page,X
	{0xD7, "DCP", op.DCP, AM_ZEROPAGE_INDEXED_X  , 6, false, false, 0x20}, -- DCP - Zero Page,X (undocumented)
	{0xD8, "CLD", op.CLD, AM_IMPLIED             , 2, true , false, 0x02}, -- CLD
	{0xD9, "CMP", op.CMP, AM_ABSOLUTE_INDEXED_Y  , 4, true , false, 0x08}, -- CMP - Absolute,Y
	{0xDA, "NOP", op.NOP, AM_IMPLIED             , 2, false, false, 0x02}, -- NOP (undocumented)
	{0xDB, "DCP", op.DCP, AM_ABSOLUTE_INDEXED_Y  , 7, false, true , 0x40}, -- DCP - Absolute,Y (undocumented)
	{0xDC, "TOP", op.TOP, AM_ABSOLUTE_INDEXED_X  , 4, false, false, 0x08}, -- TOP (undocumented)
	{0xDD, "CMP", op.CMP, AM_ABSOLUTE_INDEXED_X  , 4, true , false, 0x08}, -- CMP - Absolute,X
	{0xDE, "DEC", op.DEC, AM_ABSOLUTE_INDEXED_X  , 7, true , true , 0x40}, -- DEC - Absolute,X
	{0xDF, "DCP", op.DCP, AM_ABSOLUTE_INDEXED_X  , 7, false, true , 0x40}, -- DCP - Absolute,X (undocumented)
	{0xE0, "CPX", op.CPX, AM_IMMEDIATE           , 2, true , false, 0x02}, -- CPX - Immediate
	{0xE1, "SBC", op.SBC, AM_PREINDEXED_INDIRECT , 6, true , false, 0x20}, -- SBC - (Indirect,X)
	{0xE2, "DOP", op.DOP, AM_IMMEDIATE           , 2, false, false, 0x02}, -- DOP (undocumented)
	{0xE3, "ISB", op.ISB, AM_PREINDEXED_INDIRECT , 8, false, false, 0x80}, -- INS - (Indirect,X) (undocumented)
	{0xE4, "CPX", op.CPX, AM_ZEROPAGE            , 3, true , false, 0x04}, -- CPX - Zero Page
	{0xE5, "SBC", op.SBC, AM_ZEROPAGE            , 3, true , false, 0x04}, -- SBC - Zero Page
	{0xE6, "INC", op.INC, AM_ZEROPAGE            , 5, true , false, 0x10}, -- INC - Zero Page
	{0xE7, "ISB", op.ISB, AM_ZEROPAGE            , 5, false, false, 0x10}, -- INS - Zero Page (undocumented)
	{0xE8, "INX", op.INX, AM_IMPLIED             , 2, true , false, 0x02}, -- INX
	{0xE9, "SBC", op.SBC, AM_IMMEDIATE           , 2, true , false, 0x02}, -- SBC - Immediate
	{0xEA, "NOP", op.NOP, AM_IMPLIED             , 2, true , false, 0x02}, -- NOP
	{0xEB, "SBC", op.SBC, AM_IMMEDIATE           , 2, false, false, 0x02}, -- SBC - Immediate (undocumented)
	{0xEC, "CPX", op.CPX, AM_ABSOLUTE            , 4, true , false, 0x08}, -- CPX - Absolute
	{0xED, "SBC", op.SBC, AM_ABSOLUTE            , 4, true , false, 0x08}, -- SBC - Absolute
	{0xEE, "INC", op.INC, AM_ABSOLUTE            , 6, true , false, 0x20}, -- INC - Absolute
	{0xEF, "ISB", op.ISB, AM_ABSOLUTE            , 6, false, false, 0x20}, -- INS - Absolute (undocumented)
	{0xF0, "BEQ", op.BEQ, AM_RELATIVE            , 2, true , false, 0x0A}, -- BEQ
	{0xF1, "SBC", op.SBC, AM_POSTINDEXED_INDIRECT, 5, true , false, 0x10}, -- SBC - (Indirect),Y
	{0xF2, "KIL", op.KIL, AM_IMPLIED             , 0, false, false, 0x00}, -- KIL - Implied (processor lock up!)
	{0xF3, "ISB", op.ISB, AM_POSTINDEXED_INDIRECT, 8, false, true , 0x80}, -- INS - (Indirect),Y (undocumented)
	{0xF4, "DOP", op.DOP, AM_ZEROPAGE_INDEXED_X  , 4, false, false, 0x08}, -- DOP (undocumented)
	{0xF5, "SBC", op.SBC, AM_ZEROPAGE_INDEXED_X  , 4, true , false, 0x08}, -- SBC - Zero Page,X
	{0xF6, "INC", op.INC, AM_ZEROPAGE_INDEXED_X  , 6, true , false, 0x20}, -- INC - Zero Page,X
	{0xF7, "ISB", op.ISB, AM_ZEROPAGE_INDEXED_X  , 6, false, false, 0x20}, -- INS - Zero Page,X (undocumented)
	{0xF8, "SED", op.SED, AM_IMPLIED             , 2, true , false, 0x02}, -- SED
	{0xF9, "SBC", op.SBC, AM_ABSOLUTE_INDEXED_Y  , 4, true , false, 0x08}, -- SBC - Absolute,Y
	{0xFA, "NOP", op.NOP, AM_IMPLIED             , 2, false, false, 0x02}, -- NOP (undocumented)
	{0xFB, "ISB", op.ISB, AM_ABSOLUTE_INDEXED_Y  , 7, false, true , 0x40}, -- INS - Absolute,Y (undocumented)
	{0xFC, "TOP", op.TOP, AM_ABSOLUTE_INDEXED_X  , 4, false, false, 0x08}, -- TOP (undocumented)
	{0xFD, "SBC", op.SBC, AM_ABSOLUTE_INDEXED_X  , 4, true , false, 0x08}, -- SBC - Absolute,X
	{0xFE, "INC", op.INC, AM_ABSOLUTE_INDEXED_X  , 7, true , true , 0x40}, -- INC - Absolute,X
	{0xFF, "ISB", op.ISB, AM_ABSOLUTE_INDEXED_X  , 7, false, true , 0x40}  -- INS - Absolute,X (undocumented)
}

local AM_IMPLIED = 1
local AM_IMMEDIATE = 2
local AM_ABSOLUTE = 3
local AM_ZEROPAGE = 4 
local AM_ACCUMULATOR = 5
local AM_ABSOLUTE_INDEXED_X = 6
local AM_ABSOLUTE_INDEXED_Y = 7
local AM_ZEROPAGE_INDEXED_X = 8
local AM_ZEROPAGE_INDEXED_Y = 9
local AM_INDIRECT = 10
local AM_PREINDEXED_INDIRECT = 11
local AM_POSTINDEXED_INDIRECT = 12
local AM_RELATIVE = 13

local function makeNintendulatorLog(opcode)
	local bytes = ""
	local obj = ""
	for i = 0, opcode_size[m_6502opcode[opcode][4]] - 1 do
		bytes = bytes .. " " .. string.format("%02X", NES.bus.readByte(_cpu.registers.PC + i))
		if i > 0 then
			obj = string.format("%02X", NES.bus.readByte(_cpu.registers.PC + i)) .. obj
		end
	end
	return string.format("%04X %-9s %4s %-28sA:%02X X:%02X Y:%02X P:%02X SP:%02X", _cpu.registers.PC, bytes, m_6502opcode[opcode][2], obj, _cpu.registers.A, _cpu.registers.X, _cpu.registers.Y, _cpu.getFlags(), _cpu.registers.SP)
end

NES.cpu = {
	run = function()
		if _cpu.running then -- Not locked up
			-- Check for interrupts
			if _cpu.ninterrupt then -- NMI
				_cpu.ninterrupt = false
				_cpu.interrupt = false
				local tojump = NES.bus.readByte(0xFFFA) + bit.lshift(NES.bus.readByte(0xFFFB), 8)
				local retaddr = _cpu.registers.PC + 2
				NES.bus.writeByte(wrap8(_cpu.registers.SP-0)+256, math.floor(retaddr/256))
				NES.bus.writeByte(wrap8(_cpu.registers.SP-1)+256, bit.band(retaddr, 0xFF))
				NES.bus.writeByte(wrap8(_cpu.registers.SP-2)+256, _cpu.getFlags())
				_cpu.registers.flags.I = true
				_cpu.registers.SP = wrap8(_cpu.registers.SP-3)
				_cpu.registers.PC = tojump

				-- Decrement Cycles
				NES.cycles = NES.cycles - 7
				_cpu.cycles = _cpu.cycles + 7
			elseif _cpu.interrupt and not _cpu.registers.flags.I then -- IRQ
				_cpu.interrupt = false
				local tojump = NES.bus.readByte(0xFFFE) + bit.lshift(NES.bus.readByte(0xFFFF), 8)
				local retaddr = _cpu.registers.PC + 2
				NES.bus.writeByte(wrap8(_cpu.registers.SP-0)+256, math.floor(retaddr/256))
				NES.bus.writeByte(wrap8(_cpu.registers.SP-1)+256, bit.band(retaddr, 0xFF))
				NES.bus.writeByte(wrap8(_cpu.registers.SP-2)+256, _cpu.getFlags())
				_cpu.registers.flags.I = true
				_cpu.registers.SP = wrap8(_cpu.registers.SP-3)
				_cpu.registers.PC = tojump

				-- Decrement Cycles
				NES.cycles = NES.cycles - 7
				_cpu.cycles = _cpu.cycles + 7
			else
				_cpu.interrupt = false
				-- Fetch OPCode
				local opcode = NES.bus.readByte(_cpu.registers.PC)
				--[[
				-- Generate log
				print(makeNintendulatorLog(opcode))
				--]]
				-- Run OPCode
				if m_6502opcode[opcode][3] ~= nil then
					m_6502opcode[opcode][3](m_6502opcode[opcode][4])
				else
					print("Warning: op." .. m_6502opcode[opcode][2] .. " not implemented. " .. string.format("%02X", opcode))
				end
				-- Increment PC
				_cpu.registers.PC = (_cpu.registers.PC + opcode_size[m_6502opcode[opcode][4]]) % 65536

				-- Decrement Cycles
				NES.cycles = NES.cycles - m_6502opcode[opcode][5]
				_cpu.cycles = _cpu.cycles + m_6502opcode[opcode][5]
			end
		else
			NES.cycles = 0 -- Nothing is being run.
		end
	end,
	reset = function()
		-- TODO: Reset code
		_cpu.running = true
		_cpu.registers.PC = NES.bus.readByte(0xFFFC) + bit.lshift(NES.bus.readByte(0xFFFD), 8)
		-- Initialize Stack
		_cpu.registers.SP = 0xFD
		NES.bus.writeByte(0x1FE, 0xFF)
		NES.bus.writeByte(0x1FF, 0xFF)
	end,
	cpu = _cpu,
}
