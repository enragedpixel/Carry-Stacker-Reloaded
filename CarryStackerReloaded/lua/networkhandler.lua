dofile(ModPath .. "lua/_modannounce.lua")

Hooks:Add("NetworkReceivedData", 
	"NetworkReceivedData_BLT_CarryStacker", 
	function(sender, id, data)
		local logger = BLT_CarryStacker.Log
		if id == BLT_CarryStacker.NETWORK_MESSAGES.ALLOW_MOD then
			logger("Received a request to allow the mod")
			BLT_CarryStacker:HostAllowsMod()
			BLT_CarryStacker:SetRemoteHostSync(data == 1)
		elseif id == BLT_CarryStacker.NETWORK_MESSAGES.REQUEST_MOD_USAGE then
			logger("Received a request to use the mod")
			LuaNetworking:SendToPeer(sender, 
				BLT_CarryStacker.NETWORK_MESSAGES.ALLOW_MOD, 
				BLT_CarryStacker:IsHostSyncEnabled() and 1 or 0)

			if BLT_CarryStacker:IsHostSyncEnabled() then
				BLT_CarryStacker:syncConfigToClient(sender)
			end
		elseif id == BLT_CarryStacker.NETWORK_MESSAGES.SET_HOST_CONFIG then
			logger("Received a request to update mod settings")
			local penalty_split = split(tostring(data), ":")
			local carry_type = penalty_split[1]
			if type(penalty_split[2]) ~= "number" then return end

			local penalty = tonumber(penalty_split[2])

			BLT_CarryStacker:setHostMovementPenalty(carry_type, penalty)
		end
	end
)

function BLT_CarryStacker:syncConfigToClient(peer_id)
	local logger = BLT_CarryStacker.Log
	logger("Request to sync configuration to " .. tostring(peer_id))
	for i,v in pairs(BLT_CarryStacker:getLocalMovementPenalties()) do
		LuaNetworking:SendToPeer(peer_id, 
			BLT_CarryStacker.NETWORK_MESSAGES.SET_HOST_CONFIG, i .. ":" .. v)
	end
end

function BLT_CarryStacker:syncConfigToAll()
	local logger = BLT_CarryStacker.Log
	logger("Request to sync configuration to all peers")
	-- TODO the stealth_only option should also be synchronised
	for i,v in pairs(BLT_CarryStacker:getLocalMovementPenalties()) do
		LuaNetworking:SendToPeers(
			BLT_CarryStacker.NETWORK_MESSAGES.SET_HOST_CONFIG, i .. ":" .. v)
	end
end

local master_client_load_complete = ClientNetworkSession.on_load_complete
function ClientNetworkSession:on_load_complete()
	local logger = BLT_CarryStacker.Log
	logger("Client network session loaded. Calling the master callback")
	master_client_load_complete(self)

	logger("By default, setting the mod to not be allowed")
	BLT_CarryStacker:HostDisallowsMod()
	BLT_CarryStacker:SetRemoteHostSync(false)
	
	logger("Requesting the host to allow the mod")
	LuaNetworking:SendToPeer(managers.network:session():server_peer():id(), 
		BLT_CarryStacker.NETWORK_MESSAGES.REQUEST_MOD_USAGE, "request")
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
