--- AceConsole-3.0.lua
local MAJOR, MINOR = "AceConsole-3.0", 7
local AceConsole, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConsole then return end

local format = string.format
local strsub = string.sub
local strgsub = string.gsub
local strfind = string.find
local strbyte = string.byte
local strchar = string.char
local tinsert = table.insert
local tconcat = table.concat

local function Print(self, frame, ...)
	local text = tconcat({...}, " ")
	if strsub(text, 1, 1) == "/" then
		text = strgsub(text, "/", "", 1)
	end
	if frame then
		frame:AddMessage(text)
	else
		DEFAULT_CHAT_FRAME:AddMessage(text)
	end
end

function AceConsole:Embed(target)
	target.Print = Print
	target.Printf = function(self, frame, fmt, ...)
		Print(self, frame, format(fmt, ...))
	end
end

function AceConsole:RegisterChatCommand(command, func, persist)
	if type(command) ~= "string" then error("Usage: RegisterChatCommand(command, func[, persist]): 'command' - string expected.", 2) end
	if type(func) ~= "string" and type(func) ~= "function" then error("Usage: RegisterChatCommand(command, func[, persist]): 'func' - function or string expected.", 2) end
	if type(func) == "string" then
		if type(target[func]) ~= "function" then
			error("Usage: RegisterChatCommand(command, func[, persist]): 'func' - method '"..func.."' not found on target object.", 2)
		end
		func = target[func]
	end

	local name = strupper(target.name or "AceConsole-3.0")
	_G["SLASH_"..name..command.."1"] = "/"..strlower(command)
	SlashCmdList[name..command] = func
	if persist then
		-- Persist the command
	end
end

AceConsole.commands = AceConsole.commands or {}
AceConsole.weakcommands = AceConsole.weakcommands or {}
