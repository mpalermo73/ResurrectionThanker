--- AceConfigRegistry-3.0.lua
local MAJOR, MINOR = "AceConfigRegistry-3.0", 14
local AceConfigRegistry = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigRegistry then return end

AceConfigRegistry.options = {}

function AceConfigRegistry:RegisterOptionsTable(name, options)
	AceConfigRegistry.options[name] = options
end

function AceConfigRegistry:NotifyChange(name)
	-- Notify change
end
