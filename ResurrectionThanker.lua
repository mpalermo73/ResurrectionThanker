-- ============================================================
--  ResurrectionThanker  v2.0
--  Thanks healers when they resurrect you.
--  Zero library dependencies — uses modern WoW Settings API.
--
--  Settings in Interface > AddOns > Resurrection Thanker
--  Or type /rzt to open settings
-- ============================================================

local ADDON_NAME = "ResurrectionThanker"
local db
local settingsCategory

-- ── Resurrection spell IDs ────────────────────────────────────
local RES_SPELLS = {
	[2006]   = true,  -- Resurrection (Priest)
	[61999]  = true,  -- Raise Ally (Death Knight)
	[20484]  = true,  -- Rebirth (Druid)
	[391054] = true,  -- Revive (Druid, out-of-combat)
	[7328]   = true,  -- Redemption (Paladin)
	[391270] = true,  -- Ancestral Spirit (Shaman)
	[212056] = true,  -- Soulstone Resurrection (Warlock)
	[115178] = true,  -- Resuscitate (Monk)
	[361227] = true,  -- Return (Evoker)
	[50769]  = true,  -- Revive (non-combat generic)
	[8342]   = true,  -- Defibrillate
}

-- ── Runtime state ────────────────────────────────────────────
local lastRezzer = nil
local pendingRezzer = nil
local playerGUID = nil

-- ── Default settings ─────────────────────────────────────────
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
local CHANNEL_LABELS = { SAY = "Say", PARTY = "Party", RAID = "Raid", WHISPER = "Whisper" }

-- ── Helper functions ─────────────────────────────────────────
local function FormatMessage(index, name)
	local msg = db.messages[index] or db.messages[1]
	return msg:format(name or "healer")
end

local function SendThankYou(text)
	if not text or text == "" then return end
	local ch = db.channel
	if ch == "WHISPER" and lastRezzer then
		SendChatMessage(text, "WHISPER", nil, lastRezzer)
	elseif ch == "RAID" and IsInRaid() then
		SendChatMessage(text, "RAID")
	elseif ch == "PARTY" and IsInGroup() then
		SendChatMessage(text, "PARTY")
	else
		SendChatMessage(text, "SAY")
	end
end

local function ShowPopup(rezzerName)
	if not rezzerName or rezzerName == "" then return end

	local f = CreateFrame("Frame", ADDON_NAME .. "Popup", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(320, 160)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -15)
	title:SetText("Resurrection Thanker")

	local msg = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	msg:SetPoint("TOP", title, "BOTTOM", 0, -15)
	msg:SetText("You were resurrected by " .. rezzerName .. "!")

	local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	btn:SetSize(100, 24)
	btn:SetPoint("BOTTOM", 0, 12)
	btn:SetText("Thank!")
	btn:SetScript("OnClick", function()
		SendThankYou(FormatMessage(db.autoMessage, rezzerName))
		f:Hide()
	end)

	f:Show()

	if db.popupTimeout > 0 then
		C_Timer.After(db.popupTimeout, function()
			if f and f:IsShown() then f:Hide() end
		end)
	end
end

-- ── Open settings helper ─────────────────────────────────────
local function OpenSettings()
	if settingsCategory then
		Settings.OpenToCategory(settingsCategory:GetID())
	end
end

-- ── Settings panel (modern Settings API) ─────────────────────
local function CreateSettingsPanel()
	local panel = CreateFrame("Frame", ADDON_NAME .. "Options")

	-- Title
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Resurrection Thanker v2.0")

	local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	desc:SetText("Automatically thank healers when they resurrect you.")

	local y = -70

	-- ── Auto Reply checkbox ──────────────────────────────
	local autoReplyCheck = CreateFrame("CheckButton", ADDON_NAME .. "AutoReply", panel, "UICheckButtonTemplate")
	autoReplyCheck:SetPoint("TOPLEFT", 20, y)
	local autoReplyLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	autoReplyLabel:SetPoint("LEFT", autoReplyCheck, "RIGHT", 4, 0)
	autoReplyLabel:SetText("Auto Reply — Automatically send a thank-you when resurrected")
	autoReplyCheck:SetScript("OnClick", function(self) db.autoReply = self:GetChecked() end)
	y = y - 32

	-- ── Test Mode checkbox ───────────────────────────────
	local testModeCheck = CreateFrame("CheckButton", ADDON_NAME .. "TestMode", panel, "UICheckButtonTemplate")
	testModeCheck:SetPoint("TOPLEFT", 20, y)
	local testModeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	testModeLabel:SetPoint("LEFT", testModeCheck, "RIGHT", 4, 0)
	testModeLabel:SetText("Test Mode — Send real messages when using Simulate")
	testModeCheck:SetScript("OnClick", function(self) db.testMode = self:GetChecked() end)
	y = y - 40

	-- ── Channel selector (dropdown) ──────────────────────
	local channelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	channelLabel:SetPoint("TOPLEFT", 20, y)
	channelLabel:SetText("Chat Channel:")

	local channelDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	channelDropdown:SetPoint("LEFT", channelLabel, "RIGHT", 10, 0)
	channelDropdown:SetWidth(150)
	channelDropdown:SetupMenu(function(dropdown, rootDescription)
		for _, key in ipairs(CHANNEL_ORDER) do
			rootDescription:CreateRadio(
				CHANNEL_LABELS[key],
				function() return db.channel == key end,
				function() db.channel = key end
			)
		end
	end)
	y = y - 40

	-- ── Message list (radio buttons + editable text) ─────
	local msgLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	msgLabel:SetPoint("TOPLEFT", 20, y)
	msgLabel:SetText("Thank-You Messages (select one, edit text as needed):")
	y = y - 22

	local msgRadios = {}
	local msgEditBoxes = {}

	local function RefreshMsgRadios()
		for i, radio in ipairs(msgRadios) do
			radio:SetChecked(i == db.autoMessage)
		end
	end

	for i = 1, #db.messages do
		local radio = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
		radio:SetPoint("TOPLEFT", 30, y)
		radio:SetScript("OnClick", function()
			db.autoMessage = i
			RefreshMsgRadios()
		end)
		msgRadios[i] = radio

		local editBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
		editBox:SetPoint("LEFT", radio, "RIGHT", 8, 0)
		editBox:SetSize(400, 20)
		editBox:SetAutoFocus(false)
		editBox:SetScript("OnEnterPressed", function(self)
			db.messages[i] = self:GetText()
			self:ClearFocus()
		end)
		editBox:SetScript("OnEscapePressed", function(self)
			self:SetText(db.messages[i])
			self:ClearFocus()
		end)
		msgEditBoxes[i] = editBox

		y = y - 28
	end
	y = y - 10

	-- ── Popup timeout (dropdown) ─────────────────────────
	local timeoutValues = { 5, 10, 15, 20, 30, 45, 60 }

	local timeoutLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	timeoutLabel:SetPoint("TOPLEFT", 20, y)
	timeoutLabel:SetText("Popup Timeout:")

	local timeoutDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	timeoutDropdown:SetPoint("LEFT", timeoutLabel, "RIGHT", 10, 0)
	timeoutDropdown:SetWidth(150)
	timeoutDropdown:SetupMenu(function(dropdown, rootDescription)
		for _, val in ipairs(timeoutValues) do
			rootDescription:CreateRadio(
				val .. " seconds",
				function() return db.popupTimeout == val end,
				function() db.popupTimeout = val end
			)
		end
	end)
	y = y - 45

	-- ── Simulate button ──────────────────────────────────
	local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	testBtn:SetSize(180, 28)
	testBtn:SetPoint("TOPLEFT", 20, y)
	testBtn:SetText("Simulate Resurrection")
	testBtn:SetScript("OnClick", function()
		lastRezzer = "TestHealer"
		if db.autoReply then
			if db.testMode then
				SendThankYou(FormatMessage(db.autoMessage, "TestHealer"))
				print("|cff00ccff[RezThanker]|r Sent test message: " .. FormatMessage(db.autoMessage, "TestHealer"))
			else
				print("|cff00ccff[RezThanker]|r (TEST) Would send: " ..
					FormatMessage(db.autoMessage, "TestHealer") .. " via " .. db.channel)
			end
		else
			ShowPopup("TestHealer")
		end
	end)

	-- Refresh all controls when the panel is shown
	panel:SetScript("OnShow", function()
		autoReplyCheck:SetChecked(db.autoReply)
		testModeCheck:SetChecked(db.testMode)
		RefreshMsgRadios()
		for i, editBox in ipairs(msgEditBoxes) do
			editBox:SetText(db.messages[i] or "")
		end
	end)

	-- Register with modern Settings API (10.0+)
	settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Resurrection Thanker")
	Settings.RegisterAddOnCategory(settingsCategory)
end

-- ── SavedVariables initialization ────────────────────────────
local function InitDB()
	if not ResurrectionThankerDB then
		ResurrectionThankerDB = {}
	end
	for k, v in pairs(DEFAULTS) do
		if ResurrectionThankerDB[k] == nil then
			if type(v) == "table" then
				ResurrectionThankerDB[k] = {}
				for tk, tv in pairs(v) do
					ResurrectionThankerDB[k][tk] = tv
				end
			else
				ResurrectionThankerDB[k] = v
			end
		end
	end
	db = ResurrectionThankerDB
end

-- ── Slash command handler ────────────────────────────────────
local function SlashHandler(input)
	input = (input or ""):lower():match("^%s*(.-)%s*$")

	if input == "" or input == "config" or input == "options" then
		OpenSettings()
		return
	end

	if input == "help" then
		print("|cff00ccff[RezThanker]|r Slash commands:")
		print("  |cffFFD700/rzt|r — Open settings panel")
		print("  |cffFFD700/rzt test|r — Simulate a resurrection")
		print("  |cffFFD700/rzt status|r — Show current settings")
		return
	end

	if input == "test" then
		lastRezzer = "TestHealer"
		if db.autoReply then
			if db.testMode then
				SendThankYou(FormatMessage(db.autoMessage, "TestHealer"))
				print("|cff00ccff[RezThanker]|r Sent test message: " .. FormatMessage(db.autoMessage, "TestHealer"))
			else
				print("|cff00ccff[RezThanker]|r (TEST MODE OFF) Would send: " ..
					FormatMessage(db.autoMessage, "TestHealer") .. " via " .. db.channel)
			end
		else
			ShowPopup("TestHealer")
		end
		return
	end

	if input == "status" then
		print("|cff00ccff[RezThanker]|r Current settings:")
		print("  Auto-reply: " .. (db.autoReply and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
		print("  Channel: " .. db.channel)
		print("  Popup timeout: " .. db.popupTimeout .. "s")
		print("  Auto-message: #" .. db.autoMessage .. " — " .. FormatMessage(db.autoMessage, "Healer"))
		print("  Test mode: " .. (db.testMode and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
		return
	end

	print("|cff00ccff[RezThanker]|r Unknown command: |cffFFD700" .. input .. "|r — try |cffFFD700/rzt help|r")
end

-- ── Event handling (no libraries needed) ─────────────────────
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddon = ...
		if loadedAddon == ADDON_NAME then
			InitDB()
			C_Timer.After(0, CreateSettingsPanel)

			SLASH_REZTHANKER1 = "/rzt"
			SLASH_REZTHANKER2 = "/rezthanker"
			SlashCmdList["REZTHANKER"] = SlashHandler

			print("|cff00ccff[Resurrection Thanker]|r v2.0 loaded - type |cffFFD700/rzt|r to open settings")
			self:UnregisterEvent("ADDON_LOADED")
		end

	elseif event == "PLAYER_LOGIN" then
		playerGUID = UnitGUID("player")

	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subEvent, _, _, sourceName, _, _, destGUID, _, _, _, spellID =
			CombatLogGetCurrentEventInfo()

		if (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_RESURRECT")
			and destGUID == playerGUID
			and (RES_SPELLS[spellID] or subEvent == "SPELL_RESURRECT")
		then
			pendingRezzer = sourceName
		end

	elseif event == "PLAYER_ALIVE" then
		local rezzer = pendingRezzer or lastRezzer
		pendingRezzer = nil
		if not rezzer then return end

		lastRezzer = rezzer

		if db.autoReply then
			C_Timer.After(1.5, function()
				SendThankYou(FormatMessage(db.autoMessage, rezzer))
			end)
		else
			C_Timer.After(1.0, function()
				ShowPopup(rezzer)
			end)
		end
	end
end)
