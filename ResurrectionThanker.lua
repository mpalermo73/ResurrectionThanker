-- ============================================================
--  ResurrectionThanker
--  Thanks the player who resurrected you.
-- ============================================================

local ADDON_NAME = ...
local DISPLAY_NAME = "Resurrection Thanker"
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version") or "2.0"

local db
local settingsCategory
local lastRezzer
local pendingRezzer
local pendingRezTime = 0
local popup

local RESURRECTION_SPELLS = {
	[2006] = true,   -- Resurrection
	[2008] = true,   -- Ancestral Spirit
	[7328] = true,   -- Redemption
	[8342] = true,   -- Defibrillate
	[20484] = true,  -- Rebirth
	[50769] = true,  -- Revive
	[61999] = true,  -- Raise Ally
	[115178] = true, -- Resuscitate
	[212036] = true, -- Mass Resurrection
	[212056] = true, -- Soulstone Resurrection
	[361227] = true, -- Return
	[391054] = true, -- Improved Revive
	[391270] = true, -- Improved Ancestral Spirit
}

local DEFAULTS = {
	autoReply = false,
	autoMessage = 1,
	channel = "SAY",
	popupTimeout = 20,
	testMode = false,
	messages = {
		"Thanks for the rez, %s!",
		"Appreciate the resurrection, %s!",
		"Back from the dead thanks to %s!",
		"Couldn't have made it without you, %s! Thank you!",
		"bless u %s <3",
	},
}

local CHANNEL_ORDER = { "SAY", "PARTY", "RAID", "WHISPER" }
local CHANNEL_LABELS = {
	SAY = "Say",
	PARTY = "Party",
	RAID = "Raid",
	WHISPER = "Whisper",
}

local POPUP_TIMEOUTS = { 5, 10, 15, 20, 30, 45, 60 }
local RESURRECTION_WINDOW_SECONDS = 30

local function Print(message)
	print("|cff00ccff[RezThanker]|r " .. tostring(message))
end

local function CopyDefaults(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and CopyDefaults(value) or value
	end
	return copy
end

local function ContainsValue(values, needle)
	for _, value in ipairs(values) do
		if value == needle then
			return true
		end
	end
	return false
end

local function InitDB()
	ResurrectionThankerDB = type(ResurrectionThankerDB) == "table" and ResurrectionThankerDB or {}

	for key, value in pairs(DEFAULTS) do
		if ResurrectionThankerDB[key] == nil then
			ResurrectionThankerDB[key] = type(value) == "table" and CopyDefaults(value) or value
		end
	end

	if type(ResurrectionThankerDB.messages) ~= "table" then
		ResurrectionThankerDB.messages = CopyDefaults(DEFAULTS.messages)
	else
		for index, message in ipairs(DEFAULTS.messages) do
			if type(ResurrectionThankerDB.messages[index]) ~= "string" or ResurrectionThankerDB.messages[index] == "" then
				ResurrectionThankerDB.messages[index] = message
			end
		end
	end

	if type(ResurrectionThankerDB.autoReply) ~= "boolean" then
		ResurrectionThankerDB.autoReply = DEFAULTS.autoReply
	end
	if type(ResurrectionThankerDB.testMode) ~= "boolean" then
		ResurrectionThankerDB.testMode = DEFAULTS.testMode
	end
	if type(ResurrectionThankerDB.autoMessage) ~= "number" or not ResurrectionThankerDB.messages[ResurrectionThankerDB.autoMessage] then
		ResurrectionThankerDB.autoMessage = DEFAULTS.autoMessage
	end
	if not CHANNEL_LABELS[ResurrectionThankerDB.channel] then
		ResurrectionThankerDB.channel = DEFAULTS.channel
	end
	if type(ResurrectionThankerDB.popupTimeout) ~= "number" or not ContainsValue(POPUP_TIMEOUTS, ResurrectionThankerDB.popupTimeout) then
		ResurrectionThankerDB.popupTimeout = DEFAULTS.popupTimeout
	end

	db = ResurrectionThankerDB
end

local function GetDisplayName(name)
	if not name or name == "" then
		return "healer"
	end
	return Ambiguate and Ambiguate(name, "short") or name
end

local function FormatMessage(index, name)
	local template = db.messages[index] or db.messages[1] or DEFAULTS.messages[1]
	local ok, formatted = pcall(string.format, template, GetDisplayName(name))
	if ok then
		return formatted
	end
	return template .. " " .. GetDisplayName(name)
end

local function GetChatChannel()
	if db.channel == "RAID" and IsInRaid() then
		return "RAID"
	end
	if db.channel == "PARTY" and IsInGroup() then
		return "PARTY"
	end
	if db.channel == "WHISPER" and lastRezzer then
		return "WHISPER"
	end
	return "SAY"
end

local function SendThankYou(text, target)
	if type(text) ~= "string" or text == "" then
		return
	end

	local channel = GetChatChannel()
	if channel == "WHISPER" then
		SendChatMessage(text, "WHISPER", nil, target or lastRezzer)
	else
		SendChatMessage(text, channel)
	end
end

local function IsGroupUnit(unit)
	if type(unit) ~= "string" then
		return false
	end

	return unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$")
end

local function GetUnitName(unit)
	if UnitNameUnmodified then
		local name, realm = UnitNameUnmodified(unit)
		if name and realm and realm ~= "" then
			return name .. "-" .. realm
		end
		return name
	end

	return UnitName(unit)
end

local function UnitTargetsPlayer(unit)
	return UnitExists(unit .. "target") and UnitIsUnit(unit .. "target", "player")
end

local function TrackResurrectionCast(unit, spellID)
	if not IsGroupUnit(unit) or not RESURRECTION_SPELLS[spellID] or not UnitTargetsPlayer(unit) then
		return
	end

	pendingRezzer = GetUnitName(unit)
	pendingRezTime = GetTime()
end

local function HidePopup()
	if popup then
		popup:Hide()
	end
end

local function CreatePopup()
	if popup then
		return popup
	end

	local frame = CreateFrame("Frame", ADDON_NAME .. "Popup", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(420, 270)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", 0, -14)
	frame.title:SetText(DISPLAY_NAME)

	frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.message:SetPoint("TOP", frame.title, "BOTTOM", 0, -16)
	frame.message:SetWidth(380)

	frame.messageButtons = {}
	for index = 1, #DEFAULTS.messages do
		local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		button:SetSize(360, 24)
		if index == 1 then
			button:SetPoint("TOP", frame.message, "BOTTOM", 0, -16)
		else
			button:SetPoint("TOP", frame.messageButtons[index - 1], "BOTTOM", 0, -6)
		end
		button:SetScript("OnClick", function()
			SendThankYou(FormatMessage(index, frame.rezzer), frame.rezzer)
			HidePopup()
		end)
		frame.messageButtons[index] = button
	end

	frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.closeButton:SetSize(120, 24)
	frame.closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
	frame.closeButton:SetText("Dismiss")
	frame.closeButton:SetScript("OnClick", HidePopup)

	popup = frame
	return popup
end

local function ShowPopup(rezzerName)
	if not rezzerName or rezzerName == "" then
		return
	end

	local frame = CreatePopup()
	frame.rezzer = rezzerName
	frame.message:SetText("You were resurrected by " .. GetDisplayName(rezzerName) .. ".")
	for index, button in ipairs(frame.messageButtons) do
		button:SetText(FormatMessage(index, rezzerName))
	end
	frame:Show()

	if db.popupTimeout > 0 then
		local rezzerAtShow = rezzerName
		C_Timer.After(db.popupTimeout, function()
			if popup and popup:IsShown() and popup.rezzer == rezzerAtShow then
				popup:Hide()
			end
		end)
	end
end

local function OpenSettings()
	if not settingsCategory then
		return
	end

	local categoryID = settingsCategory.GetID and settingsCategory:GetID() or settingsCategory.ID
	if categoryID then
		Settings.OpenToCategory(categoryID)
		Settings.OpenToCategory(categoryID)
	end
end

local function CreateLabeledCheckButton(parent, name, label, tooltip)
	local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
	local text = check.Text or _G[name .. "Text"]
	if text then
		text:SetText(label)
	end
	if tooltip then
		check.tooltipText = label
		check.tooltipRequirement = tooltip
	end
	return check
end

local function SetDropdownText(dropdown, text)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(text)
	elseif dropdown.SetText then
		dropdown:SetText(text)
	end
end

local function CreateSettingsPanel()
	if settingsCategory then
		return
	end

	local panel = CreateFrame("Frame", ADDON_NAME .. "Options")
	panel.name = DISPLAY_NAME

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText(DISPLAY_NAME .. " v" .. VERSION)

	local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	desc:SetText("Thank the player who resurrected you.")

	local autoReplyCheck = CreateLabeledCheckButton(
		panel,
		ADDON_NAME .. "AutoReply",
		"Auto reply",
		"Send the selected thank-you automatically instead of showing the popup."
	)
	autoReplyCheck:SetPoint("TOPLEFT", 20, -68)
	autoReplyCheck:SetScript("OnClick", function(self)
		db.autoReply = self:GetChecked()
	end)

	local testModeCheck = CreateLabeledCheckButton(
		panel,
		ADDON_NAME .. "TestMode",
		"Test mode sends real chat messages",
		"Leave this off to preview /rzt test without sending chat."
	)
	testModeCheck:SetPoint("TOPLEFT", autoReplyCheck, "BOTTOMLEFT", 0, -8)
	testModeCheck:SetScript("OnClick", function(self)
		db.testMode = self:GetChecked()
	end)

	local channelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	channelLabel:SetPoint("TOPLEFT", testModeCheck, "BOTTOMLEFT", 0, -18)
	channelLabel:SetText("Chat channel")

	local channelDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	channelDropdown:SetPoint("LEFT", channelLabel, "RIGHT", 16, 0)
	channelDropdown:SetWidth(150)
	channelDropdown:SetupMenu(function(_, rootDescription)
		for _, key in ipairs(CHANNEL_ORDER) do
			rootDescription:CreateRadio(CHANNEL_LABELS[key], function()
				return db.channel == key
			end, function()
				db.channel = key
				SetDropdownText(channelDropdown, CHANNEL_LABELS[key])
			end)
		end
	end)

	local timeoutLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	timeoutLabel:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -28)
	timeoutLabel:SetText("Popup timeout")

	local timeoutDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	timeoutDropdown:SetPoint("LEFT", timeoutLabel, "RIGHT", 16, 0)
	timeoutDropdown:SetWidth(150)
	timeoutDropdown:SetupMenu(function(_, rootDescription)
		for _, seconds in ipairs(POPUP_TIMEOUTS) do
			rootDescription:CreateRadio(seconds .. " seconds", function()
				return db.popupTimeout == seconds
			end, function()
				db.popupTimeout = seconds
				SetDropdownText(timeoutDropdown, seconds .. " seconds")
			end)
		end
	end)

	local messageLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	messageLabel:SetPoint("TOPLEFT", timeoutLabel, "BOTTOMLEFT", 0, -30)
	messageLabel:SetText("Messages")

	local selectedButtons = {}
	local editBoxes = {}

	local function RefreshMessages()
		autoReplyCheck:SetChecked(db.autoReply)
		testModeCheck:SetChecked(db.testMode)
		SetDropdownText(channelDropdown, CHANNEL_LABELS[db.channel])
		SetDropdownText(timeoutDropdown, db.popupTimeout .. " seconds")

		for index, check in ipairs(selectedButtons) do
			check:SetChecked(index == db.autoMessage)
		end
		for index, editBox in ipairs(editBoxes) do
			editBox:SetText(db.messages[index] or "")
		end
	end

	local previous = messageLabel
	for index = 1, #DEFAULTS.messages do
		local selectButton = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
		if index == 1 then
			selectButton:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 4, -10)
		else
			selectButton:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -8)
		end
		selectButton:SetScript("OnClick", function()
			db.autoMessage = index
			RefreshMessages()
		end)
		selectedButtons[index] = selectButton

		local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
		editBox:SetPoint("LEFT", selectButton, "RIGHT", 8, 0)
		editBox:SetSize(430, 24)
		editBox:SetAutoFocus(false)
		editBox:SetScript("OnEnterPressed", function(self)
			db.messages[index] = self:GetText()
			self:ClearFocus()
		end)
		editBox:SetScript("OnEditFocusLost", function(self)
			local value = self:GetText()
			db.messages[index] = value ~= "" and value or DEFAULTS.messages[index]
			self:SetText(db.messages[index])
		end)
		editBox:SetScript("OnEscapePressed", function(self)
			self:SetText(db.messages[index] or DEFAULTS.messages[index])
			self:ClearFocus()
		end)
		editBoxes[index] = editBox
		previous = selectButton
	end

	local testButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	testButton:SetSize(180, 26)
	testButton:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -18)
	testButton:SetText("Simulate Resurrection")
	testButton:SetScript("OnClick", function()
		lastRezzer = UnitNameUnmodified and UnitNameUnmodified("player") or UnitName("player") or "TestHealer"
		if db.autoReply then
			local message = FormatMessage(db.autoMessage, lastRezzer)
			if db.testMode then
				SendThankYou(message, lastRezzer)
				Print("Sent test message: " .. message)
			else
				Print("(test preview) Would send: " .. message .. " via " .. db.channel)
			end
		else
			ShowPopup(lastRezzer)
		end
	end)

	panel:SetScript("OnShow", RefreshMessages)

	settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, DISPLAY_NAME)
	Settings.RegisterAddOnCategory(settingsCategory)
end

local function RunThankYou(rezzer)
	pendingRezzer = nil
	pendingRezTime = 0

	if not rezzer or rezzer == "" then
		return
	end

	lastRezzer = rezzer

	if db.autoReply then
		C_Timer.After(1.5, function()
			SendThankYou(FormatMessage(db.autoMessage, rezzer), rezzer)
		end)
	else
		C_Timer.After(1.0, function()
			ShowPopup(rezzer)
		end)
	end
end

local function SlashHandler(input)
	input = (input or ""):lower():match("^%s*(.-)%s*$")

	if input == "" or input == "config" or input == "options" then
		OpenSettings()
		return
	end

	if input == "help" then
		Print("Slash commands:")
		print("  |cffFFD700/rzt|r - Open settings")
		print("  |cffFFD700/rzt test|r - Simulate a resurrection")
		print("  |cffFFD700/rzt status|r - Show current settings")
		return
	end

	if input == "test" then
		lastRezzer = UnitNameUnmodified and UnitNameUnmodified("player") or UnitName("player") or "TestHealer"
		if db.autoReply then
			local message = FormatMessage(db.autoMessage, lastRezzer)
			if db.testMode then
				SendThankYou(message, lastRezzer)
				Print("Sent test message: " .. message)
			else
				Print("(test preview) Would send: " .. message .. " via " .. db.channel)
			end
		else
			ShowPopup(lastRezzer)
		end
		return
	end

	if input == "status" then
		Print("Current settings:")
		print("  Auto reply: " .. (db.autoReply and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
		print("  Channel: " .. CHANNEL_LABELS[db.channel])
		print("  Popup timeout: " .. db.popupTimeout .. "s")
		print("  Auto message: #" .. db.autoMessage .. " - " .. FormatMessage(db.autoMessage, "Healer"))
		print("  Test mode: " .. (db.testMode and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
		return
	end

	Print("Unknown command: |cffFFD700" .. input .. "|r - try |cffFFD700/rzt help|r")
end

local addonFrame = CreateFrame("Frame")
addonFrame:RegisterEvent("ADDON_LOADED")
addonFrame:RegisterEvent("PLAYER_LOGIN")
addonFrame:RegisterEvent("PLAYER_ALIVE")
addonFrame:RegisterEvent("UNIT_SPELLCAST_START")
addonFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
addonFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddon = ...
		if loadedAddon ~= ADDON_NAME then
			return
		end

		InitDB()

		SLASH_REZTHANKER1 = "/rzt"
		SLASH_REZTHANKER2 = "/rezthanker"
		SlashCmdList.REZTHANKER = SlashHandler

		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		CreateSettingsPanel()
		Print("v" .. VERSION .. " loaded - type |cffFFD700/rzt|r to open settings")
	elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, _, spellID = ...
		TrackResurrectionCast(unit, spellID)
	elseif event == "PLAYER_ALIVE" then
		if pendingRezzer and (GetTime() - pendingRezTime) <= RESURRECTION_WINDOW_SECONDS then
			RunThankYou(pendingRezzer)
		end
	end
end)
