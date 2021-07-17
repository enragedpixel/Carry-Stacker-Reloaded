--[[
	This functions are presaved before overriding them becase drop_carry
	will make use of both master drop_carry and master set_carry
]]
local master_PlayerManager_set_carry = PlayerManager.set_carry
local master_PlayerManager_drop_carry = PlayerManager.drop_carry
local master_PlayerManager_can_carry = PlayerManager.can_carry

--[[This will prevent the missing bag when carrying 2 or more bags 
and throwing them when using The Fixes mod
]]
TheFixesPreventer = TheFixesPreventer or {}
TheFixesPreventer.remove_bag_from_back_playerman = true

--[[
	This function will be called to check whether the player can carry 
	a bag.
]]
function PlayerManager:can_carry(carry_id, logger)
	logger = logger or BLT_CarryStacker.Log
	logger("Request to check whether the player can carry " ..
		tostring(carry_id))
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		return BLT_CarryStacker.DoMasterFunction(false,
			master_PlayerManager_can_carry, self, carry_id)
	end
	logger("Returning the result of BLT_CarryStacker:CanCarry")
	return BLT_CarryStacker:CanCarry(carry_id, logger)
end

--[[
	This function will be called when the player wants to carry a bag.
]]
function PlayerManager:drop_carry(...)
	local logger = BLT_CarryStacker.Log
	logger("Request to drop a carry")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		BLT_CarryStacker.DoMasterFunction(false,
			master_PlayerManager_drop_carry, self, ...)
		return
	end

	if #BLT_CarryStacker.stack == 0 then
        logger("WARNING: Request to drop carry, but the stack is empty")
        -- If the mod was disabled and the player picked a carry, the 
        -- mod will not be aware of it. This is, even if #stack == 0, 
        -- the player could be carrying a bag
        -- return
    end

    local cdata = BLT_CarryStacker.stack[#BLT_CarryStacker.stack]
    if cdata then
        logger("The carry being dropped is: " .. tostring(cdata.carry_id))
    else
        logger("The mod has no data on the carry being dropped")
    end
    master_PlayerManager_drop_carry(self, ...)
    logger("The carry has been dropped")
    -- The Carry has to be removed from the stack after master 
    -- drop_carry. This is so that the mod's state is updated 
    -- afterwards. Therefore, the anticheat engine wont detect cheating
    -- when dropping the carry
    BLT_CarryStacker:RemoveCarry()
    -- If there are more carries in the stack, the top-most has to be 
    -- set using master set_carry so the game registers it for the next 
    -- drop
    if #BLT_CarryStacker.stack > 0 then
        logger("Since there are more items in the stack, " ..
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
	local logger = BLT_CarryStacker.Log
	logger("Request to set a new carry")
	if BLT_CarryStacker:GetModState() == BLT_CarryStacker.STATES.DISABLED then
		BLT_CarryStacker.DoMasterFunction(false,
			master_PlayerManager_set_carry, self, ...)
		return
	end

	logger("Setting the carry with master set_carry and " ..
		"adding the item to the stack")
	master_PlayerManager_set_carry(self, ...)
	BLT_CarryStacker:AddCarry(self:get_my_carry_data())
	-- This will be used to prevent the player from picking a new bag
	-- within the next 0.1 sec
	PlayerStandard:block_use_item()
end
