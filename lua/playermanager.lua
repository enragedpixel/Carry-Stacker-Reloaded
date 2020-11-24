--[[
	This functions are presaved before overriding them becase drop_carry
	will make use of both master drop_carry and master set_carry
]]
local master_PlayerManager_set_carry = PlayerManager.set_carry
local master_PlayerManager_drop_carry = PlayerManager.drop_carry
local master_PlayerManager_can_carry = PlayerManager.can_carry

--[[
	This function will be called to check whether the player can carry 
	a bag.
]]
function PlayerManager:can_carry(carry_id)
	BLT_CarryStacker:Log("Request to check whether the player can carry " ..
		tostring(carry_id))
	if not BLT_CarryStacker:IsModEnabled() then
		return BLT_CarryStacker:DoMasterFunction(false,
			master_PlayerManager_can_carry, self, carry_id)
	end
	BLT_CarryStacker:Log("Returning the result of BLT_CarryStacker:CanCarry")
	return BLT_CarryStacker:CanCarry(carry_id)
end

--[[
	This function will be called when the player wants to carry a bag.
]]
function PlayerManager:drop_carry(...)
	BLT_CarryStacker:Log("Request to drop a carry")
	if not BLT_CarryStacker:IsModEnabled() then
		BLT_CarryStacker:DoMasterFunction(false,
			master_PlayerManager_drop_carry, self, ...)
		return
	end

	local cdata = BLT_CarryStacker:RemoveCarry()
	if cdata then
		master_PlayerManager_drop_carry(self, ...)
		if #BLT_CarryStacker.stack > 0 then
			BLT_CarryStacker:Log("Since there are more items in the stack, " ..
				"using master set_carry with the current top-most carry")
			cdata = BLT_CarryStacker.stack[#BLT_CarryStacker.stack]
			master_PlayerManager_set_carry(self, cdata.carry_id, 
				cdata.multiplier or 1, cdata.dye_initiated, 
				cdata.has_dye_pack, cdata.dye_value_multiplier)
		end
	end
end

--[[
	This function will be called after player is done picking up a bag.
]]
function PlayerManager:set_carry(...)
	BLT_CarryStacker:Log("Request to set a new carry")
	if not BLT_CarryStacker:IsModEnabled() then
		BLT_CarryStacker:DoMasterFunction(false,
			master_PlayerManager_set_carry, self, ...)
		return
	end

	BLT_CarryStacker:Log("Setting the carry with master set_carry and " ..
		"adding the item to the stack")
	master_PlayerManager_set_carry(self, ...)
	BLT_CarryStacker:AddCarry(self:get_my_carry_data())
	-- This will be used to prevent the player from picking a new bag
	-- within the next 0.1 sec
	PlayerStandard:block_use_item()
end
