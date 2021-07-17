local master_PlayerCarry_perform_jump = PlayerCarry._perform_jump
function PlayerCarry:_perform_jump(jump_vec)
	local logger = BLT_CarryStacker.Log
	logger("Request to perform a jump")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		BLT_CarryStacker:DoMasterFunction(false, 
			master_PlayerCarry_perform_jump, self, jump_vec)
		return
	end

	if not managers.player:has_category_upgrade("carry", "movement_penalty_nullifier") then
		logger("The player's movement has to be penalised. " ..
			"Multiplying the jump speed by the total carry weight")
		mvector3.multiply(jump_vec, BLT_CarryStacker.weight)
	end

	logger("Calling super._perform_jump")
	PlayerCarry.super._perform_jump(self, jump_vec)
end

local master_PlayerCarry_get_max_walk_speed = PlayerCarry._get_max_walk_speed
function PlayerCarry:_get_max_walk_speed(...)
	local logger = BLT_CarryStacker.RLog
	logger("Request to get the max walking speed")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		return BLT_CarryStacker:DoMasterFunction(true, 
			master_PlayerCarry_get_max_walk_speed, self, ...)
	end

	local penalty = BLT_CarryStacker.weight
	if managers.player:has_category_upgrade("carry", "movement_penalty_nullifier") then
		logger("The player's max walking speed will not be penalised")
		penalty = 1
	else
		logger("The player's max walking speed will be " ..
			"penalised according to the bag's weight")
		penalty = math.clamp(penalty * managers.player:upgrade_value("carry", 
			"movement_speed_multiplier", 1), 0, 1)
	end
	
	logger("Returning super max walking speed penalised by " .. 
		tostring(penalty))
	local result = PlayerCarry.super._get_max_walk_speed(self, ...) * penalty
	logger("The max walk speed is " .. tostring(result))
	return result
end

local master_PlayerCarry_get_walk_headbob = PlayerCarry._get_walk_headbob
function PlayerCarry:_get_walk_headbob(...)
	local logger = BLT_CarryStacker.RLog
	logger("Request to get walk headbob")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		return BLT_CarryStacker:DoMasterFunction(true, 
			master_PlayerCarry_get_walk_headbob, self, ...)
	end

	logger("Returning super walk headbob penalised by the " ..
		"current weight: " .. tostring(BLT_CarryStacker.weight))
	local result = PlayerCarry.super._get_walk_headbob(self, ...) * BLT_CarryStacker.weight
	logger("The walk headbob is: " .. tostring(result))
	return result
end

local master_PlayerCarry_check_action_run = PlayerCarry._check_action_run
function PlayerCarry:_check_action_run(...)
	local logger = BLT_CarryStacker.RLog
	logger("Request to check whether the player can run")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		BLT_CarryStacker:DoMasterFunction(true, 
		 	master_PlayerCarry_check_action_run, self, ...)
		return
	end

	if BLT_CarryStacker.weight >= 0.75 
			or managers.player:has_category_upgrade("carry", "movement_penalty_nullifier") then
		logger("The current weight is greater than 0.75 or " ..
			"the player's movement cant be penalised. Calling super check_run")
		PlayerCarry.super._check_action_run(self, ...)
	end
end
