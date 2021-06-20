_G.BLT_CarryStacker = _G.BLT_CarryStacker or {}
BLT_CarryStacker._path = ModPath
BLT_CarryStacker._data_path = SavePath .. "carrystacker.txt"
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

		It controls whether the mod	should be used if the player is 
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
function BLT_CarryStacker:Log(message, caller_function_level)
	if self.settings.toggle_debug then
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
function BLT_CarryStacker:RLog(message)
	if self.settings.toggle_repeated_logs then
		BLT_CarryStacker:Log(message, 3)
	end
end

--[[
	Show a chat message that only this client will see.

	messageId is a string representing a localized message. For example:
		"bltcs_stealth_only_alarm_message"
]]
function BLT_CarryStacker:ShowInfoMessage(messageId)
	BLT_CarryStacker:Log("Request to show info message with id " .. messageId)
	if not self.settings.toggle_show_chat_info then
		BLT_CarryStacker:Log("The player does not want messages to be shown. Returning")
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
		use BLT_CarryStacker:Log or BLT_CarryStacker:RLog
	master_function has to be a function
	All other arguments passed to this function will be passed to 
	master_function

	Returns the master's function return value
]]
function BLT_CarryStacker:DoMasterFunction(useRLog, master_function, ...)
	local doMasterFunctionLogger = function(message)
		if useRLog then
			self:RLog(message)
		else
			self:Log(message)
		end
	end
	doMasterFunctionLogger("The mod is not enabled. Using master function")
	local result = master_function(...)
	doMasterFunctionLogger("The master's function result is " .. tostring(result))
	return result
end

--[[
	Load the Mod's settings from the data file.
]]
function BLT_CarryStacker:Load()
	BLT_CarryStacker:Log("Loading settings")
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
	BLT_CarryStacker:Log("Settings loaded")

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
	BLT_CarryStacker:Log("Saving settings")
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
		BLT_CarryStacker:Log("Settings saved")
	end
end

--[[
	Reset settings to their default values. 

	It does not persist the settings, but just modifies the in-memory
	ones.
]]
function BLT_CarryStacker:ResetSettings()
	BLT_CarryStacker:Log("Resetting settings to their default values")
	self.settings.movement_penalties = {
		light = 10,
		coke_light = 10,
		medium = 20,
		heavy = 30,
		very_heavy = 40,
		mega_heavy = 50,

		being = 30,
		slightly_very_heavy = 30
	}
	self.settings.toggle_enable = true
	self.settings.toggle_host = true
	self.settings.toggle_stealth = false
	self.settings.toggle_offline = false
	self.settings.toggle_show_chat_info = true
	self.settings.toggle_debug = false
	self.settings.toggle_repeated_logs = false
	self.host_settings.movement_penalties = {}
	BLT_CarryStacker:Log("Settings resetted")
end

--[[
	Return the table of local movement penalties
]]
function BLT_CarryStacker:getLocalMovementPenalties()
	BLT_CarryStacker:Log("Request to get local movement penalties")
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
	BLT_CarryStacker:Log("Request to set the host movement penalty of " .. 
		tostring(carry_type) .. " to " .. tostring(penalty))
	if not self.settings.movement_penalties[carry_type] then
		BLT_CarryStacker:Log("ERROR: There is no \"" .. 
			tostring(carry_type) .. "\" type.")
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
function BLT_CarryStacker:getWeightForType(carry_id)
	BLT_CarryStacker:Log("Request to get the weight of carry " .. 
		tostring(carry_id))
	local carry_type = tweak_data.carry[carry_id].type
	local movement_penalty = nil
	if LuaNetworking:IsMultiplayer() 
			and not LuaNetworking:IsHost() 
			and self:IsRemoteHostSyncEnabled() then
		BLT_CarryStacker:Log("Using host's movement penalties")
		movement_penalty = self.host_settings.movement_penalties[carry_type]
	else
		BLT_CarryStacker:Log("Using local movement penalties")
		movement_penalty = self.settings.movement_penalties[carry_type]
	end
	local result = movement_penalty ~= nil 
		and ((100 -movement_penalty) / 100) 
		or 1
	BLT_CarryStacker:Log("The resulting weight is " .. tostring(result))
	return result
end

--[[
	Set the mod to be allowed in online games not hosted by this client
]]
function BLT_CarryStacker:HostAllowsMod()
	BLT_CarryStacker:Log("Request to set host_settings.is_mod_allowed to true")
	self.host_settings.is_mod_allowed = true
end

--[[
	Set the mod to NOT be allowed in online games not hosted by this 
	client
]]
function BLT_CarryStacker:HostDisallowsMod()
	BLT_CarryStacker:Log("Request to set host_settings.is_mod_allowed to false")
	self.host_settings.is_mod_allowed = false
end

--[[
	Return the current mod state

	The return value one of the values of the BLT_CarryStacker.STATES
	table.
]]
function BLT_CarryStacker:GetModState()
	BLT_CarryStacker:RLog("Request to get the mod's state")
	local result = self.STATES.DISABLED
	-- Unable to use if online and offline only is toggled
	if self:IsOfflineOnly() and not Global.game_settings.single_player then
		BLT_CarryStacker:RLog("The mod is configured to be used only on " ..
			"offline, but it is multiplayer. The mod is disabled")
		result = self.STATES.DISABLED
	elseif self:IsStealthOnly() 
			and not managers.groupai:state():whisper_mode() then
		BLT_CarryStacker:RLog("The mod is configured to be used only during " ..
			"stealth, and it is loud. The mod is disabled")
		result = self.STATES.DISABLED
	elseif LuaNetworking:IsHost() then
		BLT_CarryStacker:RLog("The player is the host. The mod is enabled")
		result = self.settings.toggle_enable and self.STATES.ENABLED or self.STATES.DISABLED
	else
		BLT_CarryStacker:RLog("The player is not the host. Using the host's " ..
			"configuration")
		result = self.host_settings.is_mod_allowed and self.STATES.ENABLED or self.STATES.DISABLED
	end

	if result == self.STATES.DISABLED and #self.stack > 0 then
		BLT_CarryStacker:RLog("The mod is to be disabled, but there still " ..
			"are bags in the stack")
		result = self.STATES.BEING_DISABLED
	end

	BLT_CarryStacker:RLog("The mod is: " .. tostring(result))
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
	BLT_CarryStacker:Log("Request to set " .. tostring(setting_id) .. " to " ..
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
	BLT_CarryStacker:Log("Request to set remote_host_sync to " .. tostring(state))
	self.host_settings.remote_host_sync = state
end

function BLT_CarryStacker:IsRemoteHostSyncEnabled()
	BLT_CarryStacker:Log("Request to return host_settings.remote_host_sync. " ..
		"Its value is " .. tostring(self.host_settings.remote_host_sync))
	return self.host_settings.remote_host_sync
end 

function BLT_CarryStacker:IsHostSyncEnabled()
	BLT_CarryStacker:Log("Request to return settings.toggle_host. Its value " ..
		"is " .. tostring(self.settings.toggle_host))
	return self.settings.toggle_host
end

function BLT_CarryStacker:IsStealthOnly()
	BLT_CarryStacker:RLog("Request to return settings.toggle_stealth. Its value " ..
		"is " .. tostring(self.settings.toggle_stealth))
	return self.settings.toggle_stealth
end

function BLT_CarryStacker:IsOfflineOnly()
	BLT_CarryStacker:RLog("Request to return settings.toggle_online. Its value " ..
		"is " .. tostring(self.settings.toggle_offline))
	return self.settings.toggle_offline
end

--[[
	Return whether the player can carry a bag with carry_id.

	carry_id is a string. Example: "heavy"

	The return type is a boolean value.
]]
function BLT_CarryStacker:CanCarry(carry_id)
	BLT_CarryStacker:Log("Request to check whether the player can " ..
		"carry " .. tostring(carry_id))
	if self:GetModState() == self.STATES.BEING_DISABLED then
		BLT_CarryStacker:Log("The mod is being disabled. Cannot carry more bags")
		return false
	end
	local check_weight = self.weight * self:getWeightForType(carry_id)
	BLT_CarryStacker:Log("The current weight is " .. tostring(self.weight) .. 
		" and the new weight is " .. tostring(check_weight))
	local result = check_weight >= 0.25
	BLT_CarryStacker:Log("The player can carry a bag: " .. tostring(result))
	return result
end

--[[
	Add to the top of the stack the carry cdata.
]]
function BLT_CarryStacker:AddCarry(cdata)
	BLT_CarryStacker:Log("Request to add the carry " .. tostring(cdata.carry_id))
	BLT_CarryStacker:Log("The previous weight was " .. tostring(self.weight))
	self.weight = self.weight * self:getWeightForType(cdata.carry_id)
	BLT_CarryStacker:Log("The new weight is " .. tostring(self.weight))
	table.insert(self.stack, cdata)
	self:HudRefresh()
end

--[[
	Remove the top-most carry from the stack and return it.

	If the stack is empty, it returns nil.
]]
function BLT_CarryStacker:RemoveCarry()
	BLT_CarryStacker:Log("Request to remove the top-most carry from the stack")
	if #self.stack == 0 then
		BLT_CarryStacker:Log("The stack is empty. Returning")
		return nil
	end
	local cdata = self.stack[#self.stack]
	BLT_CarryStacker:Log("The top-most item is: " .. tostring(cdata.carry_id))
	BLT_CarryStacker:Log("The previous weight was " .. tostring(self.weight))
	self.weight = self.weight / self:getWeightForType(cdata.carry_id)
	BLT_CarryStacker:Log("The new weight is " .. tostring(self.weight))
	table.remove(self.stack, #self.stack)
	if #self.stack == 0 then
		BLT_CarryStacker:Log("The stack is empty. Setting the weight to 1")
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
	BLT_CarryStacker:Log("Request to refresh the HUD")
	managers.hud:remove_special_equipment("carrystacker")
	if #self.stack > 0 then
		BLT_CarryStacker:Log("There are items in the stack. Adding the "
			.. "corresponding special equipment icon")
		managers.hud:add_special_equipment({
			id = "carrystacker", 
			icon = "pd2_loot", 
			amount = #self.stack
		})
	end
end

function BLT_CarryStacker:RecalculateWeightOnMenuClose()
	if #BLT_CarryStacker.stack > 0 
			and not BLT_CarryStacker.closePauseMenuCallbacks.recalculateWeight then
        BLT_CarryStacker.closePauseMenuCallbacks.recalculateWeight = function()
		    BLT_CarryStacker:Log("Bag penalties have been changed " ..
		        "while carrying bags. Recalculating self.weight")
		    BLT_CarryStacker.weight = 1
		    for i, cdata in pairs(BLT_CarryStacker.stack) do
		        BLT_CarryStacker.weight = BLT_CarryStacker.weight
		            * BLT_CarryStacker:getWeightForType(cdata.carry_id)
		    end
		    BLT_CarryStacker:Log("Resulting weight is: " .. 
		        tostring(BLT_CarryStacker.weight))
		end
    end
end

Hooks:Add("LocalizationManagerPostInit", 
	"LocalizationManagerPostInit_BLT_CarryStacker", 
	function(loc)
		BLT_CarryStacker:Log("Loading the localization file")
		local path = BLT_CarryStacker._path .. "loc/english.txt"
		BLT_CarryStacker:Log("The path to the localization file is " .. path)
		loc:load_localization_file(path)
	end
)

Hooks:PostHook(MenuManager, "close_menu", 
	"MenuManager_Post_close_menu_BLT_CarryStacker",
	function(menu_manager, menu_name)
		if menu_name == "menu_pause" then
			-- This section of the code will be executed whenever the 
			-- player closes the pause menu in-game
			BLT_CarryStacker:Log("Closing the pause menu")
			for settingName, callback in pairs(BLT_CarryStacker.closePauseMenuCallbacks) do
				if callback then
					BLT_CarryStacker:Log("Calling the callback for " .. settingName)
					callback()
				end
			end
			BLT_CarryStacker.closePauseMenuCallbacks = {}
		end
	end
)

Hooks:Add("MenuManagerInitialize", 
	"MenuManagerInitialize_BLT_CarryStacker", 
	function(menu_manager)
		BLT_CarryStacker:Log("Initializing the menu")
		-- Callback for the movement penalty sliders
		MenuCallbackHandler.BLT_CarryStacker_setBagPenalty = function(this, item)
			BLT_CarryStacker:Log("The player requested changing a bag penalty")
			local _type = item:name():sub(7)
			local new_value = item:value()
			BLT_CarryStacker:SetMovPenaltySetting(_type, new_value)
			if _type == "light" then
				BLT_CarryStacker:Log("Since 'light' bag's penality has been " ..
					"updated, updating 'coke_light' as well")
				BLT_CarryStacker:SetMovPenaltySetting("coke_light", new_value)
			elseif _type == "heavy" then
				BLT_CarryStacker:Log("Since 'heavy' bag's penality has been " ..
					"updated, updating 'being' and 'slightly_very_heavy as well'")
				BLT_CarryStacker:SetMovPenaltySetting("being", new_value)
				BLT_CarryStacker:SetMovPenaltySetting("slightly_very_heavy", new_value)
			end
		end	

		-- Reset button callback
		MenuCallbackHandler.BLT_CarryStacker_Reset = function(this, item)
			BLT_CarryStacker:Log("The player requested resetting setting " ..
				"to their default")
			BLT_CarryStacker:ResetSettings()
			BLT_CarryStacker:RecalculateWeightOnMenuClose()

			-- Bag weights
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_light = true}, 
				BLT_CarryStacker.settings.movement_penalties.light)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_medium = true}, 
				BLT_CarryStacker.settings.movement_penalties.medium)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_heavy = true}, 
				BLT_CarryStacker.settings.movement_penalties.heavy)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_very_heavy = true}, 
				BLT_CarryStacker.settings.movement_penalties.very_heavy)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_mega_heavy = true}, 
				BLT_CarryStacker.settings.movement_penalties.mega_heavy)

			-- Toggle buttons
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_enable = true},
				BLT_CarryStacker.settings.toggle_enable)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_host_sync = true},
				BLT_CarryStacker.settings.toggle_host)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_stealth_only = true},
				BLT_CarryStacker.settings.toggle_stealth)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_offline_only = true},
				BLT_CarryStacker.settings.toggle_offline)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_show_chat_info = true},
				BLT_CarryStacker.settings.toggle_show_chat_info)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_debug = true},
				BLT_CarryStacker.settings.toggle_debug)
			MenuHelper:ResetItemsToDefaultValue(item, {bltcs_repeated_logs = true},
				BLT_CarryStacker.settings.toggle_repeated_logs)
		end

		MenuCallbackHandler.BLT_CarryStacker_Open_Options = function(this, is_opening)
			if not is_opening then return end

			BLT_CarryStacker:Log("The options menu is being opened")
			if LuaNetworking:IsMultiplayer() 
					and not LuaNetworking:IsHost() 
					and BLT_CarryStacker:IsRemoteHostSyncEnabled() then
				BLT_CarryStacker:Log("Since the player is not the host and " ..
					"remote host sync is enabled, showing an info message " ..
					" to the player")
				local title = managers.localization:text("bltcs_playing_as_client_title")
				local message = managers.localization:text("bltcs_playing_as_client_message")
				local options = {
					[1] = {
						text = managers.localization:text("bltcs_common_ok"),
						is_cancel_button = true
					}
				}
				QuickMenu:new(title, message, options, true)
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_Close_Options = function(this)
			BLT_CarryStacker:Log("The options are being closed. Saving them")
			BLT_CarryStacker:Save()

			if BLT_CarryStacker:IsHostSyncEnabled() 
					and LuaNetworking:IsMultiplayer() 
					and LuaNetworking:IsHost() then
				BLT_CarryStacker:Log("Since host sync is enabled and the " ..
					" player is the host, synchronising config to peers")
				BLT_CarryStacker:syncConfigToAll()
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleEnable = function(this, item)
			BLT_CarryStacker:Log("The player wants to change the value of toggle_enable")
			local value = val2bool(item:value())
			BLT_CarryStacker:SetSetting("toggle_enable", value)

			if value then
				BLT_CarryStacker.closePauseMenuCallbacks.toggle_enable = nil
			else
				-- Add a callback to check whether the info message to 
				-- drop bags should be shown
				BLT_CarryStacker.closePauseMenuCallbacks.toggle_enable = function()
					if Utils:IsInHeist() 
							and #BLT_CarryStacker.stack > 0 then
						BLT_CarryStacker:Log("The player just configured " ..
							"the mod to be disabled, but carrying bags. " ..
							"Advising the mod wont be disabled until all " ..
							"bags are dropped")
						BLT_CarryStacker:ShowInfoMessage("bltcs_disabled_message")
					end
				end
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleHostSync = function(this, item)
			BLT_CarryStacker:Log("The player wants to change the value of toggle_host")
			local value = val2bool(item:value())
			BLT_CarryStacker:SetSetting("toggle_host", value)

			BLT_CarryStacker.closePauseMenuCallbacks.toggle_host = function()
				if BLT_CarryStacker:IsHostSyncEnabled() 
						and LuaNetworking:IsMultiplayer() 
						and LuaNetworking:IsHost() then
					BLT_CarryStacker:Log("Since host sync is enabled and the " ..
						" player is the host, synchronising config to peers")
					LuaNetworking:SendToPeers(
						BLT_CarryStacker.NETWORK_MESSAGES.ALLOW_MOD, 
						BLT_CarryStacker:IsHostSyncEnabled() and 1 or 0)
					BLT_CarryStacker:syncConfigToAll()
				end
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleStealthOnly = function(this, item)
			BLT_CarryStacker:Log("The player wants to change the value of toggle_stealth")
			local value = val2bool(item:value())
			BLT_CarryStacker:SetSetting("toggle_stealth", value)

			if not value then
				BLT_CarryStacker.closePauseMenuCallbacks.toggle_stealth = nil
			else
				-- Add a callback to check whether the info message to 
				-- drop bags should be shown
				BLT_CarryStacker.closePauseMenuCallbacks.toggle_stealth = function()
					-- The checks are done in the callback and not  
					-- before creating it as the alarm could go off  
					-- while in the menu
					if Utils:IsInHeist() 
							and #BLT_CarryStacker.stack > 0 
							and not managers.groupai:state():whisper_mode() then
						BLT_CarryStacker:Log("The player just configured " ..
							"the mod to be used Stealth-Only, but the alarm " ..
							"is triggered and they are carrying bags. " ..
							"Advising the mod wont be disabled until all " ..
							"bags are dropped")
						BLT_CarryStacker:ShowInfoMessage("bltcs_stealth_only_alarm_message")
					end
				end
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleOfflineOnly = function(this, item)
			BLT_CarryStacker:Log("The player wants to change the value of toggle_offline")
			local value = val2bool(item:value())
			BLT_CarryStacker:SetSetting("toggle_offline", value)

			if not value then
				BLT_CarryStacker.closePauseMenuCallbacks.toggle_offline = nil
			else
				-- Add a callback to check whether the info message to 
				-- drop bags should be shown
				BLT_CarryStacker.closePauseMenuCallbacks.toggle_offline = function()
					if Utils:IsInHeist() 
							and #BLT_CarryStacker.stack > 0 
							and not Global.game_settings.single_player then
						BLT_CarryStacker:Log("The player just configured " ..
							"the mod to be used Offline-Only, but the player " ..
							"is online and they are carrying bags. " ..
							"Advising the mod wont be disabled until all " ..
							"bags are dropped")
						BLT_CarryStacker:ShowInfoMessage("bltcs_offline_only_online_message")
					end
				end
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleShowChatInfo = function(this, item)
			BLT_CarryStacker:Log("The player wants to change the value of toggle_show_chat_info")
			BLT_CarryStacker:SetSetting("toggle_show_chat_info", val2bool(item:value()))
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleDebug = function(this, item)
			BLT_CarryStacker:Log("The player wants to change the value of toggle_debug")
			BLT_CarryStacker:SetSetting("toggle_debug", val2bool(item:value()))
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleRepeatedLogs = function(this, item)
			BLT_CarryStacker:Log("The player wants to change the value of toggle_repeated_logs")
			BLT_CarryStacker:SetSetting("toggle_repeated_logs", val2bool(item:value()))
		end

		-- Help button callback
		MenuCallbackHandler.BLT_CarryStacker_Help = function(this, item)
			BLT_CarryStacker:Log("The player want to be shown the help message")
			local title = managers.localization:text("bltcs_help_title")
			local message = managers.localization:text("bltcs_help_message")
			local options = {
				[1] = {
					text = "Okay",
					is_cancel_button = true
				}
			}
			QuickMenu:new(title, message, options, true)
		end

		BLT_CarryStacker:Load()
		MenuHelper:LoadFromJsonFile(BLT_CarryStacker._path .. "menu/options.txt", 
			BLT_CarryStacker, (function()
				-- The mod's settings are converted into a simple table
				-- for the MenuHelper to load the value
				local tbl = {}
				for i, v in pairs(BLT_CarryStacker.settings.movement_penalties) do
					tbl[i] = v
				end
				tbl.toggle_enable = BLT_CarryStacker.settings.toggle_enable
				tbl.toggle_host = BLT_CarryStacker.settings.toggle_host
				tbl.toggle_stealth = BLT_CarryStacker.settings.toggle_stealth
				tbl.toggle_offline = BLT_CarryStacker.settings.toggle_offline
				tbl.toggle_show_chat_info = BLT_CarryStacker.settings.toggle_show_chat_info
				tbl.toggle_debug = BLT_CarryStacker.settings.toggle_debug
				tbl.toggle_repeated_logs = BLT_CarryStacker.settings.toggle_repeated_logs
				return tbl
			-- The function is declared and called
			end)()
		)
	end
)
