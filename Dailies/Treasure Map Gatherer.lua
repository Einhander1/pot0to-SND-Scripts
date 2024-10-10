--[[

****************************************
*            Map Gathering             * 
****************************************

Created by: pot0to (https://ko-fi.com/pot0to)
State Machine Diagram: https://github.com/pot0to/pot0to-SND-Scripts/blob/main/FateFarmingStateMachine.drawio.png

***********
* Version *
*  0.0.0  *
***********

*********************
*  Required Plugins *
*********************
        
]]

--#region Settings

--[[
*************
*  Settings *
*************
]]

MapName = "Timeworn Br'aaxskin Map"

Multimode = true
Characters =
{
	{ characterName="John Doe", worldName="Behemoth" },
	{ characterName="Jane Doe", worldName="Excalibur" }
}

--#endregion Settings

--[[
**************************************************************
*  Code: Don't touch this unless you know what you're doing  *
**************************************************************
]]

TimewornMapIds = {
    {itemId=43557, itemName="Timeworn Br'aaxskin Map"},
    {itemId=43556, itemName="Timeworn Loboskin Map"}
}

function GetMapInfo()
    for _, mapInfo in ipairs(TimewornMapIds) do
        yield("/echo "..mapInfo.itemName)
        if mapInfo.itemName == MapName then
            return mapInfo
        end
    end
end

function Gather()
    yield("/gbr auto on")
    yield("/wait 10")
end

function SwapCharacters()
	for i=1, #Characters do
		if Characters[i].visited == nil then
			Characters[i].visited = true
			local nextCharacterName = Characters[i].characterName.."@"..Characters[i].worldName
			if GetCharacterName(true) ~= nextCharacterName then
				yield("/ays relog "..nextCharacterName)
				yield("/wait 3")
				yield("/waitaddon _ActionBar <maxwait.600><wait.5>")
			end
			return
		end
	end
	Multimode = false
end

function Main()

    if GetItemCount(MapInfo.itemId) > 0 then
        yield("/gbr auto off")
        if IsPlayerOccupied() then
            return
        end

        SwapCharacters()
    else
        Gather()
    end
end

MapInfo = GetMapInfo()
repeat
	Main()
until not Multimode