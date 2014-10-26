--[[
Nintendo Entertainment System emulator for Love2D
Controller Emulation

By Gamax92
--]]

NES.joy = {
}

-- Dummy Joystick output
NES.bus.register(0x4016, 1, function() return 0 end, function() end, 0)
NES.bus.register(0x4017, 1, function() return 0 end, function() end, 0)
