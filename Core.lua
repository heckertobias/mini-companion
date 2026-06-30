local ADDON_NAME, MiniCompanion = ...
_G.MiniCompanion = MiniCompanion

-- ===========================================================================
-- SavedVariables / Auswahl des permanenten Pets
-- ===========================================================================

local function EnsureDB()
    if type(MiniCompanionDB) ~= "table" then
        MiniCompanionDB = {}
    end
    return MiniCompanionDB
end

function MiniCompanion.GetPermanentPet()
    return EnsureDB().permanentPetGUID
end

function MiniCompanion.IsPermanentPet(guid)
    return guid ~= nil and EnsureDB().permanentPetGUID == guid
end

local function RefreshUI()
    if MiniCompanion.RefreshMarkers then
        MiniCompanion.RefreshMarkers()
    end
    if MiniCompanion.RefreshRematchList then
        MiniCompanion.RefreshRematchList()
    end
end

function MiniCompanion.SetPermanentPet(guid)
    EnsureDB().permanentPetGUID = guid
    RefreshUI()
    MiniCompanion.TryResummon()
end

function MiniCompanion.ClearPermanentPet()
    EnsureDB().permanentPetGUID = nil
    RefreshUI()
end

-- Toggle, von der Pet-Journal-UI genutzt.
function MiniCompanion.TogglePermanentPet(guid)
    if not guid then return end
    if MiniCompanion.IsPermanentPet(guid) then
        MiniCompanion.ClearPermanentPet()
    else
        MiniCompanion.SetPermanentPet(guid)
    end
end

-- ===========================================================================
-- Re-Summon-Logik
-- ===========================================================================

local THROTTLE = 0.5
local lastTry = 0

function MiniCompanion.TryResummon()
    local guid = MiniCompanion.GetPermanentPet()
    if not guid then return end

    -- GUID muss noch im Pet Journal existieren.
    if not C_PetJournal.GetPetInfoByPetID(guid) then return end

    -- Guards: nicht im Kampf, nicht tot/Geist, nicht beim Reiten.
    if InCombatLockdown() or UnitIsDeadOrGhost("player") or IsMounted() then
        return
    end

    if C_PetJournal.GetSummonedPetGUID() ~= guid then
        C_PetJournal.SummonPetByGUID(guid)
    end
end

local function OnStartedMoving()
    local now = GetTime()
    if now - lastTry < THROTTLE then return end
    lastTry = now
    MiniCompanion.TryResummon()
end

-- ===========================================================================
-- Events
-- ===========================================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_STARTED_MOVING")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            EnsureDB()
        end
    elseif event == "PLAYER_STARTED_MOVING" then
        OnStartedMoving()
    end
end)

-- ===========================================================================
-- Slash-Befehl (Diagnose / Fallback)
-- ===========================================================================

SLASH_MINICOMPANION1 = "/mc"
SlashCmdList["MINICOMPANION"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "clear" then
        MiniCompanion.ClearPermanentPet()
        print("|cff66ccffMini-Companion|r: permanent pet cleared.")
    elseif msg == "status" then
        local guid = MiniCompanion.GetPermanentPet()
        if guid then
            local _, customName, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(guid)
            print("|cff66ccffMini-Companion|r: permanent pet = " .. (customName or name or guid))
        else
            print("|cff66ccffMini-Companion|r: no permanent pet set.")
        end
    else
        print("|cff66ccffMini-Companion|r: /mc status | /mc clear")
        print("Keep a pet out: right-click a pet in Rematch -> 'Keep Out Permanently'")
        print("(without Rematch: Alt+click a pet in the Pet Journal).")
    end
end
