_G.BLT_CarryStacker = _G.BLT_CarryStacker or {}

--[[
    Load the Mod's settings from the data file.
]]
function BLT_CarryStacker:Load()
    local logger = BLT_CarryStacker.Log
    logger("Loading settings")
    self:ResetSettings()

    local file = io.open(self._data_path, "r")
    if file then

        -- Check for old config data. Going to be removed in R8+
        local foundMP = false
        for k, v in pairs(json.decode(file:read("*all"))) do
            self.settings[k] = v
            if k == "movement_penalties" then foundMP = true end
        end
        file:close()
    logger("Settings loaded")

        if not foundMP then
            os.remove(self._data_path)
            BLT_CarryStacker:ResetSettings()
        end
    end
end

--[[
    Save the Mod's settings into the data file.
]]
function BLT_CarryStacker:Save()
    local logger = BLT_CarryStacker.Log
    logger("Saving settings")
    local file = io.open(self._data_path, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
        logger("Settings saved")
    end
end

--[[
    Reset settings to their default values. 

    It does not persist the settings, but just modifies the in-memory
    ones.
]]
function BLT_CarryStacker:ResetSettings()
    local logger = BLT_CarryStacker.Log
    logger("Resetting settings to their default values")
    self.settings.movement_penalties = {
        light = 15,
        coke_light = 15,
        medium = 30,
        heavy = 45,
        very_heavy = 60,
        mega_heavy = 75,

        being = 45,
        slightly_very_heavy = 45
    }
    self.settings.toggle_enable = true
    self.settings.toggle_host = true
    self.settings.toggle_stealth = false
    self.settings.toggle_offline = false
    self.settings.toggle_show_chat_info = true
    self.settings.toggle_debug = false
    self.settings.toggle_repeated_logs = false
    self.host_settings.movement_penalties = {}
    logger("Settings resetted")
end

--[[
    Return the table of local movement penalties
]]
function BLT_CarryStacker:getLocalMovementPenalties()
    local logger = BLT_CarryStacker.Log
    logger("Request to get local movement penalties")
    return self.settings.movement_penalties
end

--[[
    Set the movement penalty of the specified carry_type.

    carry_type is a string.
    penalty is a number.

    Example:
        BLT_CarryStacker.setHostMovementPenalty("light", 15)
]]
function BLT_CarryStacker:setHostMovementPenalty(carry_type, penalty)
    local logger = BLT_CarryStacker.Log
    logger("Request to set the host movement penalty of " .. 
        tostring(carry_type) .. " to " .. tostring(penalty))
    if not self.settings.movement_penalties[carry_type] then
        logger("ERROR: There is no \"" .. tostring(carry_type) .. "\" type.")
        return
    end
    self.host_settings.movement_penalties[carry_type] = penalty
end

--[[
    Return the weight of a carry with id carry_id.

    The returned value is in range [0.5, 1].

    The weight will be calculated using either the local 
    movement_penalties or the host movement_penalties accoding to the
    game state.

    carry_id is a string.

    Example:
        getWeightForType("light") -> 10

        Note: the returned value is 10 according to default settings
]]
function BLT_CarryStacker:getWeightForType(carry_id, logger)
    logger = logger or BLT_CarryStacker.Log
    logger("Request to get the weight of carry " .. 
        tostring(carry_id))
    local carry_type = tweak_data.carry[carry_id].type
    local movement_penalty = nil
    if LuaNetworking:IsMultiplayer() 
            and not LuaNetworking:IsHost() 
            and self:IsRemoteHostSyncEnabled() then
        logger("Using host's movement penalties")
        movement_penalty = self.host_settings.movement_penalties[carry_type]
    else
        logger("Using local movement penalties")
        movement_penalty = self.settings.movement_penalties[carry_type]
    end
    local result = movement_penalty ~= nil 
        and ((100 -movement_penalty) / 100) 
        or 1
    logger("The resulting weight is " .. tostring(result))
    return result
end

--[[
    Set the mod to be allowed in online games not hosted by this client
]]
function BLT_CarryStacker:HostAllowsMod()
    local logger = BLT_CarryStacker.Log
    logger("Request to set host_settings.is_mod_allowed to true")
    self.host_settings.is_mod_allowed = true
end

--[[
    Set the mod to NOT be allowed in online games not hosted by this 
    client
]]
function BLT_CarryStacker:HostDisallowsMod()
    local logger = BLT_CarryStacker.Log
    logger("Request to set host_settings.is_mod_allowed to false")
    self.host_settings.is_mod_allowed = false
end

--[[
    Return the current mod state

    The return value one of the values of the BLT_CarryStacker.STATES
    table.
]]
function BLT_CarryStacker:GetModState()
    local logger = BLT_CarryStacker.RLog
    logger("Request to get the mod's state")
    local result = self.STATES.DISABLED
    -- Unable to use if online and offline only is toggled
    if self:IsOfflineOnly() and not Global.game_settings.single_player then
        logger("The mod is configured to be used only on " ..
            "offline, but it is multiplayer. The mod is disabled")
        result = self.STATES.DISABLED
    elseif self:IsStealthOnly() 
            and not managers.groupai:state():whisper_mode() then
        logger("The mod is configured to be used only during " ..
            "stealth, and it is loud. The mod is disabled")
        result = self.STATES.DISABLED
    elseif LuaNetworking:IsHost() then
        logger("The player is the host. The mod is enabled")
        result = self.settings.toggle_enable and self.STATES.ENABLED or self.STATES.DISABLED
    else
        logger("The player is not the host. Using the host's " ..
            "configuration")
        result = self.host_settings.is_mod_allowed and self.STATES.ENABLED or self.STATES.DISABLED
    end

    if result == self.STATES.DISABLED and #self.stack > 0 then
        logger("The mod is to be disabled, but there still " ..
            "are bags in the stack")
        result = self.STATES.BEING_DISABLED
    end

    logger("The mod is: " .. tostring(result))
    return result
end

--[[
    Set the setting identified by setting_id to state.

    setting_id is a string.
    state has to have a value valid for the given setting_id.
    dest [optional] The table in which to set the setting. 
        Default: BLT_CarryStacker.settings

    Example:
        BLT_CarryStacker:SetSetting("toggle_stealth", true)
]]
function BLT_CarryStacker:SetSetting(setting_id, state, dest)
    local logger = BLT_CarryStacker.Log
    logger("Request to set " .. tostring(setting_id) .. " to " ..
        tostring(state))
    if not dest then
        dest = self.settings
    end
    dest[setting_id] = state
end

function BLT_CarryStacker:SetMovPenaltySetting(setting_id, state)
    BLT_CarryStacker:SetSetting(setting_id, state, 
        BLT_CarryStacker.settings.movement_penalties)
    BLT_CarryStacker:RecalculateWeightOnMenuClose()
end

function BLT_CarryStacker:SetRemoteHostSync(state)
    local logger = BLT_CarryStacker.Log
    logger("Request to set remote_host_sync to " .. tostring(state))
    self.host_settings.remote_host_sync = state
end

function BLT_CarryStacker:IsRemoteHostSyncEnabled()
    local logger = BLT_CarryStacker.Log
    logger("Request to return host_settings.remote_host_sync. " ..
        "Its value is " .. tostring(self.host_settings.remote_host_sync))
    return self.host_settings.remote_host_sync
end 

function BLT_CarryStacker:IsHostSyncEnabled()
    local logger = BLT_CarryStacker.Log
    logger("Request to return settings.toggle_host. Its value " ..
        "is " .. tostring(self.settings.toggle_host))
    return self.settings.toggle_host
end

function BLT_CarryStacker:IsStealthOnly()
    local logger = BLT_CarryStacker.RLog
    logger("Request to return settings.toggle_stealth. Its value " ..
        "is " .. tostring(self.settings.toggle_stealth))
    return self.settings.toggle_stealth
end

function BLT_CarryStacker:IsOfflineOnly()
    local logger = BLT_CarryStacker.RLog
    logger("Request to return settings.toggle_online. Its value " ..
        "is " .. tostring(self.settings.toggle_offline))
    return self.settings.toggle_offline
end

--[[
    Return whether the player can carry a bag with carry_id.

    carry_id is a string. Example: "heavy"

    The return type is a boolean value.
]]
function BLT_CarryStacker:CanCarry(carry_id, logger)
    logger = logger or BLT_CarryStacker.Log
    logger("Request to check whether the player can " ..
        "carry " .. tostring(carry_id))
    if self:GetModState() == self.STATES.BEING_DISABLED then
        logger("The mod is being disabled. Cannot carry more bags")
        return false
    end
    local check_weight = self.weight * self:getWeightForType(carry_id, logger)
    logger("The current weight is " .. tostring(self.weight) .. 
        " and the new weight is " .. tostring(check_weight))
    local result = check_weight >= 0.25
    logger("The player can carry a bag: " .. tostring(result))
    return result
end

--[[
    Add to the top of the stack the carry cdata.
]]
function BLT_CarryStacker:AddCarry(cdata)
    local logger = BLT_CarryStacker.Log
    logger("Request to add the carry " .. tostring(cdata.carry_id))
    logger("The previous weight was " .. tostring(self.weight))
    self.weight = self.weight * self:getWeightForType(cdata.carry_id)
    logger("The new weight is " .. tostring(self.weight))
    table.insert(self.stack, cdata)
    self:HudRefresh()
end

--[[
    Remove the top-most carry from the stack and return it.

    If the stack is empty, it returns nil.
]]
function BLT_CarryStacker:RemoveCarry()
    local logger = BLT_CarryStacker.Log
    logger("Request to remove the top-most carry from the stack")
    if #self.stack == 0 then
        logger("The stack is empty. Returning")
        return nil
    end
    local cdata = self.stack[#self.stack]
    logger("The top-most item is: " .. tostring(cdata.carry_id))
    logger("The previous weight was " .. tostring(self.weight))
    self.weight = self.weight / self:getWeightForType(cdata.carry_id)
    logger("The new weight is " .. tostring(self.weight))
    table.remove(self.stack, #self.stack)
    if #self.stack == 0 then
        logger("The stack is empty. Setting the weight to 1")
        self.weight = 1
    end
    self:HudRefresh()
    return cdata
end

--[[
    Update the HUD's carry symbol, indicating the ammount of bags
    carried by the player
]]
function BLT_CarryStacker:HudRefresh()
    local logger = BLT_CarryStacker.Log
    logger("Request to refresh the HUD")
    managers.hud:remove_special_equipment("carrystacker")
    if #self.stack > 0 then
        logger("There are items in the stack. Adding the "
            .. "corresponding special equipment icon")
        managers.hud:add_special_equipment({
            id = "carrystacker", 
            icon = "pd2_loot", 
            amount = #self.stack
        })
    end
end

function BLT_CarryStacker:RecalculateWeightOnMenuClose()
    local logger = BLT_CarryStacker.Log
    if #BLT_CarryStacker.stack > 0 
            and not BLT_CarryStacker.closePauseMenuCallbacks.recalculateWeight then
        BLT_CarryStacker.closePauseMenuCallbacks.recalculateWeight = function()
            logger("Bag penalties have been changed " ..
                "while carrying bags. Recalculating self.weight")
            BLT_CarryStacker.weight = 1
            for i, cdata in pairs(BLT_CarryStacker.stack) do
                BLT_CarryStacker.weight = BLT_CarryStacker.weight
                    * BLT_CarryStacker:getWeightForType(cdata.carry_id)
            end
            logger("Resulting weight is: " .. 
                tostring(BLT_CarryStacker.weight))
        end
    end
end