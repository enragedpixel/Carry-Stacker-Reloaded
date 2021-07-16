local btn_use_item_held = false
local block_use_item_from
local master_PlayerStandard_check_use_item = PlayerStandard._check_use_item

local master_PlayerStandard_update = PlayerStandard.update
function PlayerStandard:update(t, dt)
	local logger = BLT_CarryStacker.RLog
	logger("Request to update the player")
	master_PlayerStandard_update(self, t, dt)

	if self ~= nil then
		if self._get_input ~= nil then
			logger("Storing whether the player is holding " ..
				"the use button")
			btn_use_item_held = self._controller:get_input_bool("use_item")
		end
	end
end

function PlayerStandard:_check_use_item(t, input)
	local logger = BLT_CarryStacker.RLog
	logger("Request to check whether the player can use an item")
	if block_use_item_from ~= nil then
		if TimerManager:game():time() - block_use_item_from < 0.1 then
			logger("The last time the player used an item " ..
				"was less than 0.1 sec ago. Returning false")
			return false
		end
	end
	logger("Using master _check_use_item")
	local result = master_PlayerStandard_check_use_item(self, t, input)
	logger("The player can use item: " .. tostring(result))
	return result
end

function PlayerStandard:use_item_held()
	local logger = BLT_CarryStacker.Log
	logger("Request to get whether the player is holding the " ..
		"use button. The answer is: " .. tostring(btn_use_item_held))
	return btn_use_item_held
end

function PlayerStandard:block_use_item()
	local logger = BLT_CarryStacker.Log
	logger("Request to update the time from which the " ..
		"player has to wait to use another item")
	block_use_item_from = TimerManager:game():time()
end
