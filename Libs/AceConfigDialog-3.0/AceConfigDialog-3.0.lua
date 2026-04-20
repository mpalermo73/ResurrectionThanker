--- AceConfigDialog-3.0.lua
local MAJOR, MINOR = "AceConfigDialog-3.0", 86
local AceConfigDialog = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigDialog then return end

function AceConfigDialog:Open(name)
	-- Open the dialog
end

function AceConfigDialog:AddToBlizOptions(name, displayName, parent)
	if InterfaceOptions_AddCategory then
		local frame = CreateFrame("Frame", name .. "BlizOptions", UIParent)
		frame.name = displayName or name
		frame:SetScript("OnShow", function()
			local options = LibStub("AceConfigRegistry-3.0").options[name]
			if options then
				-- Display options
			end
		end)
		InterfaceOptions_AddCategory(frame)
	end
end
