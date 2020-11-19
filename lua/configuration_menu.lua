_G.BLT_CarryStacker = _G.BLT_CarryStacker or {}
BLT_CarryStacker._path = ModPath
BLT_CarryStacker._data_path = SavePath .. "carrystacker.txt"
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
	Convert the value returned when clicking a toggle button to a 
	boolean value.
]]
function val2bool(value)
	return value == "on"
end

--[[
	Load the Mod's settings from the data file.
]]
function BLT_CarryStacker:Load()
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
	local file = io.open(self._data_path, "w+")
	if file then
		file:write(json.encode(self.settings))
		file:close()
	end
end

--[[
	Reset settings to their default values. 

	It does not persist the settings, but just modifies the in-memory
	ones.
]]
function BLT_CarryStacker:ResetSettings()
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
	self.settings.toggle_host = true
	self.settings.toggle_stealth = false
	self.settings.toggle_offline = false
	self.host_settings.movement_penalties = {}
end

--[[
	Return the table of local movement penalties
]]
function BLT_CarryStacker:getLocalMovementPenalties()
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
	if not self.settings.movement_penalties[carry_type] then
		log("There is no \"" .. tostring(carry_type) .. "\" type.")
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
	local carry_type = tweak_data.carry[carry_id].type
	local movement_penalty = nil
	if LuaNetworking:IsMultiplayer() 
			and not LuaNetworking:IsHost() 
			and self:IsRemoteHostSyncEnabled() then
		movement_penalty = self.host_settings.movement_penalties[carry_type]
	else
		movement_penalty = self.settings.movement_penalties[carry_type]
	end
	return movement_penalty ~= nil 
		and ((100 -movement_penalty) / 100) 
		or 1
end

--[[
	Set the mod to be allowed in online games not hosted by this client
]]
function BLT_CarryStacker:HostAllowsMod()
	self.host_settings.is_mod_allowed = true
end

--[[
	Set the mod to NOT be allowed in online games not hosted by this 
	client
]]
function BLT_CarryStacker:HostDisallowsMod()
	self.host_settings.is_mod_allowed = false
end

--[[
	TODO
]]
function BLT_CarryStacker:IsModEnabled()
	-- Unable to use if online and offline only is toggled
	if self:IsOfflineOnly() and not Global.game_settings.single_player then
		return false
	end
	-- Able to drop loot even if stealth failed on stealth-only
	if self:IsStealthOnly() 
			and not managers.groupai:state():whisper_mode() 
			and #self.stack > 0 then
		return true
	-- Unable to use the mod after every item was dropped if 
	-- stealth-only and stealth failed
	elseif self:IsStealthOnly() 
			and not managers.groupai:state():whisper_mode() 
			and #self.stack == 0 then
		return false
	end
	if LuaNetworking:IsHost() then
		return true
	end
	return self.host_settings.is_mod_allowed
end

--[[
	Set the setting identified by setting_id to state.

	setting_id is a string.
	state has to have a value valid for the given setting_id.

	Example:
		BLT_CarryStacker:SetSetting("toggle_stealth", true)
]]
function BLT_CarryStacker:SetSetting(setting_id, state)
	self.settings[setting_id] = state
end

function BLT_CarryStacker:SetRemoteHostSync(state)
	self.host_settings.remote_host_sync = state
end

function BLT_CarryStacker:IsRemoteHostSyncEnabled()
	return self.host_settings.remote_host_sync
end 

function BLT_CarryStacker:IsHostSyncEnabled()
	return self.settings.toggle_host
end

function BLT_CarryStacker:IsStealthOnly()
	return self.settings.toggle_stealth
end

function BLT_CarryStacker:IsOfflineOnly()
	return self.settings.toggle_offline
end

--[[
	Return whether the player can carry a bag with carry_id.

	carry_id is a string. Example: "heavy"

	The return type is a boolean value.
]]
function BLT_CarryStacker:CanCarry(carry_id)
	local check_weight = self.weight * self:getWeightForType(carry_id)
	-- Unable to pick up more loot using stealth-only in case of alarm
	if self:IsStealthOnly() 
			and not managers.groupai:state():whisper_mode() 
			and #self.stack > 0 then
		return false
	end
	return check_weight >= 0.25
end

--[[
	Add to the top of the stack the carry cdata.
]]
function BLT_CarryStacker:AddCarry(cdata)
	self.weight = self.weight * self:getWeightForType(cdata.carry_id)
	table.insert(self.stack, cdata)
	self:HudRefresh()
end

--[[
	Remove the top-most carry from the stack and return it.

	If the stack is empty, it returns nil.
]]
function BLT_CarryStacker:RemoveCarry()
	if #self.stack == 0 then
		return nil
	end
	local cdata = self.stack[#self.stack]
	self.weight = self.weight / self:getWeightForType(cdata.carry_id)
	table.remove(self.stack, #self.stack)
	if #self.stack == 0 then
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
	managers.hud:remove_special_equipment("carrystacker")
	if #self.stack > 0 then
		managers.hud:add_special_equipment({
			id = "carrystacker", 
			icon = "pd2_loot", 
			amount = #self.stack
		})
	end
end

Hooks:Add("LocalizationManagerPostInit", 
	"LocalizationManagerPostInit_BLT_CarryStacker", 
	function(loc)
		loc:load_localization_file(BLT_CarryStacker._path .. "loc/english.txt")
	end
)

Hooks:Add("MenuManagerInitialize", 
	"MenuManagerInitialize_BLT_CarryStacker", 
	function(menu_manager)
		-- Callback for the movement penalty sliders
		MenuCallbackHandler.BLT_CarryStacker_setBagPenalty = function(this, item)
			local _type = item:name():sub(7)

			BLT_CarryStacker.settings.movement_penalties[_type] = item:value()
			if _type == "light" then
				BLT_CarryStacker.settings.movement_penalties.coke_light = item:value()
			elseif _type == "heavy" then
				BLT_CarryStacker.settings.movement_penalties.being = item:value()
				BLT_CarryStacker.settings.movement_penalties.slightly_very_heavy = item:value()
			end
		end	

		-- Reset button callback
		MenuCallbackHandler.BLT_CarryStacker_Reset = function(this, item)
			BLT_CarryStacker:ResetSettings()

			MenuHelper:ResetItemsToDefaultValue(item, {["bltcs_light"] = true}, 
				BLT_CarryStacker.settings.movement_penalties.light)
			MenuHelper:ResetItemsToDefaultValue(item, {["bltcs_medium"] = true}, 
				BLT_CarryStacker.settings.movement_penalties.medium)
			MenuHelper:ResetItemsToDefaultValue(item, {["bltcs_heavy"] = true}, 
				BLT_CarryStacker.settings.movement_penalties.heavy)
			MenuHelper:ResetItemsToDefaultValue(item, {["bltcs_very_heavy"] = true}, 
				BLT_CarryStacker.settings.movement_penalties.very_heavy)
			MenuHelper:ResetItemsToDefaultValue(item, {["bltcs_mega_heavy"] = true}, 
				BLT_CarryStacker.settings.movement_penalties.mega_heavy)
		end

		MenuCallbackHandler.BLT_CarryStacker_Open_Options = function(this, is_opening)
			if not is_opening then return end

			if LuaNetworking:IsMultiplayer() 
					and not LuaNetworking:IsHost() 
					and BLT_CarryStacker:IsRemoteHostSyncEnabled() then
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
			BLT_CarryStacker:Save()

			if BLT_CarryStacker:IsHostSyncEnabled() 
					and LuaNetworking:IsMultiplayer() 
					and LuaNetworking:IsHost() then
				BLT_CarryStacker:syncConfigToAll()
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleHostSync = function(this, item)
			BLT_CarryStacker:SetSetting("toggle_host", val2bool(item:value()))

			if BLT_CarryStacker:IsHostSyncEnabled() 
					and LuaNetworking:IsMultiplayer() 
					and LuaNetworking:IsHost() then
				LuaNetworking:SendToPeers("BLT_CarryStacker_AllowMod", 
					BLT_CarryStacker:IsHostSyncEnabled())
				BLT_CarryStacker:syncConfigToAll()
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleStealthOnly = function(this, item)
			BLT_CarryStacker:SetSetting("toggle_stealth", val2bool(item:value()))
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleOfflineOnly = function(this, item)
			BLT_CarryStacker:SetSetting("toggle_offline", val2bool(item:value()))
		end

		-- Help button callback
		MenuCallbackHandler.BLT_CarryStacker_Help = function(this, item)
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
				tbl["toggle_host"] = BLT_CarryStacker.settings["toggle_host"]
				tbl["toggle_stealth"] = BLT_CarryStacker.settings["toggle_stealth"]
				tbl["toggle_offline"] = BLT_CarryStacker.settings["toggle_offline"]
				return tbl
			-- The function is declared and called
			end)()
		)
	end
)
