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
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
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
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		BLT_CarryStacker:DoMasterFunction(false,
			master_PlayerManager_drop_carry, self, ...)
		return
	end

	if #BLT_CarryStacker.stack == 0 then
        BLT_CarryStacker:Log("WARNING: Request to drop carry, but the stack is empty")
        return
    end

    local cdata = BLT_CarryStacker.stack[#BLT_CarryStacker.stack]
    BLT_CarryStacker:Log("The carry being dropped is: " .. tostring(cdata.carry_id))
    master_PlayerManager_drop_carry(self, ...)
    BLT_CarryStacker:Log("The carry has been dropped")
    -- The Carry has to be removed from the stack after master 
    -- drop_carry. This is so that the mod's state is updated 
    -- afterwards. Therefore, the anticheat engine wont detect cheating
    -- when dropping the carry
    BLT_CarryStacker:RemoveCarry()
    -- If there are more carries in the stack, the top-most has to be 
    -- set using master set_carry so the game registers it for the next 
    -- drop
    if #BLT_CarryStacker.stack > 0 then
        BLT_CarryStacker:Log("Since there are more items in the stack, " ..
                "using master set_carry with the current top-most carry")
        cdata = BLT_CarryStacker.stack[#BLT_CarryStacker.stack]
        master_PlayerManager_set_carry(self, cdata.carry_id, 
                cdata.multiplier or 1, cdata.dye_initiated, 
                cdata.has_dye_pack, cdata.dye_value_multiplier)
    end
end

--[[
	This function will be called after player is done picking up a bag.
]]
function PlayerManager:set_carry(...)
	BLT_CarryStacker:Log("Request to set a new carry")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
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
