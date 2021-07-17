_G.BLT_CarryStacker = _G.BLT_CarryStacker or {}
BLT_CarryStacker._path = ModPath
BLT_CarryStacker._data_path = SavePath .. "carrystacker.txt"

dofile(ModPath .. "lua/bltcs_common.lua")
dofile(ModPath .. "lua/bltcs_data.lua")
dofile(ModPath .. "lua/bltcs_methods.lua")

Hooks:Add("LocalizationManagerPostInit", 
	"LocalizationManagerPostInit_BLT_CarryStacker", 
	function(loc)
		local logger = BLT_CarryStacker.Log
		logger("Loading the localization file")
		local path = BLT_CarryStacker._path .. "loc/english.txt"
		logger("The path to the localization file is " .. path)
		loc:load_localization_file(path)
	end
)

Hooks:PostHook(MenuManager, "close_menu", 
	"MenuManager_Post_close_menu_BLT_CarryStacker",
	function(menu_manager, menu_name)
		local logger = BLT_CarryStacker.Log
		if menu_name == "menu_pause" then
			-- This section of the code will be executed whenever the 
			-- player closes the pause menu in-game
			logger("Closing the pause menu")
			for settingName, callback in pairs(BLT_CarryStacker.closePauseMenuCallbacks) do
				if callback then
					logger("Calling the callback for " .. settingName)
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
		local logger = BLT_CarryStacker.Log
		logger("Initializing the menu")
		-- Callback for the movement penalty sliders
		MenuCallbackHandler.BLT_CarryStacker_setBagPenalty = function(this, item)
			logger("The player requested changing a bag penalty")
			local _type = item:name():sub(7)
			local new_value = item:value()
			BLT_CarryStacker:SetMovPenaltySetting(_type, new_value)
			if _type == "light" then
				logger("Since 'light' bag's penality has been " ..
					"updated, updating 'coke_light' as well")
				BLT_CarryStacker:SetMovPenaltySetting("coke_light", new_value)
			elseif _type == "heavy" then
				logger("Since 'heavy' bag's penality has been " ..
					"updated, updating 'being' and 'slightly_very_heavy as well'")
				BLT_CarryStacker:SetMovPenaltySetting("being", new_value)
				BLT_CarryStacker:SetMovPenaltySetting("slightly_very_heavy", new_value)
			end
		end	

		-- Reset button callback
		MenuCallbackHandler.BLT_CarryStacker_Reset = function(this, item)
			local logger = BLT_CarryStacker.Log
			logger("The player requested resetting setting " ..
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

			local logger = BLT_CarryStacker.Log
			logger("The options menu is being opened")
			if LuaNetworking:IsMultiplayer() 
					and not LuaNetworking:IsHost() 
					and BLT_CarryStacker:IsRemoteHostSyncEnabled() then
				logger("Since the player is not the host and " ..
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
			local logger = BLT_CarryStacker.Log
			logger("The options are being closed. Saving them")
			BLT_CarryStacker:Save()

			if BLT_CarryStacker:IsHostSyncEnabled() 
					and LuaNetworking:IsMultiplayer() 
					and LuaNetworking:IsHost() then
				logger("Since host sync is enabled and the " ..
					" player is the host, synchronising config to peers")
				BLT_CarryStacker:syncConfigToAll()
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleEnable = function(this, item)
			local logger = BLT_CarryStacker.Log
			logger("The player wants to change the value of toggle_enable")
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
						logger("The player just configured " ..
							"the mod to be disabled, but carrying bags. " ..
							"Advising the mod wont be disabled until all " ..
							"bags are dropped")
						BLT_CarryStacker.ShowInfoMessage("bltcs_disabled_message")
					end
				end
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleHostSync = function(this, item)
			local logger = BLT_CarryStacker.Log
			logger("The player wants to change the value of toggle_host")
			local value = val2bool(item:value())
			BLT_CarryStacker:SetSetting("toggle_host", value)

			BLT_CarryStacker.closePauseMenuCallbacks.toggle_host = function()
				if BLT_CarryStacker:IsHostSyncEnabled() 
						and LuaNetworking:IsMultiplayer() 
						and LuaNetworking:IsHost() then
					logger("Since host sync is enabled and the " ..
						" player is the host, synchronising config to peers")
					LuaNetworking:SendToPeers(
						BLT_CarryStacker.NETWORK_MESSAGES.ALLOW_MOD, 
						BLT_CarryStacker:IsHostSyncEnabled() and 1 or 0)
					BLT_CarryStacker:syncConfigToAll()
				end
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleStealthOnly = function(this, item)
			local logger = BLT_CarryStacker.Log
			logger("The player wants to change the value of toggle_stealth")
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
						logger("The player just configured " ..
							"the mod to be used Stealth-Only, but the alarm " ..
							"is triggered and they are carrying bags. " ..
							"Advising the mod wont be disabled until all " ..
							"bags are dropped")
						BLT_CarryStacker.ShowInfoMessage("bltcs_stealth_only_alarm_message")
					end
				end
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleOfflineOnly = function(this, item)
			local logger = BLT_CarryStacker.Log
			logger("The player wants to change the value of toggle_offline")
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
						logger("The player just configured " ..
							"the mod to be used Offline-Only, but the player " ..
							"is online and they are carrying bags. " ..
							"Advising the mod wont be disabled until all " ..
							"bags are dropped")
						BLT_CarryStacker.ShowInfoMessage("bltcs_offline_only_online_message")
					end
				end
			end
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleShowChatInfo = function(this, item)
			local logger = BLT_CarryStacker.Log
			logger("The player wants to change the value of toggle_show_chat_info")
			BLT_CarryStacker:SetSetting("toggle_show_chat_info", val2bool(item:value()))
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleDebug = function(this, item)
			local logger = BLT_CarryStacker.Log
			logger("The player wants to change the value of toggle_debug")
			BLT_CarryStacker:SetSetting("toggle_debug", val2bool(item:value()))
		end

		MenuCallbackHandler.BLT_CarryStacker_toggleRepeatedLogs = function(this, item)
			local logger = BLT_CarryStacker.Log
			logger("The player wants to change the value of toggle_repeated_logs")
			BLT_CarryStacker:SetSetting("toggle_repeated_logs", val2bool(item:value()))
		end

		-- Help button callback
		MenuCallbackHandler.BLT_CarryStacker_Help = function(this, item)
			local logger = BLT_CarryStacker.Log
			logger("The player want to be shown the help message")
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
