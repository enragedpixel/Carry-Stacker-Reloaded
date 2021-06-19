dofile(ModPath .. "lua/_modannounce.lua")

--[[
	NETWORK_MESSAGES is a table.

	It contains the different messages ids exchanged through the 
	network.

	Its content will be used as constants, and should NOT be MODIFIED 
	on runtime.

	SET_SETTINGS: Sent by the host, to share its settings with the 
		players
	REQUEST_SETTINGS: Sent to the host, to be notified of mod's 
		settings to be used
]]
BLT_CarryStacker.NETWORK_MESSAGES = {
	SET_SETTINGS = "BLT_CarryStacker_SetSettings",
	REQUEST_SETTINGS = "BLT_CarryStacker_RequestSettings"
}
--[[
	OLD_NETWORK_MESSAGES is a table.

	It contains the different messages ids that used to be exchanged through 
	the network.
	They have to be kept for backwards compatibility.

	Its content will be used as constants, and should NOT be MODIFIED 
	on runtime.

	ALLOW_MOD: Sent by the host to notify other players they can use 
	the mod
	REQUEST_MOD_USAGE: Sent to the host, to request using the mod
	SET_HOST_CONFIG: Sent by the host, to synchronize configuration

	Note: Modifying these ids may break backwards compatibility
]]
BLT_CarryStacker.OLD_NETWORK_MESSAGES = {
	ALLOW_MOD = "BLT_CarryStacker_AllowMod",
	REQUEST_MOD_USAGE = "BLT_CarryStacker_Request",
	SET_HOST_CONFIG = "BLT_CarryStacker_SyncConfig"
}

BLT_CarryStacker.CURR_NET_VERSION = 2
BLT_CarryStacker.NET_VERSION_1 = 1
--[[
	Table with peerIDs as keys, and network versions as data

	E.g.:
		peerVersions = {
			somePeerId = 2,
			someOtherPeerIdWithOldClient = 1
		}
]]
BLT_CarryStacker.peerVersions = {}

Hooks:Add("NetworkReceivedData", 
	"NetworkReceivedData_BLT_CarryStacker", 
	function(sender, id, data)
		-- Old network messages
		if id == BLT_CarryStacker.OLD_NETWORK_MESSAGES.ALLOW_MOD then
			BLT_CarryStacker:handleAllowModMessage(sender, data)
		elseif id == BLT_CarryStacker.OLD_NETWORK_MESSAGES.REQUEST_MOD_USAGE then
			BLT_CarryStacker:handleRequestMessage(sender, data)
		elseif id == BLT_CarryStacker.OLD_NETWORK_MESSAGES.SET_HOST_CONFIG then
			BLT_CarryStacker:handleSetHostConfig(sender, data)
		else
			BLT_CarryStacker:handleReceivedMessage(sender, id, data)
		end
	end
)

function BLT_CarryStacker:handleAllowModMessage(sender, data)
	BLT_CarryStacker:Log("Received a request to allow the mod")
	BLT_CarryStacker:updatePeerVersion(sender, BLT_CarryStacker.NET_VERSION_1)

	BLT_CarryStacker:HostAllowsMod()
	BLT_CarryStacker:SetRemoteHostSync(data == 1)
end

function BLT_CarryStacker:handleRequestMessage(sender, data)
	BLT_CarryStacker:Log("Received a request to use the mod")
	BLT_CarryStacker:updatePeerVersion(sender, BLT_CarryStacker.NET_VERSION_1)

	LuaNetworking:SendToPeer(sender, 
		BLT_CarryStacker.OLD_NETWORK_MESSAGES.ALLOW_MOD, 
		BLT_CarryStacker:IsHostSyncEnabled() and 1 or 0)

	if BLT_CarryStacker:IsHostSyncEnabled() then
		BLT_CarryStacker:syncConfigToClient(sender)
	end
end

function BLT_CarryStacker:handleSetHostConfig(sender, data)
	BLT_CarryStacker:Log("Received a request to update mod settings")
	BLT_CarryStacker:updatePeerVersion(sender, BLT_CarryStacker.NET_VERSION_1)

	local penalty_split = split(tostring(data), ":")
	local carry_type = penalty_split[1]
	if type(penalty_split[2]) ~= "number" then return end

	local penalty = tonumber(penalty_split[2])

	BLT_CarryStacker:setHostMovementPenalty(carry_type, penalty)
end

function BLT_CarryStacker:handleReceivedMessage(sender, msgId, messageStr)
	local message = json.decode(messageStr)

	local clientVersion = message.version or tostring(BLT_CarryStacker.NET_VERSION_1)
	clientVersion = tonumber(clientVersion)
	BLT_CarryStacker:updatePeerVersion(sender, clientVersion)

	local data = message.data or {}

	if msgId == BLT_CarryStacker.NETWORK_MESSAGES.SET_SETTINGS then
		BLT_CarryStacker:handleSetSettingsMessage(sender, data)
	elseif msgId == BLT_CarryStacker.NETWORK_MESSAGES.REQUEST_SETTINGS then
		BLT_CarryStacker:handleRequestSettingsMessage(sender, data)
	end
end


function BLT_CarryStacker:handleSetSettingsMessage(sender, data)
	BLT_CarryStacker:Log("Received a request to configure mod's settings")
	-- TODO show a message to the player announcing the host has changed
	-- the game configuration, and show the configuration that has ben changed
	BLT_CarryStacker.host_settings = data
	DelayedCalls:Remove("BLT_CarryStacker.OldHostVersionTimer")
end

function BLT_CarryStacker:handleRequestSettingsMessage(sender, data)
	BLT_CarryStacker:Log("Received a request to get mod's settings")
	BLT_CarryStacker:syncConfigToClient(sender)
end

function BLT_CarryStacker:createNetworkMessage(data)
	return json.encode({
		version = BLT_CarryStacker.CURR_NET_VERSION,
		data = data
	})
end

function BLT_CarryStacker:updatePeerVersion(sender, version)
	BLT_CarryStacker:Log("Peer " .. tostring(sender) .. " can use version " 
		.. tostring(version))
	local currClientVersion = BLT_CarryStacker.peerVersions[sender]
	if not currClientVersion or currClientVersion < version then
		BLT_CarryStacker.peerVersions[sender] = version
	end
	BLT_CarryStacker:Log("Peer's " .. tostring(sender) .. " version is " 
		.. tostring(BLT_CarryStacker.peerVersions[sender]))
end

function BLT_CarryStacker:syncConfigToClient(peer_id)
	BLT_CarryStacker:Log("Request to sync configuration to " .. tostring(peer_id))
	if BLT_CarryStacker.peerVersions[sender] == BLT_CarryStacker.NET_VERSION_1 then
		for i,v in pairs(BLT_CarryStacker:getLocalMovementPenalties()) do
			LuaNetworking:SendToPeer(peer_id, 
				BLT_CarryStacker.OLD_NETWORK_MESSAGES.SET_HOST_CONFIG, i .. ":" .. v)
		end
	else
		LuaNetworking:SendToPeer(peer_id, 
			BLT_CarryStacker.NETWORK_MESSAGES.SET_SETTINGS,
			BLT_CarryStacker:createNetworkMessage({
				is_mod_allowed = BLT_CarryStacker.settings.toggle_enable 
					and not BLT_CarryStacker:IsOfflineOnly(),
				is_stealth_only = BLT_CarryStacker:IsStealthOnly(),
				remote_host_sync = BLT_CarryStacker:IsHostSyncEnabled(),
				movement_penalties = BLT_CarryStacker:getLocalMovementPenalties()
			}))
	end
end

function BLT_CarryStacker:syncConfigToAll()
	BLT_CarryStacker:Log("Request to sync configuration to all peers")
	for peer_id, ply in pairs(LuaNetworking:GetPeers()) do
	    BLT_CarryStacker:syncConfigToClient(peer_id)
	end
end

local master_client_load_complete = ClientNetworkSession.on_load_complete
function ClientNetworkSession:on_load_complete()
	BLT_CarryStacker:Log("Client network session loaded. Calling the master callback")
	master_client_load_complete(self)

	BLT_CarryStacker:Log("By default, setting the mod to not be allowed")
	BLT_CarryStacker:HostDisallowsMod()
	BLT_CarryStacker:SetRemoteHostSync(false)
	
	BLT_CarryStacker:Log("Requesting the host mod's settings")
	LuaNetworking:SendToPeer(managers.network:session():server_peer():id(), 
		BLT_CarryStacker.NETWORK_MESSAGES.REQUEST_SETTINGS,
		BLT_CarryStacker:createNetworkMessage("request"))
	-- If the host does not respond to the previous request within 10 seconds,
	-- we can assume it is running an older version of the game
	DelayedCalls:Add("BLT_CarryStacker.OldHostVersionTimer", 10, function()
		LuaNetworking:SendToPeer(managers.network:session():server_peer():id(), 
			BLT_CarryStacker.NETWORK_MESSAGES.REQUEST_MOD_USAGE, "request")
		end)
end

function split(str, pat)
	local t = {}
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(t,cap)
		end
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	end
	return t
end
