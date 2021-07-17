--[[
	A higher order function that calls master_function or returns true
	depending on whether the mod is enabled or not.

	master_function is the function to be called if the mod is disabled
	All other arguments will be passed to master_function

	Returns either the result of master_function or true
]]
function doAntiAntiCheat(master_function, ...)
	local logger = BLT_CarryStacker.Log
	logger("Request to do the antianticheat procedure")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		return BLT_CarryStacker.DoMasterFunction(false, master_function, ...)
	end
	logger("The mod is enabled. Returning true")
	return true
end

--[[
	This function will be called whenever the player's carry is to be
	verified.

	If false is returned, the anticheat will detect cheating.
]]
local master_PlayerManager_verify_carry = PlayerManager.verify_carry
function PlayerManager:verify_carry(peer, carry_id)
	local logger = BLT_CarryStacker.Log
	logger("Request to verify carry")
	return doAntiAntiCheat(master_PlayerManager_verify_carry, self, peer, carry_id)
end

--[[
	This function will be called whenever the player gets a new carry.

	If false is returned, the anticheat will detect cheating.
]]
local master_PlayerManager_register_carry = PlayerManager.register_carry
function PlayerManager:register_carry(peer, carry_id)
	local logger = BLT_CarryStacker.Log
	logger("Request to register carry")
	return doAntiAntiCheat(master_PlayerManager_register_carry, self, peer, carry_id)
end
