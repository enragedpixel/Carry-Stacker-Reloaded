local master_IntimitateInteractionExt_interact_blocked = IntimitateInteractionExt._interact_blocked
local master_CarryInteractionExt_interact_blocked = CarryInteractionExt._interact_blocked
local master_CarryInteractionExt_can_select = CarryInteractionExt.can_select

function IntimitateInteractionExt:_interact_blocked(player)
	BLT_CarryStacker:Log("Called IntimitateInteractionExt:_interact_blocked")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		return  BLT_CarryStacker:DoMasterFunction(false, 
			master_IntimitateInteractionExt_interact_blocked, self, player)
	end

	if self.tweak_data == "corpse_dispose" then
		BLT_CarryStacker:Log("The interaction is corpse_dispose")
		if managers.player:chk_body_bags_depleted() then
			BLT_CarryStacker:Log("The player is out of body bags. The " ..
				"interaction is blocked")
			return true, nil, "body_bag_limit_reached"
		end
		BLT_CarryStacker:Log("Checking whether the player can carry the body")
		local result = not managers.player:can_carry("person")
		BLT_CarryStacker:Log("The interaction is blocked: " .. tostring(result))
		return result
	end
	BLT_CarryStacker:Log("The interaction is not corpse_dispose. Using " ..
		"master function")
	local result = master_IntimitateInteractionExt_interact_blocked(self, player)
	BLT_CarryStacker:Log("The master's function result is " .. tostring(result))
	return result
end

function CarryInteractionExt:_interact_blocked(player)
	BLT_CarryStacker:Log("Called CarryInteractionExt:_interact_blocked")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		return  BLT_CarryStacker:DoMasterFunction(false, 
			master_CarryInteractionExt_interact_blocked, self, player)
	end

	BLT_CarryStacker:Log("Checking whether the player can carry the bag")
	local result = not managers.player:can_carry(self._unit:carry_data():carry_id())
	BLT_CarryStacker:Log("The interacion is blocked: " .. tostring(result))
	return result
end

function CarryInteractionExt:can_select(player)
	BLT_CarryStacker:RLog("Request to check whether the player can select a bag")
	if BLT_CarryStacker:GetModState() ~= BLT_CarryStacker.STATES.ENABLED then
		return  BLT_CarryStacker:DoMasterFunction(true, 
			master_CarryInteractionExt_can_select, self, player)
	end

	BLT_CarryStacker:RLog("Calling super's can select")
	local result = CarryInteractionExt.super.can_select(self, player)
	BLT_CarryStacker:RLog("The super's can_select result is: " .. tostring(result))
	return result
end
