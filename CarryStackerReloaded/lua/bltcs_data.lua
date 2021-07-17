_G.BLT_CarryStacker = _G.BLT_CarryStacker or {}

--[[
    STATES is a table.

    It contains the different states in which the mod can be.

    If the mod is ENABLED, all of its features should be usable.
    If the mod is DISABLED, the vanilla features should be used.
    If the mod is BEING_DISABLED, only certain features of the mod 
        should be used. For example, the player will not be able to
        carry more bags.
]]
BLT_CarryStacker.STATES = {
    ENABLED = "enabled",
    BEING_DISABLED = "being_disabled",
    DISABLED = "disabled"
}
--[[
    NETWORK_MESSAGES is a table.

    It contains the different messages ids that can be exchanged through 
    the network.

    Its content will be used as constants, and should NOT be MODIFIED 
    on runtime.

    ALLOW_MOD: Sent by the host to notify other players they can use 
    the mod
    REQUEST_MOD_USAGE: Sent to the host, to request using the mod
    SET_HOST_CONFIG: Sent by the host, to synchronize configuration

    Note: Modifying these ids may break backwards compatibility
]]
BLT_CarryStacker.NETWORK_MESSAGES = {
    ALLOW_MOD = "BLT_CarryStacker_AllowMod",
    REQUEST_MOD_USAGE = "BLT_CarryStacker_Request",
    SET_HOST_CONFIG = "BLT_CarryStacker_SyncConfig"
}
--[[
    settings is a table.

    As its name suggests, it will contain the mod's settings. For 
    example, the movement_penalties of each type of carry/bag, whether
    host sync is active or not, whether the mod can only be used 
    offline...
]]
BLT_CarryStacker.settings = {}
--[[
    weight is a number in [0.25, 1].

    It represents how affected is the player's movement by the bags 
    they are carrying. This is, if weight is 1, the player's is not 
    affected at all. However, if weight is less than 1, the player's
    speed and jumping ability will be reduced. Furthermore, the player
    will not be able to pick more bags once a certain weight threshold.

    As of today, writing this documentation, the player cannot run if
    its weight is less than 0.75, and cannot pick bags if its weight is
    less than 0.25.
]]
BLT_CarryStacker.weight = 1
--[[
    stack is a table.

    It will contain the player carries (bags picked by the player) in 
    the order they where picked. This is, the first item in the stack 
    will be the first item the player picked.

    As its name suggests, it will be used as a FILO queue: First In 
    Last Out.
]]
BLT_CarryStacker.stack = {}
--[[
    host_settings is a table.

    It will contain the configuration to be used when playing online
    and not hosting the game.
]]
BLT_CarryStacker.host_settings = {
    --[[
        is_mod_allowed is a boolean variable .

        It controls whether the mod should be used if the player is 
        online and is not the host.

        By default, the mod wont be used on an online lobby.
    ]]
    is_mod_allowed = false,
    --[[
        remote_host_sync is a boolean variable.

        It indicates whether the movement_penalties provided by the 
        host should be used, instead of the local ones.
    ]]
    remote_host_sync = false,
    --[[
        movement_penalties is a table.

        It will contain the movement penalties to be used whenever 
        playing online, with a host using this mod. This penalties 
        will only be used if remote_host_sync is set to true.
    ]]
    movement_penalties = {}
}
--[[
    closePauseMenuCallbacks is a table.

    It will contain the functions to be called when closing the pause
    menu.

    The keys in the table has to be the name of the setting that 
    triggered the callback. The value has to be a function that takes 
    no arguments.
]]
BLT_CarryStacker.closePauseMenuCallbacks = {}