--[[
    This function is called with enabled=false whenever the alarm is 
    raised.

    Note: The function will also be called before starting a heist, to
    set the heist's default whisper_mode
]]
local master_GroupAIStateBase_set_whisper_mode = GroupAIStateBase.set_whisper_mode
function GroupAIStateBase:set_whisper_mode(enabled)
    local logger = BLT_CarryStacker.Log
    logger("Setting whisper mode to " .. tostring(enabled))
    if not enabled
            and Utils:IsInHeist() 
            and BLT_CarryStacker:IsStealthOnly() 
            and #BLT_CarryStacker.stack > 0 then
        logger("The mod is configured as Stealh-Only and the " ..
            "player is carrying bags. Advising the mod wont be disabled " ..
            "until all bags are dropped")
        BLT_CarryStacker.ShowInfoMessage("bltcs_stealth_only_alarm_message")
    end
    master_GroupAIStateBase_set_whisper_mode(self, enabled)
end