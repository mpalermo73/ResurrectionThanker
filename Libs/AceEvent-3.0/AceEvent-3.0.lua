--- AceEvent-3.0.lua
local MAJOR, MINOR = "AceEvent-3.0", 4
local AceEvent, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceEvent then return end

local CallbackHandler = LibStub("CallbackHandler-1.0")

function AceEvent:Embed(target)
	target.RegisterEvent = function(self, event, method)
		if type(method) == "string" then
			method = self[method]
		end
		if not self.events then
			self.events = CallbackHandler:New(self, "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents")
		end
		self.events:RegisterEvent(event, method or event)
	end

	target.UnregisterEvent = function(self, event)
		if self.events then
			self.events:UnregisterEvent(event)
		end
	end

	target.UnregisterAllEvents = function(self)
		if self.events then
			self.events:UnregisterAllEvents()
		end
	end

	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(self, event, ...)
		if target.events then
			target.events:Fire(event, ...)
		end
	end)
	target.frame = frame

	for event in pairs(target.events or {}) do
		frame:RegisterEvent(event)
	end
end

function AceEvent:OnEmbedEnable(target)
	if target.frame then
		for event in pairs(target.events or {}) do
			target.frame:RegisterEvent(event)
		end
	end
end

function AceEvent:OnEmbedDisable(target)
	if target.frame then
		target.frame:UnregisterAllEvents()
	end
end
