--- AceAddon-3.0.lua
local MAJOR, MINOR = "AceAddon-3.0", 13
local AceAddon, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceAddon then return end

AceAddon.frame = AceAddon.frame or CreateFrame("Frame", "AceAddon30Frame")
AceAddon.addons = AceAddon.addons or {}
AceAddon.status = AceAddon.status or {}
AceAddon.initializequeue = AceAddon.initializequeue or {}
AceAddon.enablequeue = AceAddon.enablequeue or {}

local function safecall(func, ...)
	local success, err = xpcall(func, errorhandler, ...)
	if not success then geterrorhandler()(err) end
end

function AceAddon:NewAddon(name, ...)
	if type(name) ~= "string" then error(("Usage: NewAddon(name, [lib, lib, lib, ...]): 'name' - string expected got '%s'."):format(type(name)), 2) end
	if self.addons[name] then error(("Usage: NewAddon(name, [lib, lib, lib, ...]): 'name' - Addon '%s' already exists."):format(name), 2) end

	local addon = {name = name}
	self.addons[name] = addon
	addon.modules = {}
	addon.defaultModuleState = true
	addon.enabledState = true
	addon.moduleProfile = {}

	for i = 1, select("#", ...) do
		local lib = select(i, ...)
		lib:Embed(addon)
	end

	addon:InitializeAddon()

	return addon
end

function AceAddon:InitializeAddon(addon)
	if addon.OnInitialize then
		safecall(addon.OnInitialize, addon)
	end
end

function AceAddon:EnableAddon(addon)
	if addon.OnEnable then
		safecall(addon.OnEnable, addon)
	end
end

function AceAddon:DisableAddon(addon)
	if addon.OnDisable then
		safecall(addon.OnDisable, addon)
	end
end

local function OnEvent(this, event, arg1)
	if event == "ADDON_LOADED" then
		local addon = AceAddon.addons[arg1]
		if addon then
			AceAddon:InitializeAddon(addon)
		end
	elseif event == "PLAYER_LOGIN" then
		for name, addon in pairs(AceAddon.addons) do
			AceAddon:EnableAddon(addon)
		end
	end
end

AceAddon.frame:SetScript("OnEvent", OnEvent)
AceAddon.frame:RegisterEvent("ADDON_LOADED")
AceAddon.frame:RegisterEvent("PLAYER_LOGIN")
