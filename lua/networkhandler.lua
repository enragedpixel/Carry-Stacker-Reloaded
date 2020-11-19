dofile(ModPath .. "lua/_modannounce.lua")

Hooks:Add("NetworkReceivedData", 
	"NetworkReceivedData_BLT_CarryStacker", 
	function(sender, id, data)
		if id == "BLT_CarryStacker_AllowMod" then
			BLT_CarryStacker:HostAllowsMod()
			BLT_CarryStacker:SetRemoteHostSync(data == 1)
		elseif id == "BLT_CarryStacker_Request" then
			LuaNetworking:SendToPeer(sender, "BLT_CarryStacker_AllowMod", 
				BLT_CarryStacker:IsHostSyncEnabled() and 1 or 0)

			if BLT_CarryStacker:IsHostSyncEnabled() then
				BLT_CarryStacker:syncConfigToClient(sender)
			end
		elseif id == "BLT_CarryStacker_SyncConfig" then
			local penalty_split = split(tostring(data), ":")
			local carry_type = penalty_split[1]
			if type(penalty_split[2]) ~= "number" then return end

			local penalty = tonumber(penalty_split[2])

			BLT_CarryStacker:setHostMovementPenalty(carry_type, penalty)
		end
	end
)

function BLT_CarryStacker:syncConfigToClient(peer_id)
	for i,v in pairs(BLT_CarryStacker:getLocalMovementPenalties()) do
		LuaNetworking:SendToPeer(peer_id, "BLT_CarryStacker_SyncConfig", i .. ":" .. v)
	end
end

function BLT_CarryStacker:syncConfigToAll()
	for i,v in pairs(BLT_CarryStacker:getLocalMovementPenalties()) do
		LuaNetworking:SendToPeers("BLT_CarryStacker_SyncConfig", i .. ":" .. v)
	end
end

local master_client_load_complete = ClientNetworkSession.on_load_complete
function ClientNetworkSession:on_load_complete()
	master_client_load_complete(self)

	BLT_CarryStacker:HostDisallowsMod()
	BLT_CarryStacker:SetRemoteHostSync(false)
	
	LuaNetworking:SendToPeer(managers.network:session():server_peer():id(), 
		"BLT_CarryStacker_Request", "request")
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
