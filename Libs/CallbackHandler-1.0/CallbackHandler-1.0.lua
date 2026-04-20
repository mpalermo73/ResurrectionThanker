--[[ $Id: CallbackHandler-1.0.lua 26 2019-09-23 09:54:26Z nevcairiel $ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 7
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end -- No upgrade needed

local meta = {__index = function(tbl, key) tbl[key] = {} return tbl[key] end}

-- Lua APIs
local tconcat = table.concat
local assert, error, loadstring = assert, error, loadstring
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, select, pairs, type, tostring = next, select, pairs, type, tostring

-- Global vars/functions that we don't upvalue since they might get hooked, or upgrade system doesn't touch them.
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
	local next, xpcall, eh = ...

	local method, ARGS
	local function call() return method(ARGS) end

	local function dispatch(handlers, ...)
		local index
		index, method = next(handlers)
		if not method then return end
		local OLD_ARGS = ARGS
		ARGS = ...
		repeat
			xpcall(call, eh)
			index, method = next(handlers, index)
		until not method
		ARGS = OLD_ARGS
	end

	return dispatch
	]]

	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "arg"..i end
	code = code:gsub("ARGS", tconcat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(next, xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

--------------------------------------------------------------------------
-- CallbackHandler:New
--
--   target            - target object to embed public APIs in
--   RegisterName      - name of the callback registration API, default "RegisterCallback"
--   UnregisterName    - name of the callback unregistration API, default "UnregisterCallback"
--   UnregisterAllName - name of the API to unregister all callbacks, default "UnregisterAllCallbacks"
--
function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)

	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	UnregisterAllName = UnregisterAllName or "UnregisterAllCallbacks"

	-- PUBLIC METHODS
	--------------------------------------------

	target[RegisterName] = function(self, eventname, method, ... /*arg, arg2, arg3, ... */)
		if type(eventname) ~= "string" then
			error("Usage: "..RegisterName.."(eventname, method, ...): 'eventname' - string expected.", 2)
		end
		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: "..RegisterName.."(eventname, method, ...): 'method' - function or string expected.", 2)
		end
		if type(method) == "string" then
			if type(self[method]) ~= "function" then
				error("Usage: "..RegisterName.."(eventname, method, ...): 'method' - method '"..method.."' not found on target object.", 2)
			end
			method = self[method]
		end

		local aceEventId = "AceEvent-3.0"
		local AceEvent = LibStub(aceEventId, true)
		if AceEvent and type(AceEvent.Embed) == "function" then
			AceEvent:Embed(target)
		end

		if not target.callbacks then
			target.callbacks = LibStub("CallbackHandler-1.0"):New(target, RegisterName, UnregisterName, UnregisterAllName)
		end

		target.callbacks:RegisterCallback(eventname, method, self, ...)
	end

	target[UnregisterName] = function(self, eventname, method)
		if not target.callbacks then return end
		target.callbacks:UnregisterCallback(eventname, method)
	end

	target[UnregisterAllName] = function(self, eventname)
		if not target.callbacks then return end
		target.callbacks:UnregisterAllCallbacks(eventname)
	end

	-- PRIVATE METHODS
	--------------------------------------------

	target.callbacks = setmetatable({}, meta)

	local dispatchers = setmetatable({}, meta)

	local function unregisterallcallbacks(_, eventname)
		if not target.callbacks then return end
		local callbacks = target.callbacks[eventname]
		if callbacks then
			for k in pairs(callbacks) do
				callbacks[k] = nil
			end
		end
	end

	local function unregistercallback(_, eventname, method)
		if not target.callbacks then return end
		local callbacks = target.callbacks[eventname]
		if callbacks then
			for k, v in pairs(callbacks) do
				if v == method then
					callbacks[k] = nil
					break
				end
			end
		end
	end

	local function registercallback(_, eventname, method, ... /* arg, arg2, arg3, ... */)
		if not target.callbacks then return end
		local callbacks = target.callbacks[eventname]
		if not callbacks then
			dispatchers[eventname] = dispatchers[eventname] or Dispatchers[select("#", ...)]
		end
		callbacks[...] = method
	end

	target.callbacks.RegisterCallback = registercallback
	target.callbacks.UnregisterCallback = unregistercallback
	target.callbacks.UnregisterAllCallbacks = unregisterallcallbacks

	local function Fire(target, eventname, ... /* arg, arg2, arg3, ... */)
		if not target.callbacks or not target.callbacks[eventname] then
			return
		end
		local callbacks = target.callbacks[eventname]
		if next(callbacks) then
			dispatchers[eventname](callbacks, target, eventname, ...)
		end
	end

	target.Fire = Fire

end


-- GLOBALS
--------------------------------------------
CallbackHandler.embed = CallbackHandler.New

function CallbackHandler:Embed(target)
	self:New(target, "RegisterCallback", "UnregisterCallback", "UnregisterAllCallbacks")
end
