--- AceDBOptions-3.0.lua
local MAJOR, MINOR = "AceDBOptions-3.0", 14
local AceDBOptions = LibStub:NewLibrary(MAJOR, MINOR)

if not AceDBOptions then return end

function AceDBOptions:GetOptionsTable(db)
	return {
		name = "Profiles",
		type = "group",
		args = {
			current = {
				name = "Current Profile",
				type = "description",
				order = 1,
			},
		},
	}
end
