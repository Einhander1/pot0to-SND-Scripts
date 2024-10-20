--[[
********************************************************************************
*                           Allied Society Quests                              *
*                               Version 0.0.0                                  *
********************************************************************************

--]]

ToDoList = { "Loporrits", "Omicrons" }

--[[
********************************************************************************
*            Code: Don't touch this unless you know what you're doing          *
********************************************************************************
]]

AlliedSocietiesTable =
{
    arkosodara =
    {
        alliedSocietyName = "Arkosodara",
        questGiver = "Maru",
        x = -68.21,
        y = 39.99,
        z = 323.31,
        zoneId = 957,
        aetheryteName = "Yedlihmad"
    },
    loporrits =
    {
        alliedSocietyName = "Loporrits",
        questGiver = "Managingway",
        x = -201.27,
        y = -49.15,
        z = -273.8,
        zoneId = 959,
        aetheryteName = "Bestways Burrow"
    },
    omicrons =
    {
        alliedSocietyName = "Omicrons",
        questGiver = "Stigma-4",
        x=315.84,
        y=481.99,
        z=152.08,
        zoneId = 960,
        aetheryteName = "Base Omicron"
    }
}

CharacterCondition = {
    dead=2,
    mounted=4,
    inCombat=26,
    casting=27,
    occupiedInEvent=31,
    occupiedInQuestEvent=32,
    occupied=33,
    boundByDuty34=34,
    occupiedMateriaExtractionAndRepair=39,
    betweenAreas=45,
    jumping48=48,
    jumping61=61,
    occupiedSummoningBell=50,
    betweenAreasForDuty=51,
    boundByDuty56=56,
    mounting57=57,
    mounting64=64,
    beingMoved=70,
    flying=77
}

function GetAlliedSocietyTable(alliedSocietyName)
    for _, alliedSociety in pairs(AlliedSocietiesTable) do
        if alliedSociety.alliedSocietyName == alliedSocietyName then
            return alliedSociety
        end
    end
end

function GetAcceptedAlliedSocietyQuests(alliedSocietyName)
    local accepted = {}
    local allAcceptedQuests = GetAcceptedQuests()
    for i=1, allAcceptedQuests.Count do
        if GetQuestAlliedSociety(allAcceptedQuests[i]) == alliedSocietyName then
            table.insert(accepted, allAcceptedQuests[i])
        end
    end
    return accepted
end

function CheckAllowances()
    if not IsAddonVisible("ContentsInfo") then
        yield("/timers")
        yield ("/wait 1")
    end

    for i = 1, 15 do
        local timerName = GetNodeText("ContentsInfo", 8, i, 5)
        if timerName == "Next Allied Society Daily Quest Allowance" then
            return tonumber(GetNodeText("ContentsInfo", 8, i, 4):match("%d+$"))
        end
    end
    return 0
end

function TeleportTo(aetheryteName)
    yield("/tp "..aetheryteName)
    yield("/wait 1") -- wait for casting to begin
    while GetCharacterCondition(CharacterCondition.casting) do
        LogInfo("[FATE] Casting teleport...")
        yield("/wait 1")
    end
    yield("/wait 1") -- wait for that microsecond in between the cast finishing and the transition beginning
    while GetCharacterCondition(CharacterCondition.betweenAreas) do
        LogInfo("[FATE] Teleporting...")
        yield("/wait 1")
    end
    yield("/wait 1")
end

yield("/at y")
for _, alliedSocietyName in ipairs(ToDoList) do
    local alliedSocietyTable = GetAlliedSocietyTable(alliedSocietyName)
    if alliedSocietyTable ~= nil then
        if not IsInZone(alliedSocietyTable.zoneId) then
            TeleportTo(alliedSocietyTable.aetheryteName)
        end
    
        if not GetCharacterCondition(4) then
            yield('/gaction "mount roulette"')
        end
        repeat
            yield("/wait 1")
        until GetCharacterCondition(4)
        PathfindAndMoveTo(alliedSocietyTable.x, alliedSocietyTable.y, alliedSocietyTable.z, true)
        repeat
            yield("/wait 1")
        until not PathIsRunning() and not PathfindInProgress()
    
        -- accept 3 allocations
        local quests = {}
        for i=1,3 do
            yield("/echo accepting quest "..i)
            yield("/target "..alliedSocietyTable.questGiver)
            yield("/interact")

            repeat
                yield("/wait 1")
            until IsAddonVisible("SelectIconString")

            local questName = GetNodeText("SelectIconString", 2, 1, 4)
            if string.sub(questName, 1, 3) == "" then
                local questId = GetQuestIDByName(questName)
                if questId ~= nil then
                    table.insert(quests, questId)
                    yield("/echo inserted quest #"..questId)
                end

                repeat
                    yield("/wait 1")
                until IsAddonVisible("SelectIconString")
                yield("/callback SelectIconString true 0")

                repeat
                    yield("/wait 1")
                until not IsPlayerOccupied()
            end
        end

        yield("/qst start")
        repeat
            yield("/wait 10")
        until #GetAcceptedAlliedSocietyQuests(alliedSocietyName) == 0
    end
end
