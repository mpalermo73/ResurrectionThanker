-- ============================================================
--  ResurrectionThanker  v1.2
--  Thanks healers when they resurrect you.
--
--  Interface -> AddOns shows a stub with a launch button.
--  The real config is our own taint-free frame (/rzt to open).
-- ============================================================

local ADDON_NAME = "ResurrectionThanker"

-- ── Defaults ──────────────────────────────────────────────────
local defaults = {
    autoReply    = false,
    autoMessage  = 1,
    channel      = "SAY",
    popupTimeout = 20,
    messages = {
        "Thanks for the rez, %s!",
        "Appreciate the resurrection, %s!",
        "Back from the dead thanks to %s!",
        "Couldn't have made it without you, %s! Thank you!",
        "bless u %s <3",
    },
}

-- ── SavedVariables ────────────────────────────────────────────
local db
local function InitDB()
    if not ResurrectionThankerDB then
        ResurrectionThankerDB = CopyTable(defaults)
    end
    db = ResurrectionThankerDB
    for k, v in pairs(defaults) do
        if db[k] == nil then db[k] = v end
    end
    if not db.messages then db.messages = CopyTable(defaults.messages) end
end

-- ── Runtime state ─────────────────────────────────────────────
local lastRezzer    = nil
local popupFrame    = nil
local configFrame   = nil
local playerGUID    = nil
local pendingRezzer = nil

local function GetPlayerGUID()
    if not playerGUID then playerGUID = UnitGUID("player") end
    return playerGUID
end

local function FormatMessage(index, name)
    local msg = db.messages[index] or db.messages[1]
    return msg:format(name or "healer")
end

local function SendThankYou(text)
    if not text or text == "" then return end
    local ch = db.channel
    if     ch == "WHISPER" and lastRezzer  then SendChatMessage(text, "WHISPER", nil, lastRezzer)
    elseif ch == "RAID"    and IsInRaid()  then SendChatMessage(text, "RAID")
    elseif ch == "PARTY"   and IsInGroup() then SendChatMessage(text, "PARTY")
    else                                        SendChatMessage(text, "SAY")
    end
end

-- ── Forward declare so popup can call it ──────────────────────
local ShowConfig

-- ── Rez thank-you popup ───────────────────────────────────────
local BUTTON_COUNT = 5

local function BuildPopup()
    if popupFrame then return popupFrame end

    local f = CreateFrame("Frame", "ResurrectionThankerPopup", UIParent, "BackdropTemplate")
    f:SetSize(340, 260)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left=11, right=12, top=12, bottom=11 },
    })
    f:SetBackdropColor(0, 0, 0, 1)
    f:SetBackdropBorderColor(1, 1, 1, 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", f, "TOP", 0, -18)
    title:SetText("You were resurrected!")

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    sub:SetTextColor(0.8, 0.8, 0.8)
    f.subtitle = sub

    f.buttons = {}
    for i = 1, BUTTON_COUNT do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(290, 26)
        btn:SetPoint("TOP", f, "TOP", 0, -68 - (i - 1) * 32)
        btn:SetScript("OnClick", function()
            SendThankYou(FormatMessage(i, lastRezzer))
            f:Hide()
        end)
        f.buttons[i] = btn
    end

    local dismiss = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    dismiss:SetSize(120, 26)
    dismiss:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    dismiss:SetText("Cancel")
    dismiss:SetScript("OnClick", function() f:Hide() end)
    f.dismiss = dismiss

    local countdown = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countdown:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
    countdown:SetTextColor(0.5, 0.5, 0.5)
    f.countdown = countdown

    f:SetScript("OnUpdate", function(self, elapsed)
        self._timer = (self._timer or 0) + elapsed
        local rem = self._timeout - self._timer
        if rem <= 0 then
            self:Hide()
        else
            self.countdown:SetText(string.format("%.0fs", rem))
        end
    end)

    f:Hide()
    popupFrame = f
    return f
end

local function ShowPopup(rezzerName)
    local f = BuildPopup()
    f.subtitle:SetText(rezzerName and ("Resurrected by: |cff00ff00" .. rezzerName .. "|r") or "")

    local PADDING  = 40
    local MIN_W    = 300
    local maxWidth = MIN_W

    for i = 1, BUTTON_COUNT do
        local msg = db.messages[i]
        if msg then
            f.buttons[i]:SetText(msg:format(rezzerName or "healer"))
            f.buttons[i]:Show()
            local strW = f.buttons[i]:GetFontString():GetStringWidth()
            if strW + PADDING > maxWidth then maxWidth = strW + PADDING end
        else
            f.buttons[i]:Hide()
        end
    end

    local frameW = maxWidth + 40
    f:SetWidth(frameW)
    for i = 1, BUTTON_COUNT do
        f.buttons[i]:SetWidth(maxWidth)
        f.buttons[i]:ClearAllPoints()
        f.buttons[i]:SetPoint("TOP", f, "TOP", 0, -68 - (i - 1) * 32)
    end
    f.dismiss:SetWidth(math.max(100, maxWidth * 0.4))

    f._timer   = 0
    f._timeout = db.popupTimeout
    f:Show()
end

-- ── Full config frame (taint-free, our own UI) ────────────────
local function BuildConfig()
    if configFrame then return configFrame end

    local f = CreateFrame("Frame", "ResurrectionThankerConfig", UIParent, "BackdropTemplate")
    f:SetSize(480, 520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left=11, right=12, top=12, bottom=11 },
    })
    f:SetBackdropColor(0, 0, 0, 1)
    f:SetBackdropBorderColor(1, 1, 1, 1)

    -- Close on Escape
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
    end)
    f:SetPropagateKeyboardInput(true)

    -- ── Title bar ─────────────────────────────────────────────
    local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleFS:SetPoint("TOP", f, "TOP", 0, -16)
    titleFS:SetText("|TInterface\\AddOns\\ResurrectionThanker\\ResurrectionThanker:20:20|t  Resurrection Thanker")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT",  f, "TOPLEFT",  16, -38)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -38)
    divider:SetHeight(1)
    divider:SetColorTexture(0.5, 0.5, 0.5, 0.6)

    -- ── Layout helpers ────────────────────────────────────────
    local yOff = -50

    local function SectionLabel(text)
        yOff = yOff - 8
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", 16, yOff)
        fs:SetText(text)
        fs:SetTextColor(1, 0.82, 0)
        yOff = yOff - 20
        local line = f:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT",  f, "TOPLEFT",  16, yOff)
        line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, yOff)
        line:SetHeight(1)
        line:SetColorTexture(0.4, 0.4, 0.4, 0.6)
        yOff = yOff - 10
    end

    -- ── Section: Behaviour ────────────────────────────────────
    SectionLabel("Behaviour")

    -- Auto-reply checkbox
    local autoCB = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    autoCB:SetPoint("TOPLEFT", f, "TOPLEFT", 12, yOff)
    autoCB:SetChecked(db.autoReply)
    autoCB:SetScript("OnClick", function(self) db.autoReply = self:GetChecked() end)
    local autoCBLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoCBLabel:SetPoint("LEFT", autoCB, "RIGHT", 2, 0)
    autoCBLabel:SetText("Auto-reply (skip popup)")
    local autoCBDesc = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoCBDesc:SetPoint("TOPLEFT", f, "TOPLEFT", 42, yOff - 22)
    autoCBDesc:SetText("Send a thank-you automatically without showing the button dialog.")
    autoCBDesc:SetTextColor(0.6, 0.6, 0.6)
    yOff = yOff - 50

    -- Channel — plain button row (no UIDropDownMenu, no taint)
    local chanLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chanLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, yOff)
    chanLabel:SetText("Chat channel:")
    local channels = { "SAY", "PARTY", "RAID", "WHISPER" }
    local chanBtns = {}
    local xPos = 130
    for _, ch in ipairs(channels) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(72, 22)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", xPos, yOff + 2)
        btn:SetText(ch)
        local captCh = ch
        btn:SetScript("OnClick", function()
            db.channel = captCh
            for _, b in pairs(chanBtns) do
                b:SetEnabled(true)
            end
            btn:SetEnabled(false)
        end)
        chanBtns[ch] = btn
        xPos = xPos + 78
    end
    -- Disable the currently selected one on show
    f._chanBtns = chanBtns
    yOff = yOff - 36

    -- Popup timeout slider
    local timeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, yOff)
    timeLabel:SetText("Popup timeout:")
    local timeValFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeValFS:SetPoint("LEFT", timeLabel, "RIGHT", 8, 0)
    timeValFS:SetText(db.popupTimeout .. "s")
    yOff = yOff - 8
    local timeSlider = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")
    timeSlider:SetPoint("TOPLEFT", f, "TOPLEFT", 18, yOff)
    timeSlider:SetWidth(280)
    timeSlider:SetMinMaxValues(5, 60)
    timeSlider:SetValueStep(1)
    timeSlider:SetObeyStepOnDrag(true)
    timeSlider:SetValue(db.popupTimeout)
    timeSlider.Low:SetText("5s")
    timeSlider.High:SetText("60s")
    timeSlider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val + 0.5)
        db.popupTimeout = val
        timeValFS:SetText(val .. "s")
    end)
    f._timeSlider = timeSlider
    yOff = yOff - 44

    -- ── Section: Messages ─────────────────────────────────────
    SectionLabel("Messages")

    local msgNote = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    msgNote:SetPoint("TOPLEFT", f, "TOPLEFT", 16, yOff)
    msgNote:SetText("Use %s as a placeholder for the healer's name.  " ..
                    "|cffFFD700\xe2\x97\x8f|r = message used for auto-reply.")
    msgNote:SetTextColor(0.65, 0.65, 0.65)
    yOff = yOff - 24

    f._radioButtons = {}
    f._messageBoxes = {}

    for i = 1, BUTTON_COUNT do
        local radio = CreateFrame("CheckButton", nil, f, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", f, "TOPLEFT", 12, yOff)
        radio:SetChecked(db.autoMessage == i)
        local captI = i
        radio:SetScript("OnClick", function(self)
            db.autoMessage = captI
            for _, r in ipairs(f._radioButtons) do r:SetChecked(r == self) end
        end)

        local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        eb:SetPoint("LEFT", radio, "RIGHT", 4, 0)
        eb:SetWidth(390)
        eb:SetHeight(22)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(200)
        eb:SetText(db.messages[i] or "")
        eb:SetCursorPosition(0)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)
        eb:SetScript("OnEditFocusLost", function(self)
            local txt = self:GetText()
            if txt and txt ~= "" then db.messages[captI] = txt end
        end)

        f._radioButtons[i] = radio
        f._messageBoxes[i] = eb
        yOff = yOff - 30
    end

    -- ── Section: Actions ──────────────────────────────────────
    SectionLabel("Actions")

    local testBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    testBtn:SetSize(200, 26)
    testBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 16, yOff)
    testBtn:SetText("Simulate a resurrection")
    testBtn:SetScript("OnClick", function()
        lastRezzer = "TestHealer"
        if db.autoReply then
            print("|cff00ccff[RezThanker]|r (TEST) Would send: " ..
                  FormatMessage(db.autoMessage, "TestHealer"))
        else
            ShowPopup("TestHealer")
        end
    end)

    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(150, 26)
    resetBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
    resetBtn:SetText("Reset to defaults")
    resetBtn:SetScript("OnClick", function()
        StaticPopupDialogs["REZTHANKER_RESET"] = {
            text         = "Reset all Resurrection Thanker settings to defaults?\nThis will reload the UI.",
            button1      = "Reset",
            button2      = "Cancel",
            OnAccept     = function()
                ResurrectionThankerDB = CopyTable(defaults)
                db = ResurrectionThankerDB
                ReloadUI()
            end,
            timeout      = 0,
            whileDead    = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("REZTHANKER_RESET")
    end)

    -- ── Refresh on show ───────────────────────────────────────
    f:SetScript("OnShow", function()
        autoCB:SetChecked(db.autoReply)
        timeSlider:SetValue(db.popupTimeout)
        timeValFS:SetText(db.popupTimeout .. "s")
        for ch, btn in pairs(f._chanBtns) do
            btn:SetEnabled(db.channel ~= ch)
        end
        for i, r in ipairs(f._radioButtons) do
            r:SetChecked(db.autoMessage == i)
        end
        for i, eb in ipairs(f._messageBoxes) do
            eb:SetText(db.messages[i] or "")
        end
    end)

    f:Hide()
    configFrame = f
    return f
end

-- Assign the forward-declared function
ShowConfig = function()
    local f = BuildConfig()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

-- ── Native Settings stub ──────────────────────────────────────
--  Bare-minimum canvas: just a description and a launch button.
--  No dropdowns, no sliders, nothing that can taint.
local function BuildSettingsStub()
    local canvas = CreateFrame("Frame", "ResurrectionThankerSettingsStub")
    canvas:SetSize(700, 200)

    local icon = canvas:CreateTexture(nil, "ARTWORK")
    icon:SetSize(48, 48)
    icon:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
    icon:SetTexture("Interface\\AddOns\\ResurrectionThanker\\ResurrectionThanker")

    local titleFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleFS:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, 0)
    titleFS:SetText("Resurrection Thanker")

    local descFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -6)
    descFS:SetText("Automatically thanks healers when they resurrect you.")
    descFS:SetTextColor(0.8, 0.8, 0.8)

    local openBtn = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    openBtn:SetSize(220, 28)
    openBtn:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -90)
    openBtn:SetText("Open Resurrection Thanker Settings")
    openBtn:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel)   -- close the native panel first
        ShowConfig()
    end)

    local hintFS = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintFS:SetPoint("LEFT", openBtn, "RIGHT", 10, 0)
    hintFS:SetText("or type  |cffFFD700/rzt|r  in chat")
    hintFS:SetTextColor(0.6, 0.6, 0.6)

    local ok, cat = pcall(function()
        return Settings.RegisterCanvasLayoutCategory(canvas, "Resurrection Thanker")
    end)
    if ok and cat then
        Settings.RegisterAddOnCategory(cat)
    end
end

-- ── Spell IDs ─────────────────────────────────────────────────
local RES_SPELLS = {
    [2006]   = true,  -- Resurrection (Priest)
    [61999]  = true,  -- Raise Ally (DK)
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

-- ── Event frame ───────────────────────────────────────────────
local eventFrame = CreateFrame("Frame", ADDON_NAME .. "EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= ADDON_NAME then return end
        InitDB()
        playerGUID = UnitGUID("player")
        BuildSettingsStub()

        SLASH_REZTHANKER1 = "/rezthanker"
        SLASH_REZTHANKER2 = "/rzt"
        SlashCmdList["REZTHANKER"] = SlashHandler

        print("|cff00ccff[Resurrection Thanker]|r loaded — type |cffFFD700/rzt|r to configure.")

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, _, sourceName, _, _, destGUID, _, _, _, spellID =
            CombatLogGetCurrentEventInfo()
        if (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_RESURRECT")
            and destGUID == GetPlayerGUID()
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

-- ── Slash commands ────────────────────────────────────────────
function SlashHandler(input)
    input = (input or ""):lower():trim()

    if input == "" or input == "config" or input == "options" then
        ShowConfig()
        return
    end

    if input == "help" then
        print("|cff00ccff[RezThanker]|r  /rzt [command]")
        print("  (none)         Open settings")
        print("  auto on|off    Toggle auto-reply")
        print("  channel <say|party|raid|whisper>")
        print("  timeout <5-60>")
        print("  automsg <1-5>  Set auto-reply message index")
        print("  test           Simulate a rez from 'TestHealer'")
        print("  status         Print current settings")
        return
    end

    local cmd, arg = input:match("^(%S+)%s*(.*)")
    cmd = cmd or ""
    arg = arg or ""

    if cmd == "auto" then
        if     arg == "on"  then db.autoReply = true;  print("[RezThanker] Auto-reply |cff00ff00ON|r")
        elseif arg == "off" then db.autoReply = false; print("[RezThanker] Auto-reply |cffff4444OFF|r")
        end

    elseif cmd == "channel" then
        local ch = arg:upper()
        if ch == "SAY" or ch == "PARTY" or ch == "RAID" or ch == "WHISPER" then
            db.channel = ch
            print("[RezThanker] Channel: " .. ch)
        else
            print("[RezThanker] Valid channels: say, party, raid, whisper")
        end

    elseif cmd == "timeout" then
        local s = tonumber(arg)
        if s and s >= 5 and s <= 60 then
            db.popupTimeout = s
            print("[RezThanker] Popup timeout: " .. s .. "s")
        else
            print("[RezThanker] Timeout must be between 5 and 60.")
        end

    elseif cmd == "automsg" then
        local idx = tonumber(arg)
        if idx and idx >= 1 and idx <= #db.messages then
            db.autoMessage = idx
            print("[RezThanker] Auto-reply message set to #" .. idx)
        else
            print("[RezThanker] Valid range: 1–" .. #db.messages)
        end

    elseif cmd == "test" then
        lastRezzer = "TestHealer"
        if db.autoReply then
            print("|cff00ccff[RezThanker]|r (TEST) Would send: " ..
                  FormatMessage(db.autoMessage, "TestHealer"))
        else
            ShowPopup("TestHealer")
        end

    elseif cmd == "status" then
        print("|cff00ccff[RezThanker] Status:|r")
        print("  Auto-reply : " .. (db.autoReply and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
        print("  Channel    : " .. db.channel)
        print("  Timeout    : " .. db.popupTimeout .. "s")
        print("  Auto msg   : #" .. db.autoMessage .. " — " .. (db.messages[db.autoMessage] or "?"))

    else
        print("[RezThanker] Unknown command: '" .. cmd .. "'. Try /rzt help.")
    end
end
