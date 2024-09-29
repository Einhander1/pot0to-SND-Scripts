--[[

****************************************
*            Fate Farming              * 
****************************************

Created by: pot0to (https://ko-fi.com/pot0to)
State Machine Diagram: https://github.com/pot0to/pot0to-SND-Scripts/blob/main/FateFarmingStateMachine.drawio.png

***********
* Version *
*  2.12.5 *
***********
        
    -> 2.12.5   Fixed get distance to point
                Fixed teleport penalty
                Fix arrival logic that caused you to look for an npc, even if someone else had already
                    started the fate, fixed check for finding closest aetheryte, added option to set RSR
                    auto type, updated ClassForBossFates to work with lowercase, fixed dismount options
                    for middle of fate and interacting with npc
                Updated logic to only target mobs that are part of CurrentFate, updated random
                    adjust coordinates to bring you within 10 distance of center of fate, to make
                    it easier to find targets but also provide some variation in where you land,
                    in case others in the area are using the same script
                Changed pathing to fate: upon approaching fate, bot will target either the npc
                    or a random fate mob and switch to pathing towards new target. Fixed wait for
                    continuation fates, fixed pathfinding while flying
                Added ability to summon chocobo without Pandora, updated to manually fly back
                    to closest aetheryte if no eligible fates and not changing instances,
                    added random waits during mounting up and teleporting to make it more humanlike
                Changed mounted -> ready because new mount after no eligible fates breaks CurrentFate
                    convention, fixed class parsing bug
                Fixed flying to (0,0,0) issue, added option to switch to a different class for boss
                    fates, changed logic to detect boss fates and cleaned up fate lists
                Cleaned up settings section for clarity, added mount when no eligible fates left,
                    to avoid running the chocobo timer
                Fixed pathing closer to npcs for npc fates, reduced random adjust distance to 20
                Added Feathery Dustup and The Pama-yawa Dilemma to Kozama'uka boss fates list
                Fixed changing instances
                Temporarily removed single target forlorn
                Added a lot of debug statements
                Waits for LifestreamIsBusy() to complete before attempting to resume farming
                    and checks if you're waiting for a collections fate after instead of before
    -> 2.0.0    State system

*********************
*  Required Plugins *
*********************

Plugins that are needed for it to work:

    -> Something Need Doing [Expanded Edition] : (Main Plugin for everything to work)   https://puni.sh/api/repository/croizat   
    -> VNavmesh :   (for Pathing/Moving)    https://puni.sh/api/repository/veyn       
    -> Pandora :    (for Fate targeting and auto sync [ChocoboS])   https://love.puni.sh/ment.json             
    -> RotationSolver Reborn :  (for Attacking enemys)  https://raw.githubusercontent.com/FFXIV-CombatReborn/CombatRebornRepo/main/pluginmaster.json       
        -> Target -> activate "Select only Fate targets in Fate" and "Target Fate priority"
        -> Target -> "Engage settings" set to "All targets that are in range for any abilities (Tanks/Autoduty)" regardless of whether you are tank
    -> TextAdvance: (for interacting with Fate NPCs)
    -> Teleporter :  (for Teleporting to aetherytes [teleport][Exchange][Retainers])
    -> Lifestream :  (for changing Instances [ChangeInstance][Exchange]) https://raw.githubusercontent.com/NightmareXIV/MyDalamudPlugins/main/pluginmaster.json

*********************
*  Optional Plugins *
*********************

This Plugins are Optional and not needed unless you have it enabled in the settings:

    -> AutoRetainer : (for Retainers [Retainers])   https://love.puni.sh/ment.json
    -> Deliveroo : (for gc turn ins [TurnIn])   https://plugins.carvel.li/
    -> Bossmod/BossModReborn: (for AI dodging)  https://puni.sh/api/repository/veyn
                                                https://raw.githubusercontent.com/FFXIV-CombatReborn/CombatRebornRepo/main/pluginmaster.json
    -> ChatCoordinates : (for setting a flag on the next Fate) available via base /xlplugins

--------------------------------------------------------------------------------------------------------------------------------------------------------------
]]

--#region Settings

--Pre Fate Settings
Food = ""                       --Leave "" Blank if you don't want to use any food. If its HQ include <hq> next to the name "Baked Eggplant <hq>"
ShouldSummonChocobo = true            --Summon chocobo?
MountToUse = "mount roulette"   --The mount you'd like to use when flying between fates

--Fate Combat Settings
CompletionToIgnoreFate = 80         --If the fate has more than this much progress already, skip it
MinTimeLeftToIgnoreFate = 3*60      --If the fate has less than this many seconds left on the timer, skip it
CompletionToJoinBossFate = 0        --If the boss fate has less than this much progress, skip it (used to avoid soloing bosses)
    ClassForBossFates = ""          --If you want to use a different class for boss fates, set this to the 3 letter abbreviation for the class ex: "PLD"
JoinCollectionsFates = true         --Set to false if you never want to do collections fates

                                    --"Pandora"/"RSR". Use RSR if the Pandora plugin if experiencing lag issues.
TargetingSystem = "Pandora"         --Using also makes you pull more mobs (good or bad depending on whether you're a tank).
    RSRAutoType = "LowHP"               --Only used if TargetingSystem = "RSR"
                                        --Recommended for all classes using RSR targeting: List > Map Specific Settings > "Prio Target", add Forlorn Maiden and The Forlorn
                                        --Additionally recommended for tanks: HighHP, Target > Configuration > gapcloser distance = 20y
                                    
UseBM = true                        --if you want to use the BossMod dodge/follow mode
    BMorBMR = "BMR"
    MeleeDist = 2.5                     --distance for BMRAI melee. Melee attacks (auto attacks) max distance is 2.59y, 2.60 is "target out of range"
    RangedDist = 20                     --distance for BMRAI ranged. Ranged attacks and spells max distance to be usable is 25.49y, 25.5 is "target out of range"=


--Post Fate Settings
EnableChangeInstance = true                     --should it Change Instance when there is no Fate (only works on DT fates)
    WaitIfBonusBuff = true                          --Don't change instances if you have the Twist of Fate bonus buff
ShouldExchangeBicolorVouchers = true            --Should it exchange Bicolor Gemstone Vouchers?
    VoucherType = "Bicolor Gemstone Voucher"        -- Old Sharlayan for "Bicolor Gemstone Voucher" and Solution Nine for "Turali Bicolor Gemstone Voucher"
SelfRepair = false                              --if false, will go to Limsa mender
    RepairAmount = 20                              --the amount it needs to drop before Repairing (set it to 0 if you don't want it to repair)
ExtractMateria = true                           --should it Extract Materia
Retainers = true                                --should it do Retainers
GrandCompanyTurnIn = false                      --should it to Turn ins at the GC (requires Deliveroo)
    slots = 5                                       --how much inventory space before turning in

--Change this value for how much echos u want in chat 
--0 no echos
--1 echo how many bicolor gems you have after every fate
--2 echo how many bicolor gems you have after every fate and the next fate you're moving to
Echo = 2

--#endregion Settings

------------------------------------------------------------------------------------------------------------------------------------------------------

--#region Plugin Checks and Setting Init

--Required Plugin Warning
if not HasPlugin("vnavmesh") then
    yield("/echo [FATE] Please Install vnavmesh")
end

if TargetingSystem == "Pandora" then
    if HasPlugin("PandorasBox") then
        if ShouldSummonChocobo then
            PandoraSetFeatureState("Auto-Summon Chocobo", true)
            PandoraSetFeatureConfigState("Auto-Summon Chocobo", "UseInCombat", true)
        else
            PandoraSetFeatureState("Auto-Summon Chocobo", false)
            PandoraSetFeatureConfigState("Auto-Summon Chocobo", "UseInCombat", false)
        end
        
        --Fate settings
        PandoraSetFeatureState("Auto-Sync FATEs", false)
        PandoraSetFeatureState("FATE Targeting Mode", false)
        PandoraSetFeatureState("Action Combat Targeting", false)
    else
        TargetingSystem = "RSR"
        yield("/echo [FATE] Please install Pandora's box or turn off the UsePandora setting to silence this warning message.")
    end
end

if UseBM then
    if HasPlugin("BossModReborn") then
        BMorBMR = "BMR"
    elseif HasPlugin("BossMod") then
        BMorBMR = "BM"
    else
        UseBM = false
        yield("/echo [FATE] Neither BossMod nor BossModReborn have been detected. " +
            "Please set useBM to false or install one of these plugins to silence this warning.")
    end
end

if HasPlugin("RotationSolver") then
    if TargetingSystem ~= "Pandora" then
        yield("/echo changing rsr")
        yield("/rotation Settings TargetingTypes removeall")
        yield("/rotation Settings TargetingTypes add "..RSRAutoType)
    end
else
    yield("/echo [FATE] Please Install Rotation Solver Reborn")
end
if not HasPlugin("TextAdvance") then
    yield("/echo [FATE] Please Install TextAdvance")
end

--Optional Plugin Warning
if EnableChangeInstance == true  then
    if HasPlugin("Lifestream") == false then
        yield("/echo [FATE] Please Install Lifestream or Disable ChangeInstance in the settings")
    end
end
if Retainers then
    if not HasPlugin("AutoRetainer") then
        yield("/echo [FATE] Please Install AutoRetainer")
    end
    if GrandCompanyTurnIn then
        if not HasPlugin("Deliveroo") then
            yield("/echo [FATE] Please Install Deliveroo")
        end
    end
end
if ExtractMateria == true then
    if HasPlugin("YesAlready") == false then
        yield("/echo [FATE] Please Install YesAlready")
    end 
end   

if not HasPlugin("ChatCoordinates") then
    yield("/echo [FATE] ChatCoordinates is not installed. Map will not show flag when moving to next Fate.")
end

yield("/at y")

--snd property
function setSNDProperty(propertyName, value)
    local currentValue = GetSNDProperty(propertyName)
    if currentValue ~= value then
        SetSNDProperty(propertyName, tostring(value))
        LogInfo("[SetSNDProperty] " .. propertyName .. " set to " .. tostring(value))
    end
end

setSNDProperty("UseItemStructsVersion", true)
setSNDProperty("UseSNDTargeting", true)
setSNDProperty("StopMacroIfTargetNotFound", false)
setSNDProperty("StopMacroIfCantUseItem", false)
setSNDProperty("StopMacroIfItemNotFound", false)
setSNDProperty("StopMacroIfAddonNotFound", false)
setSNDProperty("StopMacroIfAddonNotVisible", false)

--#endregion Plugin Checks and Setting Init

--#region Data

CharacterCondition = {
    dead=2,
    mounted=4,
    inCombat=26,
    casting=27,
    occupied31=31,
    occupiedShopkeeper=32,
    occupied=33,
    occupiedMateriaExtraction=39,
    betweenAreas=45,
    jumping48=48,
    jumping61=61,
    occupiedSummoningBell=50,
    mounting57=57,
    mounting64=64,
    beingmoved70=70,
    beingmoved75=75,
    flying=77
}

ClassList =
{
    pld = { classId=19, className="Paladin", isMelee=true, isTank=true },
    mnk = { classId=20, className="Monk", isMelee=true, isTank=false },
    war = { classId=21, className="Warrior", isMelee=true, isTank=true },
    drg = { classId=22, className="Dragoon", isMelee=true, isTank=false },
    brd = { classId=23, className="Bard", isMelee=false, isTank=false },
    whm = { classId=24, className="White Mage", isMelee=false, isTank=false },
    blm = { classId=25, className="Black Mage", isMelee=false, isTank=false },
    smn = { classId=27, className="Summoner", isMelee=false, isTank=false },
    sch = { classId=28, className="Scholar", isMelee=false, isTank=false },
    nin = { classId=30, className="Ninja", isMelee=true, isTank=false },
    mch = { classId=31, className="Machinist", isMelee=false, isTank=false},
    drk = { classId=32, className="Dark Knight", isMelee=true, isTank=true },
    ast = { classId=33, className="Astrologian", isMelee=false, isTank=false },
    sam = { classId=34, className="Samurai", isMelee=true, isTank=false },
    rdm = { classId=35, className="Red Mage", isMelee=false, isTank=false },
    blu = { classId=36, className="Blue Mage", isMelee=false, isTank=false },
    gnb = { classId=37, className="Gunbreaker", isMelee=true, isTank=true },
    dnc = { classId=38, className="Dancer", isMelee=false, isTank=false },
    rpr = { classId=39, className="Reaper", isMelee=true, isTank=false },
    sge = { classId=40, className="Sage", isMelee=false, isTank=false },
    vpr = { classId=41, className="Viper", isMelee=true, isTank=false },
    pct = { classId=42, className="Pictomancer", isMelee=false, isTank=false }
}

FatesData = {
    {
        zoneName = "Coerthas Central Highlands",
        zoneId = 155,
        aetheryteList = {
            { aetheryteName="Camp Dragonhead", x=223.98718, y=315.7854, z=-234.85168 }
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Coerthas Western Highlands",
        zoneId = 397,
        aetheryteList = {
            { aetheryteName="Falcon's Nest", x=474.87585, y=217.94458, z=708.5221 }
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Mor Dhona",
        zoneId = 156,
        aetheryteList = {
            { aetheryteName="Revenant's Toll", x=40.024292, y=24.002441, z=-668.0247 }
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "The Sea of Clouds",
        zoneId = 401,
        aetheryteList = {
            { aetheryteName="Camp Cloudtop", x=-615.7473, y=-118.36426, z=546.5934 },
            { aetheryteName="Ok' Zundu", x=-613.1533, y=-49.485046, z=-415.03015 }
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Azys Lla",
        zoneId = 402,
        aetheryteList = {
            { aetheryteName="Helix", x=-722.8046, y=-182.29956, z=-593.40814 }
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "The Dravanian Forelands",
        zoneId = 398,
        aetheryteList = {
            { aetheryteName="Tailfeather", x=532.6771, y=-48.722107, z=30.166992 },
            { aetheryteName="Anyx Trine", x=-304.12756, y=-16.70868, z=32.059082 }
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "The Dravanian Hinterlands",
        zoneId=399,
        tpZoneId = 478,
        aetheryteList = {
            { aetheryteName="Idyllshire", x=71.94617, y=211.26111, z=-18.905945 }
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "The Churning Mists",
        zoneId=400,
        aetheryteList = {
            { aetheryteName="Moghome", x=259.20496, y=-37.70508, z=596.85657 },
            { aetheryteName="Zenith", x=-584.9546, y=52.84192, z=313.43542 },
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Lakeland",
        zoneId = 813,
        aetheryteList = {
            { aetheryteName="The Ostall Imperative", x=-735, y=53, z=-230 },
            { aetheryteName="Fort Jobb", x=753, y=24, z=-28 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="Pick-up Sticks", npcName="Crystarium Botanist" }
            },
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Kholusia",
        zoneId = 814,
        aetheryteList = {
            { aetheryteName="Stilltide", x=668, y=29, z=289 },
            { aetheryteName="Wright", x=-244, y=20, z=385 },
            { aetheryteName="Tomra", x=-426, y=419, z=-623 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="Ironbeard Builders - Rebuilt", npcName="Tholl Engineer" }
            },
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Amh Araeng",
        zoneId = 815,
        aetheryteList = {
            { aetheryteName="Mord Souq", x=246, y=12, z=-220 },
            { aetheryteName="Twine", x=-511, y=47, z=-212 },
            { aetheryteName="The Inn at Journey's Head", x=399, y=-24, z=307 },
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {
                "Tolba No. 1", -- pathing is really bad to enemies
            }
        }
    },
    {
        zoneName = "Il Mheg",
        zoneId = 816,
        aetheryteList = {
            { aetheryteName="Lydha Lran", x=-344, y=48, z=512 },
            { aetheryteName="Wolekdorf", x=380, y=87, z=-687 },
            { aetheryteName="Pla Enni", x=-72, y=103, z=-857 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="Twice Upon a Time", npcName="Nectar-seeking Pixie" }
            },
            otherNpcFates= {
                { fateName="Once Upon a Time", npcName="Nectar-seeking Pixie" },
            },
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "The Rak'tika Greatwood",
        zoneId = 817,
        aetheryteList = {
            { aetheryteName="Slitherbough", x=-103, y=-19, z=297 },
            { aetheryteName="Fanow", x=382, y=21, z=-194 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="Picking up the Pieces", npcName="Night's Blessed Missionary" },
                { fateName="Pluck of the Draw", npcName="Myalna Bowsing" },
                { fateName="Monkeying Around", npcName="Fanow Warder" }
            },
            otherNpcFates= {
                { fateName="Queen of the Harpies", npcName="Fanow Huntress" },
                { fateName="Shot Through the Hart", npcName="Qilmet Redspear" },
            },
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "The Tempest",
        zoneId = 818,
        aetheryteList = {
            { aetheryteName="The Ondo Cups", x=561, y=352, z=-199 },
            { aetheryteName="The Macarenses Angle", x=-141, y=-280, z=218 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="Low Coral Fiber", npcName="Teushs Ooan" },
                { fateName="Pearls Apart", npcName="Ondo Spearfisher" }
            },
            otherNpcFates= {
                { fateName="Where has the Dagon", npcName="Teushs Ooan" },
                { fateName="Ondo of Blood", npcName="Teushs Ooan" },
                { fateName="Lookin' Back on the Track", npcName="Teushs Ooan" },
            },
            fatesWithContinuations = {},
            blacklistedFates= {
                "Coral Support", -- escort fate
                "The Seashells He Sells", -- escort fate
            }
        }
    },
    {
        zoneName = "Labyrinthos",
        zoneId = 956,
        aetheryteList = {
            { aetheryteName="The Archeion", x=443, y=170, z=-476 },
            { aetheryteName="Sharlayan Hamlet", x=8, y=-27, z=-46 },
            { aetheryteName="Aporia", x=-729, y=-27, z=302 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="Sheaves on the Wind", npcName="Vexed Researcher" },
                { fateName="Moisture Farming", npcName="Well-moisturized Researcher" }
            },
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Thavnair",
        zoneId = 957,
        aetheryteList = {
            { aetheryteName="Yedlihmad", x=193, y=6, z=629 },
            { aetheryteName="The Great Work", x=-527, y=4, z=36 },
            { aetheryteName="Palaka's Stand", x=405, y=5, z=-244 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="Full Petal ALchemist: Perilous Pickings", npcName="???" }
            },
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Garlemald",
        zoneId = 958,
        aetheryteList = {
            { aetheryteName="Camp Broken Glass", x=-408, y=24, z=479 },
            { aetheryteName="Tertium", x=518, y=-35, z=-178 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="Parts Unknown", npcName="Displaced Engineer" }
            },
            otherNpcFates= {
                { fateName="Artificial Malevolence: 15 Minutes to Comply", npcName="Keltlona" },
                { fateName="Artificial Malevolence: The Drone Army", npcName="Ebrelnaux" },
                { fateName="Artificial Malevolence: Unmanned Aerial Villains", npcName="Keltlona" },
                { fateName="Amazing Crates", npcName="Hardy Refugee" }
            },
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Mare Lamentorum",
        zoneId = 959,
        aetheryteList = {
            --{ aetheryteName="Sinus Lacrimarum", x=-566, y=134, z=650 },
            { aetheryteName="Sinus Lacrimarum",  x=-0.10, y=116.80, z=311.89938 },
            { aetheryteName="Bestways Burrow", x=0, y=-128, z=-512 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="What a Thrill", npcName="Thrillingway" }
            },
            otherNpcFates= {
                { fateName="Lepus Lamentorum: Dynamite Disaster", npcName="Warringway" },
                { fateName="Lepus Lamentorum: Cleaner Catastrophe", npcName="Fallingway" },
            },
            fatesWithContinuations = {},
            blacklistedFates= {
                "Hunger Strikes", --really bad line of sight with rocks, get stuck not doing anything quite often
            }
        }
    },
    {
        zoneName = "Ultima Thule",
        zoneId = 960,
        aetheryteList = {
            { aetheryteName="Reah Tahra", x=-544, y=74, z=269 },
            { aetheryteName="Abode of the Ea", x=64, y=272, z=-657 },
            { aetheryteName="Base omicron", x=-489, y=437, z=333 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="Omicron Recall: Comms Expansion", npcName="N-6205" }
            },
            otherNpcFates= {
                { fateName="Wings of Glory", npcName="Ahl Ein's Kin" },
                { fateName="Omicron Recall: Secure Connection", npcName="N-6205"},
                { fateName="Only Just Begun", npcName="Myhk Nehr" }
            },
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Elpis",
        zoneId = 961,
        aetheryteList = {
            { aetheryteName="Anagnorisis", x=159, y=11, z=126 },
            { aetheryteName="The Twelve Wonders", x=-633, y=-19, z=542 },
            { aetheryteName="Poieten Oikos", x=-529, y=161, z=-222 },
        },
        fatesList= {
            collectionsFates= {
                { fateName="So Sorry, Sokles", npcName="Flora Overseer" }
            },
            otherNpcFates= {
                { fateName="Grand Designs: Unknown Execution", npcName="Meletos the Inscrutable" },
                { fateName="Grand Designs: Aigokeros", npcName="Meletos the Inscrutable" },
                { fateName="Nature's Staunch Protector", npcName="Monoceros Monitor" },
            },
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName = "Urqopacha",
        zoneId = 1187,
        aetheryteList = {
            { aetheryteName="Wachunpelo", x=335, y=-160, z=-415 },
            { aetheryteName="Worlar's Echo", x=465, y=115, z=635 },
        },
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {
                { fateName="Pasture Expiration Date", npcName="Tsivli Stoutstrider" },
                { fateName="Gust Stop Already", npcName="Mourning Yok Huy" },
                { fateName="Lay Off the Horns", npcName="Yok Huy Vigilkeeper" },
                { fateName="Birds Up", npcName="Coffee Farmer" },
                { fateName="Salty Showdown", npcName="Chirwagur Sabreur" },
                { fateName="Fire Suppression", npcName="Tsivli Stoutstrider"},
                { fateName="Panaq Attack", npcName="Pelupelu Peddler" }
            },
            fatesWithContinuations = {
                "Salty Showdown"
            },
            blacklistedFates= {
                "Young Volcanoes",
                "Wolf Parade", -- multiple Pelupelu Peddler npcs, rng whether it tries to talk to the right one
                "Panaq Attack" -- multiple Pelupleu Peddler npcs
            }
        }
    },
    {
        zoneName="Kozama'uka",
        zoneId=1188,
        aetheryteList={
            { aetheryteName="Ok'hanu", x=-170, y=6, z=-470 },
            { aetheryteName="Many Fires", x=541, y=117, z=203 },
            { aetheryteName="Earthenshire", x=-477, y=124, z=311 }
        },
        fatesList={
            collectionsFates={
                { fateName="Borne on the Backs of Burrowers", npcName="Moblin Forager" },
                { fateName="Combing the Area", npcName="Hanuhanu Combmaker" },
                { fateName="There's Always a Bigger Beast", npcName="Hanuhanu Angler" }
            },
            otherNpcFates= {},
            fatesWithContinuations = {},
            blacklistedFates= {
                "Mole Patrol"
            }
        }
    },
    {
        zoneName="Yak T'el",
        zoneId=1189,
        aetheryteList={
            { aetheryteName="Iq Br'aax", x=-400, y=24, z=-431 },
            { aetheryteName="Mamook", x=720, y=-132, z=527 }
        },
        fatesList= {
            collectionsFates= {
                { fateName="Escape Shroom", npcName="Hoobigo Forager" }
            },
            otherNpcFates= {
                --{ fateName=, npcName="Xbr'aal Hunter" }, 2 npcs names same thing....
                { fateName="Le Selva se lo Llevó", npcName="Xbr'aal Hunter" },
                { fateName="Stabbing Gutward", npcName="Doppro Spearbrother" },
                --{ fateName=, npcName="Xbr'aal Sentry" }, -- 2 npcs named same thing.....
            },
            fatesWithContinuations = {},
            blacklistedFates= {
                "The Departed",
                "Porting Is Such Sweet Sorrow" -- defence fate
            }
        }
    },
    {
        zoneName="Shaaloani",
        zoneId=1190,
        aetheryteList= {
            { aetheryteName="Hhusatahwi", x=390, y=0, z=465 }, -- 23 collections
            { aetheryteName="Sheshenewezi Springs", x=-295, y=19, z=-115 },
            { aetheryteName="Mehwahhetsoan", x=310, y=-15, z=-567 }
        },
        fatesList= {
            collectionsFates= {
                { fateName="Gonna Have Me Some Fur", npcName="Tonawawtan Trapper" },
                { fateName="The Serpentlord Sires", npcName="Br'uk Vaw of the Setting Sun" }
            },
            otherNpcFates= {
                { fateName="The Dead Never Die", npcName="Tonawawtan Worker" }, --22 boss
                { fateName="Ain't What I Herd", npcName="Hhetsarro Herder" }, --23 normal
                { fateName="Helms off to the Bull", npcName="Hhetsarro Herder" }, --22 boss
                { fateName="A Raptor Runs Through It", npcName="Hhetsarro Angler" }, --24 tower defense
                { fateName="The Serpentlord Suffers", npcName="Br'uk Vaw of the Setting Sun" },
                { fateName="That's Me and the Porter", npcName="Pelupelu Peddler" },
            },
            fatesWithContinuations = {},
            blacklistedFates= {}
        }
    },
    {
        zoneName="Heritage Found",
        zoneId=1191,
        aetheryteList= {
            { aetheryteName="Yyasulani Station", x=515, y=145, z=210 },
            { aetheryteName="The Outskirts", x=-221, y=32, z=-583 },
            { aetheryteName="Electrope Strike", x=-222, y=31, z=123 }
        },
        fatesList= {
            collectionsFates= {
                { fateName="License to Dill", npcName="Tonawawtan Provider" },
            },
            otherNpcFates= {
                { fateName="It's Super Defective", npcName="Novice Hunter" },
                { fateName="Running of the Katobleps", npcName="Novice Hunter" },
                { fateName="Ware the Wolves", npcName="Imperiled Hunter" },
                { fateName="Domo Arigato", npcName="Perplexed Reforger" },
                { fateName="Old Stampeding Grounds", npcName="Driftdowns Reforger" },
                { fateName="Pulling the Wool", npcName="Panicked Courier" },
                { fateName="When It's So Salvage", npcName="Refined Reforger" }
            },
            fatesWithContinuations = {
                "Domo Arigato"
            },
            blacklistedFates= {
                "When It's So Salvage", -- terrain is terrible
                "print('I hate snakes')"
            }
        }
    },
    {
        zoneName="Living Memory",
        zoneId=1192,
        aetheryteList= {
            { aetheryteName="Leynode Mnemo", x=0, y=56, z=796 },
            { aetheryteName="Leynode Pyro", x=659, y=27, z=-285 },
            { aetheryteName="Leynode Aero", x=-253, y=56, z=-400 }
        },
        fatesList= {
            collectionsFates= {
                { fateName="Seeds of Tomorrow", npcName="Unlost Sentry GX" },
                { fateName="Scattered Memories", npcName="Unlost Sentry GX" }
            },
            otherNpcFates= {
                { fateName="Canal Carnage", npcName="Unlost Sentry GX" },
                { fateName="Mascot March", npcName="The Grand Marshal" }
            },
            fatesWithContinuations =
            {
                "Plumbers Don't Fear Slimes",
                "Mascot March"
            },
            blacklistedFates= {}
        }
    }
}

--#endregion Data

--#region Fate Functions
function IsCollectionsFate(fateName)
    for i, collectionsFate in ipairs(SelectedZone.fatesList.collectionsFates) do
        if collectionsFate.fateName == fateName then
            return true
        end
    end
    return false
end

function IsBossFate(fateId)
    -- for i, bossFate in ipairs(SelectedZone.fatesList.bossFates) do
    --     if bossFate == fateName then
    --         return true
    --     end
    -- end
    -- return false
    local fateIcon = GetFateIconId(fateId)
    return fateIcon == 60722
end

function IsOtherNpcFate(fateName)
    for i, otherNpcFate in ipairs(SelectedZone.fatesList.otherNpcFates) do
        if otherNpcFate.fateName == fateName then
            return true
        end
    end
    return false
end

function HasContinuation(fateName)
    for i, continuationFates in ipairs(SelectedZone.fatesList.fatesWithContinuations) do
        if continuationFates.fateName == fateName then
            return true
        end
    end
    return false
end

function IsBlacklistedFate(fateName)
    for i, blacklistedFate in ipairs(SelectedZone.fatesList.blacklistedFates) do
        if blacklistedFate == fateName then
            return true
        end
    end
    if not JoinCollectionsFates then
        for i, collectionsFate in ipairs(SelectedZone.fatesList.collectionsFates) do
            if collectionsFate.fateName == fateName then
                return true
            end
        end
    end
    return false
end

function GetFateNpcName(fateName)
    for i, fate in ipairs(SelectedZone.fatesList.otherNpcFates) do
        if fate.fateName == fateName then
            return fate.npcName
        end
    end
    for i, fate in ipairs(SelectedZone.fatesList.collectionsFates) do
        if fate.fateName == fateName then
            return fate.npcName
        end
    end
end

function IsFateActive(fateId)
    local activeFates = GetActiveFates()
    for i = 0, activeFates.Count-1 do
        if fateId == activeFates[i] then
            return true
        end
    end
    return false
end

function EorzeaTimeToUnixTime(eorzeaTime)
    return eorzeaTime/(144/7) -- 24h Eorzea Time equals 70min IRL
end

--[[
    Given two fates, picks the better one based on priority progress -> is bonus -> time left -> distance
]]
function SelectNextFateHelper(tempFate, nextFate)
    if tempFate.timeLeft < MinTimeLeftToIgnoreFate or tempFate.progress > CompletionToIgnoreFate then
        return nextFate
    else
        if nextFate == nil then
                LogInfo("[FATE] Selecting #"..tempFate.fateId.." because no other options so far.")
                return tempFate
        -- elseif nextFate.startTime == 0 and tempFate.startTime > 0 then -- nextFate is an unopened npc fate
        --     LogInfo("[FATE] Selecting #"..tempFate.fateId.." because other fate #"..nextFate.fateId.." is an unopened npc fate.")
        --     return tempFate
        -- elseif tempFate.startTime == 0 and nextFate.startTime > 0 then -- tempFate is an unopened npc fate
        --     return nextFate
        else -- select based on progress
            if tempFate.progress > nextFate.progress then
                LogInfo("[FATE] Selecting #"..tempFate.fateId.." because other fate #"..nextFate.fateId.." has less progress.")
                return tempFate
            elseif tempFate.progress < nextFate.progress then
                LogInfo("[FATE] Selecting #"..nextFate.fateId.." because other fate #"..tempFate.fateId.." has less progress.")
                return nextFate
            else
                if nextFate.isBonusFate and tempFate.isBonusFate then
                    if tempFate.timeLeft < nextFate.timeLeft then -- select based on time left
                        LogInfo("[FATE] Selecting #"..tempFate.fateId.." because other fate #"..nextFate.fateId.." has more time left.")
                        return tempFate
                    elseif tempFate.timeLeft > nextFate.timeLeft then
                        LogInfo("[FATE] Selecting #"..tempFate.fateId.." because other fate #"..nextFate.fateId.." has more time left.")
                        return nextFate
                    else
                        tempFatePlayerDistance = GetDistanceToPoint(tempFate.x, tempFate.y, tempFate.z)
                        nextFatePlayerDistance = GetDistanceToPoint(nextFate.x, nextFate.y, nextFate.z)
                        if tempFatePlayerDistance < nextFatePlayerDistance then
                            LogInfo("[FATE] Selecting #"..tempFate.fateId.." because other fate #"..nextFate.fateId.." is farther.")
                            return tempFate
                        elseif tempFatePlayerDistance > nextFatePlayerDistance then
                            LogInfo("[FATE] Selecting #"..nextFate.fateId.." because other fate #"..nextFate.fateId.." is farther.")
                            return nextFate
                        else
                            if tempFate.fateId < nextFate.fateId then
                                return tempFate
                            else
                                return nextFate
                            end
                        end
                    end
                elseif nextFate.isBonusFate then
                    return nextFate
                elseif tempFate.isBonusFate then
                    return tempFate
                end
            end
        end
    end
    return nextFate
end

function BuildFateTable(fateId)
    local fateTable = {
        fateId = fateId,
        fateName = GetFateName(fateId),
        progress = GetFateProgress(fateId),
        duration = GetFateDuration(fateId),
        startTime = GetFateStartTimeEpoch(fateId),
        x = GetFateLocationX(fateId),
        y = GetFateLocationY(fateId),
        z = GetFateLocationZ(fateId),
        isBonusFate = GetFateIsBonus(fateId),
    }
    fateTable.npcName = GetFateNpcName(fateTable.fateName)

    local currentTime = EorzeaTimeToUnixTime(GetCurrentEorzeaTimestamp())
    if fateTable.startTime == 0 then
        fateTable.timeLeft = 900
    else
        fateTable.timeElapsed = currentTime - fateTable.startTime
        fateTable.timeLeft = fateTable.duration - fateTable.timeElapsed
    end

    return fateTable
end

--Gets the Location of the next Fate. Prioritizes anything with progress above 0, then by shortest time left
function SelectNextFate()
    local fates = GetActiveFates()
    if fates == nil then
        return
    end

    local nextFate = nil
    for i = 0, fates.Count-1 do
        local tempFate = BuildFateTable(fates[i])
        LogInfo("[FATE] Considering fate #"..tempFate.fateId.." "..tempFate.fateName)
        LogInfo("[FATE] Time left on fate #:"..tempFate.fateId..": "..math.floor(tempFate.timeLeft//60).."min, "..math.floor(tempFate.timeLeft%60).."s")
        
        if not (tempFate.x == 0 and tempFate.z == 0) then -- sometimes game doesn't send the correct coords
            if not IsBlacklistedFate(tempFate.fateName) then -- check fate is not blacklisted for any reason
                if IsBossFate(tempFate.fateId) then
                    if tempFate.progress >= CompletionToJoinBossFate then
                        nextFate = SelectNextFateHelper(tempFate, nextFate)
                    else
                        LogInfo("[FATE] Skipping fate #"..tempFate.fateId.." "..tempFate.fateName.." due to boss fate with not enough progress.")
                    end
                elseif IsOtherNpcFate(tempFate.fateName) then
                    if tempFate.startTime > 0 then -- if someone already opened this fate, then treat is as all the other fates
                        nextFate = SelectNextFateHelper(tempFate, nextFate)
                    else -- no one has opened this fate yet
                        if nextFate == nil then -- pick this if there's nothing else
                            nextFate = tempFate
                        elseif tempFate.isBonusFate then
                            nextFate = SelectNextFateHelper(tempFate, nextFate)
                        elseif nextFate.startTime == 0 then -- both fates are unopened npc fates
                            nextFate = SelectNextFateHelper(tempFate, nextFate)
                        end
                    end
                elseif tempFate.duration ~= 0 then -- else is normal fate. avoid unlisted talk to npc fates
                    nextFate = SelectNextFateHelper(tempFate, nextFate)
                end
                LogInfo("[FATE] Finished considering fate #"..tempFate.fateId.." "..tempFate.fateName)
            end
        end
    end

    LogInfo("[FATE] Finished considering all fates")

    if nextFate == nil then
        LogInfo("[FATE] No eligible fates found.")
        if Echo == 2 then
            yield("/echo [FATE] No eligible fates found.")
        end
    else
        LogInfo("[FATE] Final selected fate #"..nextFate.fateId.." "..nextFate.fateName)
    end
    yield("/wait 1")

    return nextFate
end

function RandomAdjustCoordinates(x, y, z, maxDistance)
    local angle = math.random() * 2 * math.pi
    local x_adjust = maxDistance * math.random()
    local z_adjust = maxDistance * math.random()

    local randomX = x + (x_adjust * math.cos(angle))
    local randomY = y + maxDistance
    local randomZ = z + (z_adjust * math.sin(angle))

    return randomX, randomY, randomZ
end

--#endregion Fate Functions

--#region Movement Functions

function GetClosestAetheryte(x, y, z, teleportTimePenalty)
    local closestAetheryte = nil
    local closestTravelDistance = math.maxinteger
    for j, aetheryte in ipairs(SelectedZone.aetheryteList) do
        local distanceAetheryteToFate = DistanceBetween(aetheryte.x, aetheryte.y, aetheryte.z, x, y, z)
        local comparisonDistance = distanceAetheryteToFate + teleportTimePenalty
        LogInfo("[FATE] Distance via "..aetheryte.aetheryteName.." adjusted for tp penalty is "..tostring(comparisonDistance))

        if comparisonDistance < closestTravelDistance then
            LogInfo("[FATE] Updating closest aetheryte to "..aetheryte.aetheryteName)
            closestTravelDistance = comparisonDistance
            closestAetheryte = aetheryte
        end
    end

    return closestAetheryte
end

function GetClosestAetheryteToPoint(x, y, z, teleportTimePenalty)
    local directFlightDistance = GetDistanceToPoint(x, y, z)
    LogInfo("[FATE] Direct flight distance is: "..directFlightDistance)
    local closestAetheryte = GetClosestAetheryte(x, y, z, teleportTimePenalty)
    local closestAetheryteDistance = DistanceBetween(x, y, z, closestAetheryte.x, closestAetheryte.y, closestAetheryte.z) + teleportTimePenalty

    if closestAetheryteDistance < directFlightDistance then
        return closestAetheryte
    else
        return nil
    end
end

function TeleportToClosestAetheryteToFate(nextFate)
    local aetheryteForClosestFate = GetClosestAetheryteToPoint(nextFate.x, nextFate.y, nextFate.z, 200)
    if aetheryteForClosestFate ~=nil then
        TeleportTo(aetheryteForClosestFate.aetheryteName)
        return true
    end
    return false
end

function TeleportTo(aetheryteName)
    while EorzeaTimeToUnixTime(GetCurrentEorzeaTimestamp()) - LastTeleportTimeStamp < 5 do
        LogInfo("[FATE] Too soon since last teleport. Waiting...")
        yield("/wait 5")
    end

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
    LastTeleportTimeStamp = EorzeaTimeToUnixTime(GetCurrentEorzeaTimestamp())
end

function ChangeInstance()
    if SuccessiveInstanceChanges >= 3 then
        yield("/wait 10")
        SuccessiveInstanceChanges = 0
        return
    end

    yield("/target aetheryte") -- search for nearby aetheryte
    if not HasTarget() or GetTargetName() ~= "aetheryte" then -- if no aetheryte within targeting range, teleport to it
        local closestAetheryte = nil
        local closestAetheryteDistance = math.maxinteger
        for i, aetheryte in ipairs(SelectedZone.aetheryteList) do
            -- GetDistanceToPoint is implemented with raw distance instead of distance squared
            local distanceToAetheryte = GetDistanceToPoint(aetheryte.x, aetheryte.y, aetheryte.z)
            if distanceToAetheryte < closestAetheryteDistance then
                closestAetheryte = aetheryte
                closestAetheryteDistance = distanceToAetheryte
            end
        end
        TeleportTo(closestAetheryte.aetheryteName)
        return
    end

    if WaitingForCollectionsFate ~= 0 then
        yield("/wait 10")
        return
    end

    if GetCharacterCondition(CharacterCondition.mounted) then
        State = CharacterState.changeInstanceDismount
        LogInfo("[FATE] State Change: ChangeInstanceDismount")
        return
    end

    if GetDistanceToTarget() > 10 then
        if not (PathfindInProgress() or PathIsRunning()) then
            PathfindAndMoveTo(GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos(), GetCharacterCondition(CharacterCondition.flying))
            return
        end
    else
        if PathfindInProgress() or PathIsRunning() then
            yield("/vnav stop")
            return
        end
    end

    local nextInstance = (GetZoneInstance() % 3) + 1
    yield("/li "..nextInstance) -- start instance transfer
    yield("/wait 1") -- wait for instance transfer to register
    State = CharacterState.ready
    SuccessiveInstanceChanges = SuccessiveInstanceChanges + 1
    LogInfo("[FATE] State Change: Ready")
end

function WaitForContinuation()
    if IsInFate() then
        local nextFateId = GetNearestFate()
        if nextFateId ~= CurrentFate.fateId then
            CurrentFate = BuildFateTable(nextFateId)
            State = CharacterState.doFate
            LogInfo("State Change: DoFate")
        end
    elseif os.clock() - LastFateEndTime > 30 then
        LogInfo("Over 30s since end of last fate. Giving up on part 2.")
        TurnOffCombatMods()
        State = CharacterState.ready
        LogInfo("State Change: Ready")
    else
        yield("/wait 1")
    end
end

function FlyBackToAetheryte()
    NextFate = SelectNextFate()
    if NextFate ~= nil then
        State = CharacterState.ready
        LogInfo("[FATE] State Change: Ready")
        return
    end

    if GetCharacterCondition(CharacterCondition.flying) then
        if not (PathfindInProgress() or PathIsRunning()) then
            local closestAetheryte = GetClosestAetheryte(GetPlayerRawXPos(), GetPlayerRawYPos(), GetPlayerRawZPos(), 0)
            if closestAetheryte ~= nil and GetDistanceToPoint(closestAetheryte.x, closestAetheryte.y, closestAetheryte.z) > 50 then
                PathfindAndMoveTo(closestAetheryte.x, closestAetheryte.y, closestAetheryte.z, GetCharacterCondition(CharacterCondition.flying))
            end
        end
        yield("/wait 10")
    elseif GetCharacterCondition(CharacterCondition.mounted) then
        yield("/gaction jump")
    else
        if MountToUse == "mount roulette" then
            yield('/gaction "mount roulette"')
        else
            yield('/mount "' .. MountToUse)
        end
    end
    yield("/wait 1")
end

function Mount()
    if GetCharacterCondition(CharacterCondition.flying) then
        State = CharacterState.moveToFate
        LogInfo("[FATE] State Change: MoveToFate")
    elseif GetCharacterCondition(CharacterCondition.mounted) then
        yield("/gaction jump")
    else
        if MountToUse == "mount roulette" then
            yield('/gaction "mount roulette"')
        else
            yield('/mount "' .. MountToUse)
        end
    end
    yield("/wait 1")
end

function Dismount()
    if PathIsRunning() or PathfindInProgress() then
        yield("/vnav stop")
        return
    end

    if GetCharacterCondition(CharacterCondition.flying) then
        local x1 = GetPlayerRawXPos()
        local y1 = GetPlayerRawYPos()
        local z1 = GetPlayerRawZPos()

        yield('/ac dismount')

        local now = os.clock()
        if now - LastStuckCheckTime > 1 then
            local x = GetPlayerRawXPos()
            local y = GetPlayerRawYPos()
            local z = GetPlayerRawZPos()

            if GetCharacterCondition(CharacterCondition.flying) and GetDistanceToPoint(LastStuckCheckPosition.x, LastStuckCheckPosition.y, LastStuckCheckPosition.z) < 2 then
                LogInfo("[FATE] Unable to dismount here. Moving to another spot.")
                local random_x, random_y, random_z = RandomAdjustCoordinates(x, y, z, 10)
                local nearestPointX = QueryMeshNearestPointX(random_x, random_y, random_z, 100, 100)
                local nearestPointY = QueryMeshNearestPointY(random_x, random_y, random_z, 100, 100)
                local nearestPointZ = QueryMeshNearestPointZ(random_x, random_y, random_z, 100, 100)
                if nearestPointX ~= nil and nearestPointY ~= nil and nearestPointZ ~= nil then
                    PathfindAndMoveTo(nearestPointX, nearestPointY, nearestPointZ, GetCharacterCondition(CharacterCondition.flying))
                    yield("/wait 1")
                end
            end

            LastStuckCheckTime = now
            LastStuckCheckPosition = {x=x, y=y, z=z}
        end
    elseif GetCharacterCondition(CharacterCondition.mounted) then
        yield('/ac dismount')
    end
end

function MiddleOfFateDismount()
    if PathfindInProgress() or PathIsRunning() then
        return
    end

    if HasTarget() and GetDistanceToTarget() > RangedDist and not (PathfindInProgress() or PathIsRunning()) then
        PathfindAndMoveTo(GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos(), GetCharacterCondition(CharacterCondition.flying))
        return
    end

    if GetCharacterCondition(CharacterCondition.mounted) then
        Dismount()
    else
        State = CharacterState.doFate
        LogInfo("[FATE] State Change: MoveToFate")
    end
end

function NPCDismount()
    if GetCharacterCondition(CharacterCondition.mounted) then
        Dismount()
    else
        State = CharacterState.interactWithNpc
        LogInfo("[FATE] State Change: InteractWithFateNpc")
    end
end

function ChangeInstanceDismount()
    if GetCharacterCondition(CharacterCondition.mounted) then
        Dismount()
    else
        State = CharacterState.changingInstances
        LogInfo("[FATE] State Change: ChangingInstance")
    end
end

--Paths to the Fate NPC Starter
function MoveToNPC()
    yield("/target "..CurrentFate.npcName)
    if HasTarget() and GetTargetName()==CurrentFate.npcName then
        if GetDistanceToTarget() > 5 then
            PathfindAndMoveTo(GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos(), GetCharacterCondition(CharacterCondition.flying))
        else
            yield("/vnav stop")
        end
        return
    end
end

--Paths to the Fate. Assumes CurrentFate is not nil
function MoveToFate()
    SuccessiveInstanceChanges = 0

    if not IsPlayerAvailable() then
        yield("/echo [FATE] Player not available")
        return
    end

    if not IsFateActive(CurrentFate.fateId) then
        LogInfo("[FATE] Next Fate is dead, selecting new Fate.")
        yield("/vnav stop")
        State = CharacterState.ready
        LogInfo("[FATE] State Change: Ready")
        return
    end

    NextFate = SelectNextFate()
    if NextFate == nil then -- when moving to next fate, CurrentFate == NextFate
        yield("/vnav stop")
        State = CharacterState.ready
        LogInfo("[FATE] State Change: Ready")
        return
    elseif NextFate.fateId ~= CurrentFate.fateId then
        yield("/vnav stop")
        CurrentFate = NextFate
        return
    end

    -- change to secondary class if it's a boss fate
    if BossFatesClass ~= nil then
        local currentClass = GetClassJobId()
        if IsBossFate(CurrentFate.fateId) and currentClass ~= BossFatesClass.classId then
            yield("/gs change "..BossFatesClass.className)
            return
        elseif not IsBossFate(CurrentFate.fateId) and currentClass ~= MainClass.classId then
            yield("/gs change "..MainClass.className)
            return
        end
    end

    -- upon approaching fate, pick a target and switch to pathing towards target
    if HasTarget() then
        yield("/vnav stop")
        if GetTargetName() == CurrentFate.npcName then
            yield("/vnav stop")
            State = CharacterState.interactWithNpc
        elseif GetTargetFateID() == CurrentFate.fateId then
            State = CharacterState.middleOfFateDismount
            LogInfo("[FATE] State Change: MiddleOfFateDismount")
        else
            ClearTarget()
        end
        return
    elseif GetDistanceToPoint(CurrentFate.x, CurrentFate.y, CurrentFate.z) < 40 then
        if (IsOtherNpcFate(CurrentFate.fateName) or IsCollectionsFate(CurrentFate.fateName)) and not IsInFate() then
            yield("/target "..CurrentFate.npcName)
        else
            TargetClosestFateEnemy()
        end

        if HasTarget() and GetDistanceToTarget() < 30 then
            yield("/vnav stop")
        end
        return
    end

    -- if not PathIsRunning() and IsInFate() and GetFateProgress(CurrentFate.fateId) < 100 then
    --     State = CharacterState.doFate
    --     LogInfo("[FATE] State Change: DoFate")
    --     return
    -- end

    -- check for stuck
    if (PathIsRunning() or PathfindInProgress()) and GetCharacterCondition(CharacterCondition.mounted) then
        local now = os.clock()
        if now - LastStuckCheckTime > 10 then
            local x = GetPlayerRawXPos()
            local y = GetPlayerRawYPos()
            local z = GetPlayerRawZPos()

            if GetDistanceToPoint(LastStuckCheckPosition.x, LastStuckCheckPosition.y, LastStuckCheckPosition.z) < 3 then
                yield("/vnav stop")
                yield("/wait 1")
                LogInfo("[FATE] Antistuck")
                PathfindAndMoveTo(x, y + 10, z, GetCharacterCondition(CharacterCondition.flying)) -- fly up 10 then try again
            end
            
            LastStuckCheckTime = now
            LastStuckCheckPosition = {x=x, y=y, z=z}
        end
        return
    end

    -- if GetDistanceToPoint(CurrentFate.x, CurrentFate.y, CurrentFate.z) < GetFateRadius(CurrentFate.fateId) + 20 then
    --     if (IsOtherNpcFate(CurrentFate.fateName) or IsCollectionsFate(CurrentFate.fateName)) and CurrentFate.startTime == 0 then
    --         State = CharacterState.interactWithNpc
    --         LogInfo("[FATE] State Change: InteractWithFateNpc")
    --         return
    --     else
    --         if not PathIsRunning() and GetFateProgress(CurrentFate.fateId) < 100 then
    --             State = CharacterState.doFate
    --             LogInfo("[FATE] State Change: DoFate")
    --             return
    --         end
    --     end
    --     return
    -- end

    if not GetCharacterCondition(CharacterCondition.flying) then
        State = CharacterState.mounting
        LogInfo("[FATE] State Change: Mounting")
        return
    end

    LogInfo("[FATE] Moving to fate #"..CurrentFate.fateId.." "..CurrentFate.fateName)
    if Echo == 2 then
        yield("/echo [FATE] Moving to fate #"..CurrentFate.fateId.." "..CurrentFate.fateName)
    end

    local nearestLandX, nearestLandY, nearestLandZ = CurrentFate.x, CurrentFate.y, CurrentFate.z
    if not (IsCollectionsFate(CurrentFate.fateName) or IsOtherNpcFate(CurrentFate.fateName)) then
        nearestLandX, nearestLandY, nearestLandZ = RandomAdjustCoordinates(CurrentFate.x, CurrentFate.y, CurrentFate.z, 10)
    end

    if HasPlugin("ChatCoordinates") then
        SetMapFlag(SelectedZone.zoneId, nearestLandX, nearestLandY, nearestLandZ)
    end

    if TeleportToClosestAetheryteToFate(CurrentFate) then
        return
    end

    PathfindAndMoveTo(nearestLandX, nearestLandY, nearestLandZ, HasFlightUnlocked(SelectedZone.zoneId))
end

function InteractWithFateNpc()
    if IsInFate() or GetFateStartTimeEpoch(CurrentFate.fateId) > 0 then
        State = CharacterState.doFate
        LogInfo("[FATE] State Change: DoFate")
        yield("/wait 1") -- give the fate a second to register before dofate and lsync
    elseif not IsFateActive(CurrentFate.fateId) then
        State = CharacterState.ready
        LogInfo("[FATE] State Change: Ready")
    elseif PathfindInProgress() or PathIsRunning() then
        if HasTarget() and GetTargetName() == CurrentFate.npcName and GetDistanceToTarget() < 5 then
            yield("/vnav stop")
        end
        return
    else
        -- if target is already selected earlier during pathing, avoids having to target and move again
        if (not HasTarget() or GetTargetName()~=CurrentFate.npcName) then
            yield("/target "..CurrentFate.npcName)
            return
        end

        if GetDistanceToPoint(GetTargetRawXPos(), GetPlayerRawYPos(), GetTargetRawZPos()) > 5 then
            MoveToNPC()
            return
        end

        if GetCharacterCondition(CharacterCondition.mounted) then
            State = CharacterState.npcDismount
            LogInfo("[FATE] State Change: NPCDismount")
            return
        end

        if IsAddonVisible("SelectYesno") then
            yield("/callback SelectYesno true 0")
        elseif not GetCharacterCondition(CharacterCondition.occupied) then
            yield("/interact")
        end
    end
end

function CollectionsFateTurnIn()
    if (not HasTarget() or GetTargetName()~=CurrentFate.npcName) then
        yield("/target "..CurrentFate.npcName)
        return
    end

    if GetDistanceToPoint(GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos()) > 5 then
        if not (PathfindInProgress() or PathIsRunning()) then
            MoveToNPC()
        end
    else
        if GetItemCount(GetFateEventItem(CurrentFate.fateId)) >= 7 then
            GotCollectionsFullCredit = true
        end

        yield("/vnav stop")
        yield("/interact")
        yield("/wait 3")

        if GetFateProgress(CurrentFate.fateId) < 100 then
            State = CharacterState.doFate
            LogInfo("[FATE] State Change: DoFate")
        else
            if GotCollectionsFullCredit then
                State = CharacterState.ready
                LogInfo("[FATE] State Change: Ready")
            end
        end

        if CurrentFate ~=nil and CurrentFate.npcName ~=nil and GetTargetName() == CurrentFate.npcName then
            LogInfo("[FATE] Attempting to clear target.")
            ClearTarget()
            yield("/wait 1")
        end
    end
end

--#endregion

--#region Combat Functions

function GetClassJobTableFromId(jobId)
    if jobId == nil then
        LogInfo("[FATE] JobId is nil")
        return nil
    end
    for _, classJob in pairs(ClassList) do
        if classJob.classId == jobId then
            return classJob
        end
    end
    LogInfo("[FATE] Cannot recognize combat job.")
    return nil
end

function GetClassJobTableFromAbbrev(classString)
    if classString == "" then
        LogInfo("[FATE] No class set")
        return nil
    end
    for classJobAbbrev, classJob in pairs(ClassList) do
        if classJobAbbrev == string.lower(classString) then
            return classJob
        end
    end
    LogInfo("[FATE] Cannot recognize combat job.")
    return nil
end

function SummonChocobo()
    if ShouldSummonChocobo and GetBuddyTimeRemaining() == 0 and GetItemCount(4868) > 0 then
        yield("/item Gysahl Greens")
    end
end

--Paths to the enemy (for Meele)
function EnemyPathing()
    while HasTarget() and GetDistanceToTarget() > 3.5 do
        local enemy_x = GetTargetRawXPos()
        local enemy_y = GetTargetRawYPos()
        local enemy_z = GetTargetRawZPos()
        if PathIsRunning() == false then
            PathfindAndMoveTo(enemy_x, enemy_y, enemy_z, GetCharacterCondition(CharacterCondition.flying))
        end
        yield("/wait 0.1")
    end
end

-- function AvoidEnemiesWhileFlying()
--     --If you get attacked it flies up
--     if GetCharacterCondition(CharacterCondition.inCombat) then
--         Name = GetCharacterName()
--         PlocX = GetPlayerRawXPos(Name)
--         PlocY = GetPlayerRawYPos(Name)+40
--         PlocZ = GetPlayerRawZPos(Name)
--         yield("/gaction jump")
--         yield("/wait 0.5")
--         yield("/vnavmesh stop")
--         yield("/wait 1")
--         PathfindAndMoveTo(PlocX, PlocY, PlocZ, true)
--         PathStop()
--         yield("/wait 2")
--     end
-- end

function SetMaxDistance()
    MaxDistance = MeleeDist --default to melee distance
    --ranged and casters have a further max distance so not always running all way up to target
    local currentClass = GetClassJobTableFromId(GetClassJobId())
    if not currentClass.isMelee then
        MaxDistance = RangedDist
    end
end

function TurnOnCombatMods()
    if not CombatModsOn then
        CombatModsOn = true
        -- turn on RSR in case you have the RSR 30 second out of combat timer set
        if TargetingSystem == "Pandora" then
            yield("/rotation manual")
        else
            yield("/rotation auto on")
        end

        local class = GetClassJobTableFromId(GetClassJobId())
        
        if class.isTank or class.className == "White Mage" then -- white mage holy OP, or tank classes
            yield("/rotation settings aoetype 2") -- aoe
        else
            yield("/rotation settings aoetype 1") -- cleave
        end

        if not bossModAIActive and UseBM then
            SetMaxDistance()
            
            if BMorBMR == "BMR" then
                yield("/bmrai on")
                yield("/bmrai followtarget on") -- overrides navmesh path and runs into walls sometimes
                yield("/bmrai followcombat on")
                -- yield("/bmrai followoutofcombat on")
                yield("/bmrai maxdistancetarget " .. MaxDistance)
            else
                yield("/vbmai on")
                yield("/vbmai followtarget on")
                yield("/vbmai followcombat on")
                --yield("/vbmai followoutofcombat on")
            end
            bossModAIActive = true
        end
    end
end

function TurnOffCombatMods()
    if CombatModsOn then
        yield("/rotation off")

        LogInfo("[FATE] Turning off combat mods")
        CombatModsOn = false
        -- no need to turn RSR off

        -- turn off BMR so you don't start following other mobs
        if UseBM and bossModAIActive then
            if BMorBMR == "BMR" then
                yield("/bmrai off")
                yield("/bmrai followtarget off")
                yield("/bmrai followcombat off")
                yield("/bmrai followoutofcombat off")
            else
                yield("/vbmai off")
                --yield("/vbmai followtarget off")
                --yield("/vbmai followcombat off")
                --yield("/vbmai followoutofcombat off")
            end
            bossModAIActive = false
        end
    end
end

function HandleUnexpectedCombat()
    CurrentFate = nil

    if not GetCharacterCondition(CharacterCondition.inCombat) then
        yield("/vnav stop")
        ClearTarget()
        TurnOffCombatMods()
        State = CharacterState.ready
        LogInfo("[FATE] State Change: Ready")
        yield("/wait "..math.random()*3)
        return
    end

    TurnOnCombatMods()

    -- targets whatever is trying to kill you
    if not HasTarget() then
        yield("/battletarget")
    end

    --Paths to enemys when Bossmod is disabled
    if not UseBM then
        EnemyPathing()
    end

    -- pathfind closer if enemies are too far
    if HasTarget() then
        if GetDistanceToTarget() > (MaxDistance + GetTargetHitboxRadius()) then
            if not (PathfindInProgress() or PathIsRunning()) then
                PathfindAndMoveTo(GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos(), GetCharacterCondition(CharacterCondition.flying))
            end
        else
            if PathfindInProgress() or PathIsRunning() then
                yield("/vnav stop")
            elseif not GetCharacterCondition(CharacterCondition.inCombat) then
                --inch closer 3 seconds
                PathfindAndMoveTo(GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos(), GetCharacterCondition(CharacterCondition.flying))
                yield("/wait 3")
            end
        end
    end
    yield("/wait 1")
end

-- Pandora FATE Targeting Mode should only be turned on during DoFate
function DoFate()
    if TargetingSystem == "Pandora" then
        PandoraSetFeatureState("FATE Targeting Mode", true)
    end

    if IsInFate() and (GetFateMaxLevel(CurrentFate.fateId) < GetLevel()) and not IsLevelSynced() then
        yield("/lsync")
    elseif IsFateActive(CurrentFate.fateId) and not IsInFate() and GetFateProgress(CurrentFate.fateId) < 100 and
        (GetDistanceToPoint(CurrentFate.x, CurrentFate.y, CurrentFate.z) < GetFateRadius(CurrentFate.fateId) + 10) and
        not GetCharacterCondition(CharacterCondition.mounted) and not (PathIsRunning() or PathfindInProgress())
    then -- got pushed out of fate. go back
        yield("/vnav stop")
        yield("/wait 1")
        PathfindAndMoveTo(CurrentFate.x, CurrentFate.y, CurrentFate.z, GetCharacterCondition(CharacterCondition.flying))
        return
    elseif not IsFateActive(CurrentFate.fateId) then
        yield("/vnav stop")
        ClearTarget()
        if TargetingSystem == "Pandora" then
            PandoraSetFeatureState("FATE Targeting Mode", false)
        end
        if HasContinuation(CurrentFate.fateName) then
            LastFateEndTime = os.clock()
            State = CharacterState.waitForContinuation
            LogInfo("[FATE] State Change: WaitForContinuation")
        else
            TurnOffCombatMods()
            State = CharacterState.ready
            LogInfo("[FATE] State Change: Ready")
            yield("/wait "..math.random()*3)
        end
        return
    elseif GetCharacterCondition(CharacterCondition.mounted) then
        State = CharacterState.middleOfFateDismount
        LogInfo("[FATE] State Change: MiddleOfFateDismount")
        if TargetingSystem == "Pandora" then
            PandoraSetFeatureState("FATE Targeting Mode", false)
        end
        return
    elseif IsCollectionsFate(CurrentFate.fateName) then
        WaitingForCollectionsFate = CurrentFate.fateId
        yield("/wait 1") -- needs a moment after start of fate for GetFateEventItem to populate
        if GetItemCount(GetFateEventItem(CurrentFate.fateId)) >= 7 or (GotCollectionsFullCredit and GetFateProgress(CurrentFate.fateId) == 100) then
            yield("/vnav stop")
            State = CharacterState.collectionsFateTurnIn
            LogInfo("[FATE] State Change: CollectionsFatesTurnIn")
            if TargetingSystem == "Pandora" then
                PandoraSetFeatureState("FATE Targeting Mode", false)
            end
        end
    end

    LogInfo("DoFate->Finished transition checks")

    -- do not target fate npc during combat
    if CurrentFate.npcName ~=nil and GetTargetName() == CurrentFate.npcName then
        LogInfo("[FATE] Attempting to clear target.")
        ClearTarget()
        yield("/wait 1")
    end

    TurnOnCombatMods()

    GemAnnouncementLock = false

    -- switches to targeting forlorns for bonus (if present)
    yield("/target Forlorn Maiden")
    yield("/target The Forlorn")

    -- if (GetTargetName() == "Forlorn Maiden" or GetTargetName() == "The Forlorn") then
    --     if not SingleTargetForlornMode then
    --         SingleTargetForlornMode = true
    --         yield("/rotation manual")
    --         yield("/rotation settings aoetype 0") -- single target
    --     end
    -- else
    --     if SingleTargetForlornMode then
    --         SingleTargetForlornMode = false
    --         TurnOnCombatMods()
    --     end
    -- end

    -- targets whatever is trying to kill you
    if not HasTarget() then
        yield("/battletarget")
    end

    -- clears target
    if GetTargetFateID() ~= CurrentFate.fateId and not IsTargetInCombat() then
        ClearTarget()
    end

    --Paths to enemys when Bossmod is disabled
    if not UseBM then
        EnemyPathing()
    end

    -- pathfind closer if enemies are too far
    if not GetCharacterCondition(CharacterCondition.inCombat) then
        if HasTarget() then
            if GetDistanceToTarget() <= (1 + GetTargetHitboxRadius()) then
                yield("/vnav stop")
            elseif not (PathfindInProgress() or PathIsRunning()) then
                yield("/wait 1")
                PathfindAndMoveTo(GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos(), GetCharacterCondition(CharacterCondition.flying))
            end
            return
        else
            yield("/targetenemy")
        end
    else
        if HasTarget() and GetDistanceToTarget() <= (MaxDistance + GetTargetHitboxRadius()) then
            yield("/vnav stop")
        else
            if not (PathfindInProgress() or PathIsRunning()) and not UseBM then
                yield("/wait 1")
                PathfindAndMoveTo(GetTargetRawXPos(), GetTargetRawYPos(), GetTargetRawZPos(), GetCharacterCondition(CharacterCondition.flying))
            end
        end
    end
end

--#endregion

--#region State Transition Functions

function FoodCheck()
    --food usage
    if not HasStatusId(48) and Food ~= "" then
        yield("/item " .. Food)
    end
end

function Ready()
    FoodCheck()
    SummonChocobo()
    
    CombatModsOn = false -- expect RSR to turn off after every fate
    GotCollectionsFullCredit = false

    NextFate = SelectNextFate()
    if CurrentFate ~= nil and not IsFateActive(CurrentFate.fateId) then
        CurrentFate = nil
    end

    if CurrentFate == nil then
        LogInfo("[FATE] CurrentFate is nil")
    else
        LogInfo("[FATE] CurrentFate is "..CurrentFate.fateName)
    end

    if NextFate == nil then
        LogInfo("[FATE] NextFate is nil")
    else
        LogInfo("[FATE] NextFate is "..NextFate.fateName)
    end

    if not LogInfo("[FATE] Ready -> IsPlayerAvailable()") and not IsPlayerAvailable() then
        return
    elseif not LogInfo("[FATE] Ready -> Repair") and RepairAmount > 0 and NeedsRepair(RepairAmount) then
        State = CharacterState.repair
        LogInfo("[FATE] State Change: Repair")
    elseif not LogInfo("[FATE] Ready -> ExtractMateria") and ExtractMateria and CanExtractMateria(100) and GetInventoryFreeSlotCount() > 1 then
        State = CharacterState.extractMateria
        LogInfo("[FATE] State Change: ExtractMateria")
    elseif not LogInfo("[FATE] Ready -> Wait10") and NextFate == nil and (WaitIfBonusBuff and (HasStatusId(1288) or HasStatusId(1289))) then
        State = CharacterState.flyBackToAethertye
        LogInfo("[FATE] State Change: FlyBackToAetheryte")
    elseif not LogInfo("[FATE] Ready -> ExchangingVouchers") and WaitingForCollectionsFate == 0 and ShouldExchangeBicolorVouchers and (BicolorGemCount >= 1400) then
        State = CharacterState.exchangingVouchers
        LogInfo("[FATE] State Change: ExchangingVouchers")
    elseif not LogInfo("[FATE] Ready -> ProcessRetainers") and WaitingForCollectionsFate == 0 and Retainers and ARRetainersWaitingToBeProcessed() and GetInventoryFreeSlotCount() > 1 then
        State = CharacterState.processRetainers
        LogInfo("[FATE] State Change: ProcessingRetainers")
    elseif not LogInfo("[FATE] Ready -> GC TurnIn") and GrandCompanyTurnIn and GetInventoryFreeSlotCount() < slots then
        State = CharacterState.gcTurnIn
        LogInfo("[FATE] State Change: GCTurnIn")
    elseif not LogInfo("[FATE] Ready -> TeleportBackToFarmingZone") and not IsInZone(SelectedZone.zoneId) then
        TeleportTo(SelectedZone.aetheryteList[1].aetheryteName)
        return
    elseif not LogInfo("[FATE] Ready -> ChangingInstances") and NextFate == nil then
        if EnableChangeInstance and GetZoneInstance() > 0 then
            State = CharacterState.changingInstances
            LogInfo("[FATE] State Change: ChangingInstances")
        else
            State = CharacterState.flyBackToAethertye
            LogInfo("[FATE] State Change: FlyBackToAetheryte")
            yield("/wait 10")
        end
        return
    elseif not LogInfo("[FATE] Ready -> MovingToFate") then -- and ((CurrentFate == nil) or (GetFateProgress(CurrentFate.fateId) == 100) and NextFate ~= nil) then
        CurrentFate = NextFate
        State = CharacterState.moveToFate
        LogInfo("[FATE] State Change: MovingtoFate "..CurrentFate.fateName)
    end

    if not GemAnnouncementLock and Echo >= 1 then
        GemAnnouncementLock = true
        if BicolorGemCount >= 1400 then
            yield("/echo [FATE] You're almost capped with "..tostring(BicolorGemCount).."/1500 gems! <se.3>")
        else
            yield("/echo [FATE] Gems: "..tostring(BicolorGemCount).."/1500")
        end
    end
end

DeathAnnouncementLock = false
function HandleDeath()
    CurrentFate = nil

    if CombatModsOn then
        TurnOffCombatMods()
    end

    if GetCharacterCondition(CharacterCondition.dead) then --Condition Dead
        if Echo and not DeathAnnouncementLock then
            DeathAnnouncementLock = true
            yield("/echo [FATE] You have died. Returning to home aetheryte.")
        end

        if IsAddonVisible("SelectYesno") then --rez addon yes
            yield("/callback SelectYesno true 0")
            yield("/wait 0.1")
        end
    else
        State = CharacterState.ready
        LogInfo("[FATE] State Change: Ready")
        DeathAnnouncementLock = false
    end
end

function ExchangeOldVouchers()
    if not IsInZone(962) then
        TeleportTo("Old Sharlayan")
        return
    end

    if PathfindInProgress() or PathIsRunning() then
        return
    end

    local gadfrid = { x=74.17, y=5.15, z=-37.44}
    if GetDistanceToPoint(gadfrid.x, gadfrid.y, gadfrid.z) > 5 then
        PathfindAndMoveTo(gadfrid.x, gadfrid.y, gadfrid.z)
    else
        if not HasTarget() or GetTargetName() ~= "Gadfrid" then
            yield("/target Gadfrid")
        elseif not GetCharacterCondition(CharacterCondition.occupiedShopkeeper) then
            yield("/interact")
        end
    end
end

function ExchangeNewVouchers()
    if not IsInZone(1186) then
        TeleportTo("Solution Nine")
        return
    end

    local beryl = { x=-198.47, y=0.92, z=-6.95 }
    local nexusArcade = { x=-157.74, y=0.29, z=17.43 }
    if GetDistanceToPoint(beryl.x, beryl.y, beryl.z) > (DistanceBetween(nexusArcade.x, nexusArcade.y, nexusArcade.z, beryl.x, beryl.y, beryl.z) + 10) then
        yield("/li nexus arcade")
        return
    elseif GetDistanceToPoint(beryl.x, beryl.y, beryl.z) > 5 then
        if IsAddonVisible("TelepotTown") then
            yield("/callback TelepotTown false -1")
        elseif not (PathfindInProgress() or PathIsRunning()) then
            PathfindAndMoveTo(beryl.x, beryl.y, beryl.z)
        end
    else
        if not HasTarget() or GetTargetName() ~= "Beryl" then
            yield("/target Beryl")
        elseif not GetCharacterCondition(CharacterCondition.occupiedShopkeeper) then
            yield("/interact")
        end
    end
end

function ExchangeVouchers()
    CurrentFate = nil

    if BicolorGemCount >= 1400 then
        if IsAddonVisible("SelectYesno") then
            yield("/callback SelectYesno true 0")
            return
        end

        if IsAddonVisible("ShopExchangeCurrency") then
            yield("/callback ShopExchangeCurrency false 0 5 "..(BicolorGemCount//100))
            return
        end

        if VoucherType == "Bicolor Gemstone Voucher" then
            ExchangeOldVouchers()
        else
            ExchangeNewVouchers()
        end
    else
        if IsAddonVisible("ShopExchangeCurrency") then
            yield("/callback ShopExchangeCurrency true -1")
            return
        end

        State = CharacterState.ready
        LogInfo("[FATE] State Change: Ready")
        return
    end
end

function ProcessRetainers()
    CurrentFate = nil

    LogInfo("[FATE] Handling retainers...")
    if ARRetainersWaitingToBeProcessed() and GetInventoryFreeSlotCount() > 1 then
    
        if PathfindInProgress() or PathIsRunning() then
            return
        end

        if not IsInZone(129) then
            yield("/vnav stop")
            TeleportTo("Limsa Lominsa Lower Decks")
            return
        end

        local summoningBell = {
            x = -122.72,
            y = 18.00,
            z = 20.39
        }
        if GetDistanceToPoint(summoningBell.x, summoningBell.y, summoningBell.z) > 4.5 then
            PathfindAndMoveTo(summoningBell.x, summoningBell.y, summoningBell.z)
            return
        end

        if not HasTarget() or GetTargetName() ~= "Summoning Bell" then
            yield("/target Summoning Bell")
            return
        end

        if not GetCharacterCondition(CharacterCondition.occupiedSummoningBell) then
            yield("/interact")
            if IsAddonVisible("RetainerList") then
                yield("/ays e")
                yield("/echo [FATE] Processing retainers")
                yield("/wait 1")
            end
        end
    else
        if IsAddonVisible("RetainerList") then
            yield("/callback RetainerList true -1")
        elseif not GetCharacterCondition(CharacterCondition.occupiedSummoningBell) then
            State = CharacterState.ready
            LogInfo("[FATE] State Change: Ready")
        end
    end
end

function GrandCompanyTurnIn()
    if GetInventoryFreeSlotCount() <= slots then
        local playerGC = GetPlayerGC()
        local gcZoneIds = {
            129, --Limsa Lominsa
            132, --New Gridania
            130 --"Ul'dah - Steps of Nald"
        }
        if not IsInZone(gcZoneIds[playerGC]) then
            yield("/li gc")
            yield("/wait 1")
        elseif DeliverooIsTurnInRunning() then
            return
        else
            yield("/deliveroo enable")
        end
    else
        State = CharacterState.ready
        LogInfo("State Change: Ready")
    end
end

function Repair()
    if IsAddonVisible("SelectYesno") then
        yield("/callback SelectYesno true 0")
        return
    end

    if IsAddonVisible("Repair") then
        if not NeedsRepair(RepairAmount) then
            yield("/callback Repair true -1") -- if you don't need repair anymore, close the menu
        else
            yield("/callback Repair true 0") -- select repair
        end
        return
    end

    -- if occupied by repair, then just wait
    if GetCharacterCondition(CharacterCondition.occupiedMateriaExtraction) then
        LogInfo("[FATE] Repairing...")
        yield("/wait 1")
        return
    end

    if SelfRepair then
        if GetCharacterCondition(CharacterCondition.mounted) then
            Dismount()
            LogInfo("[FATE] State Change: Dismounting")
            return
        end

        if NeedsRepair(RepairAmount) then
            if not IsAddonVisible("Repair") then
                LogInfo("[FATE] Opening repair menu...")
                yield("/generalaction repair")
            end
        else
            State = CharacterState.ready
            LogInfo("[FATE] State Change: Ready")
        end
    else
        if NeedsRepair(RepairAmount) then
            if not IsInZone(129) then
                TeleportTo("Limsa Lominsa Lower Decks")
                return
            end

            local mender = { npcName="Alistair", x=-246.87, y=16.19, z=49.83 }
            local aethernetshard = { x=-213.95, y=15.99, z=49.35 }
            if GetDistanceToPoint(mender.x, mender.y, mender.z) > (DistanceBetween(aethernetshard.x, aethernetshard.y, aethernetshard.z, mender.x, mender.y, mender.z) + 10) then
                yield("/li Hawkers' Alley")
            elseif GetDistanceToPoint(mender.x, mender.y, mender.z) > 5 then
                if IsAddonVisible("TelepotTown") then
                    yield("/callback TelepotTown false -1")
                elseif not (PathfindInProgress() or PathIsRunning()) then
                    PathfindAndMoveTo(mender.x, mender.y, mender.z)
                end
            else
                if not HasTarget() or GetTargetName() ~= mender.npcName then
                    yield("/target "..mender.npcName)
                elseif not GetCharacterCondition(CharacterCondition.occupiedShopkeeper) then
                    yield("/interact")
                end
            end
        else
            State = CharacterState.ready
            LogInfo("[FATE] State Change: Ready")
        end
    end
end

function ExtractMateria()
    if GetCharacterCondition(CharacterCondition.mounted) then
        Dismount()
        LogInfo("[FATE] State Change: Dismounting")
        return
    end

    if GetCharacterCondition(CharacterCondition.occupiedMateriaExtraction) then
        return
    end

    if CanExtractMateria(100) and GetInventoryFreeSlotCount() > 1 then
        if not IsAddonVisible("Materialize") then
            yield("/generalaction \"Materia Extraction\"")
            return
        end

        LogInfo("[FATE] Extracting materia...")
            
        if IsAddonVisible("MaterializeDialog") then
            yield("/callback MaterializeDialog true 0")
        else
            yield("/callback Materialize true 2 0")
        end
    else
        if IsAddonVisible("Materialize") then
            yield("/callback Materialize true -1")
        else
            State = CharacterState.ready
            LogInfo("[FATE] State Change: Ready")
        end
    end
end

CharacterState = {
    ready = Ready,
    dead = HandleDeath,
    unexpectedCombat = HandleUnexpectedCombat,
    mounting = Mount,
    npcDismount = NPCDismount,
    middleOfFateDismount = MiddleOfFateDismount,
    moveToFate = MoveToFate,
    interactWithNpc = InteractWithFateNpc,
    collectionsFateTurnIn = CollectionsFateTurnIn,
    doFate = DoFate,
    waitForContinuation = WaitForContinuation,
    changingInstances = ChangeInstance,
    changeInstanceDismount = ChangeInstanceDismount,
    flyBackToAethertye = FlyBackToAetheryte,
    extractMateria = ExtractMateria,
    repair = Repair,
    exchangingVouchers = ExchangeVouchers,
    processRetainers = ProcessRetainers,
    gcTurnIn = GrandCompanyTurnIn,
}

--#endregion State Transition Functions

--#region Main

GemAnnouncementLock = false
AvailableFateCount = 0
SuccessiveInstanceChanges = 0
LastInstanceChangeTimestamp = 0
MainClass = GetClassJobTableFromId(GetClassJobId())
BossFatesClass = nil
if ClassForBossFates ~= "" then
    BossFatesClass = GetClassJobTableFromAbbrev(ClassForBossFates)
end
SetMaxDistance()

local selectedZoneId = GetZoneID()
for i, zone in ipairs(FatesData) do
    if selectedZoneId == zone.zoneId then
        SelectedZone = zone
    end
end
if SelectedZone == nil then
    yield("/echo [FATE] Current zone is only partially supported. Will not teleport back on death or leaving.")
    SelectedZone = {
        zoneName = "Unknown Zone Name",
        zoneId = selectedZoneId,
        aetheryteList = {},
        fatesList= {
            collectionsFates= {},
            otherNpcFates= {},
            bossFates= {},
            blacklistedFates= {}
        }
    }
end

LastTeleportTimeStamp = 0
GotCollectionsFullCredit = false -- needs 7 items for  full credit
LastStuckCheckTime = os.clock()
LastStuckCheckPosition = {x=GetPlayerRawXPos(), y=GetPlayerRawYPos(), z=GetPlayerRawZPos()}
-- variable to track collections fates that you have completed but are still active.
-- will not leave area or change instance if value ~= 0
WaitingForCollectionsFate = 0
LastFateEndTime = os.clock()
State = CharacterState.ready
CurrentFate = nil
SingleTargetForlornMode = false
if IsInFate() and GetFateProgress(GetNearestFate()) < 100 then
    CurrentFate = BuildFateTable(GetNearestFate())
end

LogInfo("[FATE] Starting fate farming script.")
while true do
    if NavIsReady() then
        if State ~= CharacterState.dead and GetCharacterCondition(CharacterCondition.dead) then
            State = CharacterState.dead
            LogInfo("[FATE] State Change: Dead")
            if TargetingSystem == "Pandora" then
                PandoraSetFeatureState("FATE Targeting Mode", false)
            end
        elseif State ~= CharacterState.unexpectedCombat and State ~= CharacterState.doFate
            and State ~= CharacterState.waitForContinuation and not IsInFate() and
            GetCharacterCondition(CharacterCondition.inCombat) and not GetCharacterCondition(CharacterCondition.mounted)
        then
            State = CharacterState.unexpectedCombat
            LogInfo("[FATE] State Change: UnexpectedCombat")
        end
        
        BicolorGemCount = GetItemCount(26807)

        if not (IsPlayerCasting() or
            GetCharacterCondition(CharacterCondition.betweenAreas) or
            GetCharacterCondition(CharacterCondition.jumping48) or
            GetCharacterCondition(CharacterCondition.jumping61) or
            GetCharacterCondition(CharacterCondition.mounting57) or
            GetCharacterCondition(CharacterCondition.mounting64) or
            GetCharacterCondition(CharacterCondition.beingmoved70) or
            GetCharacterCondition(CharacterCondition.beingmoved75) or
            GetCharacterCondition(CharacterCondition.occupiedMateriaExtraction) or
            LifestreamIsBusy())
        then
            if WaitingForCollectionsFate ~= 0 and not IsFateActive(WaitingForCollectionsFate) then
                WaitingForCollectionsFate = 0
            end
            State()
        end
    end
    yield("/wait 0.1")
end

--#endregion Main