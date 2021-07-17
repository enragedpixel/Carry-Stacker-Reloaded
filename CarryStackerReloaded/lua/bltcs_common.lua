_G.BLT_CarryStacker = _G.BLT_CarryStacker or {}

--[[
    Convert the value returned when clicking a toggle button to a 
    boolean value.
]]
function val2bool(value)
    return value == "on"
end

--[[
    Log the given message if debugging is enabled

    message has to be a string
    caller_function_level is a number. In general, this argument should 
        be ommited. It is used to indicate what layer of the call-stack
        contains the caller's function name. By default, it will be 2.
        This is, the name of the caller function will be logged

    The mod's logs are preceded by "[BLTCS]"
]]
function BLT_CarryStacker.Log(message, caller_function_level)
    if BLT_CarryStacker.settings.toggle_debug then
        local level = caller_function_level and caller_function_level or 2
        local function_name = debug.getinfo(level).name
        log("[BLTCS] - " .. function_name .. " - " .. message)
    end
end

--[[
    Log the given message. It is expected that this log call will be 
    repeatedly called many times per second.

    The message will be logged if both debugging and repeated_logs are
    enabled.

    message has to be a string.
]]
function BLT_CarryStacker.RLog(message)
    if BLT_CarryStacker.settings.toggle_repeated_logs then
        BLT_CarryStacker.Log(message, 3)
    end
end

--[[
    Show a chat message that only this client will see.

    messageId is a string representing a localized message. For example:
        "bltcs_stealth_only_alarm_message"
]]
function BLT_CarryStacker.ShowInfoMessage(messageId)
    local logger = BLT_CarryStacker.Log
    logger("Request to show info message with id " .. messageId)
    if not BLT_CarryStacker.settings.toggle_show_chat_info then
        logger("The player does not want messages to be shown. Returning")
        return
    end
    local messageSenderName = "CARRY STACKER"
    local message = managers.localization:text(messageId)
    local color = Color("5FE1FF") --cyan
    managers.chat:_receive_message(1, messageSenderName, message, color)
end

--[[
    A higher order function to log the result of master_function

    useRLog is a boolean value indicating whether the function should
        use BLT_CarryStacker.Log or BLT_CarryStacker.RLog
    master_function has to be a function
    All other arguments passed to this function will be passed to 
    master_function

    Returns the master's function return value
]]
function BLT_CarryStacker.DoMasterFunction(useRLog, master_function, ...)
    local logger = userRLog and BLT_CarryStacker.RLog or BLT_CarryStacker.Log
    logger("The mod is not enabled. Using master function")
    local result = master_function(...)
    logger("The master's function result is " .. tostring(result))
    return result
end