local master_PlayerCarry_perform_jump = PlayerCarry._perform_jump
function PlayerCarry:_perform_jump(jump_vec)
	BLT_CarryStacker:Log("Request to perform a jump")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		BLT_CarryStacker:DoMasterFunction(false, 
			master_PlayerCarry_perform_jump, self, jump_vec)
		return
	end

	if not managers.player:has_category_upgrade("carry", "movement_penalty_nullifier") then
		BLT_CarryStacker:Log("The player's movement has to be penalised. " ..
			"Multiplying the jump speed by the total carry weight")
		mvector3.multiply(jump_vec, BLT_CarryStacker.weight)
	end

	BLT_CarryStacker:Log("Calling super._perform_jump")
	PlayerCarry.super._perform_jump(self, jump_vec)
end

local master_PlayerCarry_get_max_walk_speed = PlayerCarry._get_max_walk_speed
function PlayerCarry:_get_max_walk_speed(...)
	BLT_CarryStacker:RLog("Request to get the max walking speed")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		return BLT_CarryStacker:DoMasterFunction(true, 
			master_PlayerCarry_get_max_walk_speed, self, ...)
	end

	local penalty = BLT_CarryStacker.weight
	if managers.player:has_category_upgrade("carry", "movement_penalty_nullifier") then
		BLT_CarryStacker:RLog("The player's max walking speed will not be penalised")
		penalty = 1
	else
		BLT_CarryStacker:RLog("The player's max walking speed will be " ..
			"penalised according to the bag's weight")
		penalty = math.clamp(penalty * managers.player:upgrade_value("carry", 
			"movement_speed_multiplier", 1), 0, 1)
	end
	
	BLT_CarryStacker:RLog("Returning super max walking speed penalised by " .. 
		tostring(penalty))
	local result = PlayerCarry.super._get_max_walk_speed(self, ...) * penalty
	BLT_CarryStacker:RLog("The max walk speed is " .. tostring(result))
	return result
end

local master_PlayerCarry_get_walk_headbob = PlayerCarry._get_walk_headbob
function PlayerCarry:_get_walk_headbob(...)
	BLT_CarryStacker:RLog("Request to get walk headbob")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		return BLT_CarryStacker:DoMasterFunction(true, 
			master_PlayerCarry_get_walk_headbob, self, ...)
	end

	BLT_CarryStacker:RLog("Returning super walk headbob penalised by the " ..
		"current weight: " .. tostring(BLT_CarryStacker.weight))
	local result = PlayerCarry.super._get_walk_headbob(self, ...) * BLT_CarryStacker.weight
	BLT_CarryStacker:RLog("The walk headbob is: " .. tostring(result))
	return result
end

local master_PlayerCarry_check_action_run = PlayerCarry._check_action_run
function PlayerCarry:_check_action_run(...)
	BLT_CarryStacker:RLog("Request to check whether the player can run")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		BLT_CarryStacker:DoMasterFunction(true, 
		 	master_PlayerCarry_check_action_run, self, ...)
		return
	end

	if BLT_CarryStacker.weight >= 0.75 
			or managers.player:has_category_upgrade("carry", "movement_penalty_nullifier") then
		BLT_CarryStacker:RLog("The current weight is greater than 0.75 or " ..
			"the player's movement cant be penalised. Calling super check_run")
		PlayerCarry.super._check_action_run(self, ...)
	end
end
