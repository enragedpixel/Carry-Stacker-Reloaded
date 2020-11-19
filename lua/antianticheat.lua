--[[
	This function will be called whenever the player's carry is to be
	verified.

	If false is returned, the anticheat will detect cheating.
]]
local master_PlayerManager_verify_carry = PlayerManager.verify_carry
function PlayerManager:verify_carry(peer, carry_id)
	if not BLT_CarryStacker:IsModEnabled() then
		return master_PlayerManager_verify_carry(self, peer, carry_id)
	end

	return true
end

--[[
	This function will be called whenever the player's equipment is to be
	verified.

	If false is returned, the anticheat will detect cheating.
]]
local master_PlayerManager_verify_equipment = PlayerManager.verify_equipment
function PlayerManager:verify_equipment(peer, equipment_id)
	if not BLT_CarryStacker:IsModEnabled() then
		return master_PlayerManager_verify_equipment(self, peer, equipment_id)
	end

	return true
end

--[[
	This function will be called whenever the player's granade is to be
	verified.

	If false is returned, the anticheat will detect cheating.
]]
local master_PlayerManager_verify_grenade = PlayerManager.verify_grenade
function PlayerManager:verify_grenade(peer)
	if not BLT_CarryStacker:IsModEnabled() then
		return master_PlayerManager_verify_grenade(self, peer)
	end

	return true
end	

--[[
	This function will be called whenever the player gets a new 
	granade.

	If false is returned, the anticheat will detect cheating.
]]
local master_PlayerManager_register_grenade = PlayerManager.register_grenade
function PlayerManager:register_grenade(peer)
	if not BLT_CarryStacker:IsModEnabled() then
		return master_PlayerManager_register_grenade(self, peer)
	end
	
	return true
end

--[[
	This function will be called whenever the player gets a new carry.

	If false is returned, the anticheat will detect cheating.
]]
local master_PlayerManager_register_carry = PlayerManager.register_carry
function PlayerManager:register_carry(peer, carry_id)
	if not BLT_CarryStacker:IsModEnabled() then
		return master_PlayerManager_register_carry(self, peer, carry_id)
	end

	return true
end
