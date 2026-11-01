-- The Forever client (Interface 16001, game type "camelot"/"forever") as far as the probes of its beta told:
-- a Mainline-family client. The functions only the Classic clients had are gone, their C_ forms are there,
-- and payloads can be secret (issecretvalue). Loaded after mock.lua, by checks.js (the simulated session run
-- again with this profile) and by regressions.js (FOREVER). It is a simulation, not the game.
WOW_PROJECT_ID = 18
WOW_PROJECT_CAMELOT = 18
WOW_PROJECT_MAINLINE = 1

FOREVER_SECRET = FOREVER_SECRET or {}
function issecretvalue(v) return FOREVER_SECRET[v] == true end

for _, name in ipairs({
  "GetQuestLogTitle", "GetNumQuestLogEntries", "GetQuestLogQuestText", "GetFactionInfo", "GetNumFactions",
  "GetSpellInfo", "GetItemInfo", "GetItemInfoInstant", "GetNumCompanions", "SendAddonMessage",
  "RegisterAddonMessagePrefix", "GetAddOnMetadata", "IsAddOnLoaded", "GetQuestsCompleted",
  "GetPetHappiness", "GetPetTrainingPoints", "GetPetFoodTypes", "GetPetExperience",
  "CombatLogGetCurrentEventInfo", "GetSpecialization", "GetSpecializationInfo",
}) do _G[name] = nil end

C_PetInfo = C_PetInfo or {}
C_PetInfo.GetPetFoodTypes = function() return "Meat", "Fish" end

FOREVER_FACTIONS = FOREVER_FACTIONS or {
  { name = "Stormwind", reaction = 4 }, { name = "Alliance", isHeader = true }, { name = "Darnassus", reaction = 5 },
}
C_Reputation = {
  GetNumFactions = function() return #FOREVER_FACTIONS end,
  GetFactionDataByIndex = function(i) return FOREVER_FACTIONS[i] end,
}
C_AddOns = {
  GetAddOnMetadata = function(_, key) if key == "Version" then return "test" end return nil end,
  IsAddOnLoaded = function() return false end,
}
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return true end,
  IsAddonMessagePrefixRegistered = function() return true end,
  SendAddonMessage = function() return 0 end,
}
C_Spell = { GetSpellName = function(id) return "Spell " .. tostring(id) end }
C_Item = C_Item or {}
C_Item.GetItemInfoInstant = C_Item.GetItemInfoInstant or function(id) return tonumber(tostring(id):match("%d+")), "Armor", "Cloth", "INVTYPE_CHEST", 134400, 4, 1 end
C_Item.GetItemNameByID = C_Item.GetItemNameByID or function() return nil end
C_Secrets = { HasSecretRestrictions = function() return true end }
function GetMaxPlayerLevel() return 60 end
function GetBuildInfo() return "1.60.1", "70374", "Oct 15 2026", 16001 end
