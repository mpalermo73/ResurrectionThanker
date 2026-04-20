--- AceConfig-3.0.lua
local MAJOR, MINOR = "AceConfig-3.0", 14
local AceConfig = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfig then return end

AceConfig.options = {}

function AceConfig:RegisterOptionsTable(name, options)
	AceConfig.options[name] = options
end

function AceConfig:GetOptionsTable(name)
	return AceConfig.options[name]
end
