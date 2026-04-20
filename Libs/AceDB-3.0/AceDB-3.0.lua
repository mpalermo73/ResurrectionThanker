--- AceDB-3.0.lua
local MAJOR, MINOR = "AceDB-3.0", 26
local AceDB, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceDB then return end

local CallbackHandler = LibStub("CallbackHandler-1.0")

local function copyDefaults(dest, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if not dest[k] then dest[k] = {} end
			copyDefaults(dest[k], v)
		else
			if dest[k] == nil then dest[k] = v end
		end
	end
end

function AceDB:New(name, defaults, defaultProfile)
	local self = {
		name = name,
		profile = {},
		profiles = {},
		keys = {},
		keys.profile = defaultProfile or "Default",
	}
	setmetatable(self, {__index = AceDB})

	if defaults then
		copyDefaults(self.profile, defaults.profile or defaults)
	end

	self.callbacks = CallbackHandler:New(self, "RegisterCallback", "UnregisterCallback", "UnregisterAllCallbacks")

	return self
end

function AceDB:GetProfile()
	return self.profile
end

function AceDB:SetProfile(name)
	self.keys.profile = name
	if not self.profiles[name] then
		self.profiles[name] = {}
		copyDefaults(self.profiles[name], self.defaults or {})
	end
	self.profile = self.profiles[name]
	self.callbacks:Fire("OnProfileChanged")
end
