--[[

Quest Map Scout
by CaptainBlagbird
https://github.com/CaptainBlagbird

--]]

-- Addon info
local AddonName = "QuestMapScout"
-- Local variables
local questGiverName
local reward
local lastZone
-- Init saved variables table
if QM_Scout == nil then QM_Scout = {startTime=GetTimeStamp()} end
local GPS = LibGPS2
local LMP = LibMapPins
local quest_shared

-- Check if zone is base zone
local function IsBaseZone(zoneAndSubzone)
    return (zoneAndSubzone:match("(.*)/") == zoneAndSubzone:match("/(.*)[%._]base"))
end

-- Check if both subzones are in the same zone
local function IsSameZone(zoneAndSubzone1, zoneAndSubzone2)
    return (zoneAndSubzone1:match("(.*)/") == zoneAndSubzone2:match("(.*)/"))
end

function GetQuestList(zone)
    if type(zone) == "string" and QM_Scout.quests[zone] ~= nil then
        return QM_Scout.quests[zone]
    else
        return {}
    end
end

-- Event handler function for EVENT_QUEST_ADDED
local function OnQuestAdded(eventCode, journalIndex, questName, objectiveName)
    if quest_shared then
        quest_shared = false
        return
    end
    -- -1 for these means it is undefined since 0 is a valid value
    local quest_type = -1
    local repeat_type = -1
    local quest_id = -1
    -- -1 means it has not been completed. Once complete set it to the time stamp
    -- I am considering using this to see if I can calculate order for Zone quests

    -- Add quest to saved variables table in correct zone element
    if QM_Scout.quests == nil then QM_Scout.quests = {} end
    local zone = LMP:GetZoneAndSubzone(true)
    if QM_Scout.quests[zone] == nil then QM_Scout.quests[zone] = {} end
    local normalizedX, normalizedY = GetMapPlayerPosition("player")
    local gpsx, gpsy, zoneMapIndex = GPS:LocalToGlobal(normalizedX, normalizedY)
    local measurement = GPS:GetCurrentMapMeasurements()
    if journalIndex then
        quest_type = GetJournalQuestType(journalIndex)
        repeat_type = GetJournalQuestRepeatType(journalIndex)
    end
    local quest = {
        ["quest_type"]  = quest_type,
        ["repeat_type"] = repeat_type,
        ["name"]        = questName,
        ["x"]           = normalizedX,
        ["y"]           = normalizedY,
        ["gpsx"]        = gpsx,
        ["gpsy"]        = gpsy,
        ["giver"]       = questGiverName,
        ["questID"]     = quest_id, -- assign this and get the ID when the quest is removed
        ["otherInfo"] = {
            ["api"]             = GetAPIVersion(),
            ["lang"]            = GetCVar("language.2"),
            ["measurement"]     = measurement,
        },
    }

    if not string.find(string.lower(questGiverName), "crafting writ") then
        if QuestMap then
            local quest_not_found = true
            local QuestMap_zonelist = QuestMap:GetQuestList(zone)
            for num_entry, quest_from_table in pairs(QuestMap_zonelist) do
                local quest_map_questname = QuestMap:GetQuestName(quest_from_table.id)
                if quest_map_questname == questName then
                    quest_not_found = false
                end
            end
            local QuestScout_zonelist = GetQuestList(zone)
            for num_entry, quest_from_table in pairs(QuestScout_zonelist) do
                if quest_from_table.name == questName then
                    quest_not_found = false
                end
            end
            if quest_not_found then
                table.insert(QM_Scout.quests[zone], quest)
            end
        else
            table.insert(QM_Scout.quests[zone], quest)
        end
    end
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_ADDED, OnQuestAdded) -- Verified

-- Event handler function for EVENT_CHATTER_END
local function OnChatterEnd(eventCode)
    reward = nil
    -- Stop listening for the quest added event because it would only be for shared quests
    -- Shar I added if EVENT_QUEST_SHARED to OnQuestAdded UnregisterForEvent EVENT_QUEST_ADDED
    -- EVENT_MANAGER:UnregisterForEvent(AddonName, EVENT_QUEST_ADDED)
    EVENT_MANAGER:UnregisterForEvent(AddonName, EVENT_CHATTER_END) -- Verified
end

local function OnQuestSharred(eventCode, questID)
    quest_shared = true
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_SHARED, OnQuestSharred) -- Verified

-- Event handler function for EVENT_QUEST_OFFERED
local function OnQuestOffered(eventCode)
    -- Get the name of the NPC or intractable object
    -- (This could also be done in OnQuestAdded directly, but it's saver here because we are sure the dialogue is open)
    questGiverName = GetUnitName("interact")
    -- Now that the quest has ben offered we can start listening for the quest added event
    -- Shar I added if EVENT_QUEST_SHARED to OnQuestAdded UnregisterForEvent EVENT_QUEST_ADDED
    -- EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_ADDED, OnQuestAdded)
    EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_CHATTER_END, OnChatterEnd) -- Verified
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_OFFERED, OnQuestOffered) -- Verified

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
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_COMPLETE_DIALOG, OnQuestCompleteDialog) -- Verified

-- Event handler function for EVENT_QUEST_REMOVED
local function OnQuestRemoved(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questID)
    local quest_to_update = {}

    for zone, zone_quests in pairs(QM_Scout["quests"]) do
        for num_entry, quest_from_table in pairs(zone_quests) do
            if quest_from_table.name == questName then
                quest_to_update = quest_from_table
                break
            end
        end
    end

    if not isCompleted  then
        return
    end
    if quest_to_update == nil then
        return
    end

    if quest_to_update.questID == -1 then
        quest_to_update.questID = questID
    end

    if isCompleted then
        if not QM_Scout.questInfo then QM_Scout.questInfo = {} end
        if not QM_Scout.questInfo[questID] then QM_Scout.questInfo[questID] = {} end
        QM_Scout.questInfo[questID].repeatType = GetJournalQuestRepeatType(journalIndex)
        QM_Scout.questInfo[questID].rewardTypes = reward
        reward = nil
    end
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_QUEST_REMOVED, OnQuestRemoved) -- Verified

-- Event handler function for EVENT_PLAYER_DEACTIVATED
local function OnPlayerDeactivated(eventCode)
    lastZone = LMP:GetZoneAndSubzone(true)
end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated) -- Verified

function show_quests()
    for zone, zone_quests in pairs(QM_Scout.quests) do
        d("zone: "..zone)
        for num_entry, quest_from_table in pairs(zone_quests) do
            quest_to_update = quest_from_table
            d("Quest Name: "..quest_to_update.name)
        end
    end
end

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
            local gpsx, gpsy, gpsm = GPS:LocalToGlobal(x, y)
            local measurement = GPS:GetCurrentMapMeasurements()
            QM_Scout.subZones[zone][lastZone] = {
                -- previously this was reversed ?? GetMapPlayerPosition
                -- won't reverse that ??
                -- ["y"] = x,
                -- ["x"] = y,
                ["x"] = x,
                ["y"] = y,
                ["gpsx"] = gpsx,
                ["gpsy"] = gpsy,
                ["measurement"] = measurement,
            }
        end
    end
    lastZone = zone

    SLASH_COMMANDS["/qmslist"] = show_quests

end
EVENT_MANAGER:RegisterForEvent(AddonName, EVENT_PLAYER_ACTIVATED, OnPlayerActivated) -- Verified
