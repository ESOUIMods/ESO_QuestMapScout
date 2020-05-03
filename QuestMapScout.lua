--[[

Quest Map Scout
by CaptainBlagbird
https://github.com/CaptainBlagbird

--]]

-- Addon info
local AddonName = "QuestMapScout"
-- Local variables
local questGiverName
local preQuest
local reward
local lastZone
-- Init saved variables table
if QM_Scout == nil then QM_Scout = {startTime=GetTimeStamp()} end
local GPS = LibGPS2
local LMP = LibMapPins

-- Check if zone is base zone
local function IsBaseZone(zoneAndSubzone)
    return (zoneAndSubzone:match("(.*)/") == zoneAndSubzone:match("/(.*)[%._]base"))
end

-- Check if both subzones are in the same zone
local function IsSameZone(zoneAndSubzone1, zoneAndSubzone2)
    return (zoneAndSubzone1:match("(.*)/") == zoneAndSubzone2:match("(.*)/"))
end

-- Event handler function for EVENT_QUEST_ADDED
local function OnQuestAdded(eventCode, journalIndex, questName, objectiveName)
    -- Add quest to saved variables table in correct zone element
    if QM_Scout.quests == nil then QM_Scout.quests = {} end
    local zone = LMP:GetZoneAndSubzone(true)
    if QM_Scout.quests[zone] == nil then QM_Scout.quests[zone] = {} end
    local normalizedX, normalizedY = GetMapPlayerPosition("player")
    local gpsx, gpsy, zoneMapIndex = GPS:LocalToGlobal(normalizedX, normalizedY)
    local quest = {
            ["name"]      = questName,
            ["x"]         = normalizedX,
            ["y"]         = normalizedY,
            ["gpsx"]         = gpsx,
            ["gpsy"]         = gpsy,
            ["giver"]     = questGiverName,
            ["preQuest"]  = preQuest,  -- Save it here (instead of in questInfo) because the quest (not preQuest) only has a name and not unique ID
            ["otherInfo"] = {
                    ["time"]      = GetTimeStamp(),
                    ["api"]       = GetAPIVersion(),
                    ["lang"]      = GetCVar("language.2")
                },
        }
    if not string.find(string.lower(questGiverName), "crafting writ") then
        table.insert(QM_Scout.quests[zone], quest)
    end
end

-- Event handler function for EVENT_CHATTER_END
local function OnChatterEnd(eventCode)
    preQuest = nil
    reward = nil
    -- Stop listening for the quest added event because it would only be for shared quests
    EVENT_MANAGER:UnregisterForEvent(AddonName, EVENT_QUEST_ADDED)
    EVENT_MANAGER:UnregisterForEvent(AddonName, EVENT_CHATTER_END)
end

-- Event handler function for EVENT_QUEST_OFFERED
local function OnQuestOffered(eventCode)
    -- Get the name of the NPC or intractable object
    -- (This could also be done in OnQuestAdded directly, but it's saver here because we are sure the dialogue is open)
    questGiverName = GetUnitName("interact")
    -- Now that the quest has ben offered we can start listening for the quest added event
    EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_ADDED, OnQuestAdded)
    EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_CHATTER_END, OnChatterEnd)
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_OFFERED, OnQuestOffered)

-- Event handler function for EVENT_QUEST_COMPLETE_DIALOG
local function OnQuestCompleteDialog(eventCode, journalIndex)
    local numRewards = GetJournalQuestNumRewards(journalIndex)
    if numRewards <= 0 then return end
    reward = {}
    for i=1, numRewards do
        local rewardType = GetJournalQuestRewardInfo(journalIndex, i)
        table.insert(reward, rewardType)
    end
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_COMPLETE_DIALOG, OnQuestCompleteDialog)

-- Event handler function for EVENT_QUEST_REMOVED
local function OnQuestRemoved(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questID)
    if not isCompleted then return end
    -- Remember prerequisite quest id
    preQuest = questID
    -- Save quest repeat and reward type
    if not QM_Scout.questInfo then QM_Scout.questInfo = {} end
    if not QM_Scout.questInfo[questID] then QM_Scout.questInfo[questID] = {} end
    QM_Scout.questInfo[questID].repeatType = GetJournalQuestRepeatType(journalIndex)
    QM_Scout.questInfo[questID].rewardTypes = reward
    reward = nil
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_REMOVED, OnQuestRemoved)

-- Event handler function for EVENT_PLAYER_DEACTIVATED
local function OnPlayerDeactivated(eventCode)
    lastZone = LMP:GetZoneAndSubzone(true)
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)

-- Event handler function for EVENT_PLAYER_ACTIVATED
local function OnPlayerActivated(eventCode)
    local zone = LMP:GetZoneAndSubzone(true)
    -- Check if leaving subzone (entering base zone)
    if lastZone and zone ~= lastZone and IsBaseZone(zone) and IsSameZone(zone, lastZone) then
        if QM_Scout.subZones == nil then QM_Scout.subZones = {} end
        if QM_Scout.subZones[zone] == nil then QM_Scout.subZones[zone] = {} end
        if QM_Scout.subZones[zone][lastZone] == nil then
            -- Save entrance position
            local x, y = GetMapPlayerPosition("player")
            gpsx, gpsy, zoneMapIndex = GPS:LocalToGlobal(x, y)
            QM_Scout.subZones[zone][lastZone] = {
                    -- previously this was reversed ?? GetMapPlayerPosition
                    -- won't reverse that ??
                    -- ["y"] = x,
                    -- ["x"] = y,
                    ["x"] = x,
                    ["y"] = y,
                    ["gpsx"] = x,
                    ["gpsy"] = y,
                }
        end
    end
    lastZone = zone
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)