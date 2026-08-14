local ADDON_NAME, MiniCompanion = ...

-- ===========================================================================
-- Auswahl des permanenten Pets aus dem Pet-Journal-UI
-- ===========================================================================
--
-- Zwei Pfade:
--   1) Rematch installiert  -> Eintrag im nativen Rematch-Rechtsklick-Menü
--      (öffentliche API Rematch.menus:AddToMenu).
--   2) Sonst Blizzard-Pet-Journal -> Marker-Overlay + Alt+Klick-Geste.
-- Die Kern-Logik in Core.lua ist von beidem unabhängig.

local MARKER_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"

-- nur besessene Pets haben eine BattlePet-GUID und sind beschwörbar
local function IsOwnedPetID(petID)
    return type(petID) == "string" and petID:match("^BattlePet%-") ~= nil
end

-- ---------------------------------------------------------------------------
-- Pfad 1: Rematch
-- ---------------------------------------------------------------------------

-- aktualisiert die Rematch-Pet-Liste, damit Marker sofort neu gezeichnet werden
function MiniCompanion.RefreshRematchList()
    if Rematch and Rematch.frame and Rematch.frame.Update then
        Rematch.frame:Update()
    end
end

-- hängt ein Marker-Overlay an einen Rematch-List-Button-Mixin
local function HookListMarker(mixin)
    if not mixin or not mixin.Fill or mixin.mcMarkerHooked then return end
    mixin.mcMarkerHooked = true
    hooksecurefunc(mixin, "Fill", function(self, petID)
        if not self.mcMark then
            local mark = self:CreateTexture(nil, "OVERLAY", nil, 7)
            mark:SetTexture(MARKER_TEXTURE)
            mark:SetSize(14, 14)
            -- unten links, damit der Favoriten-Stern (oben links) frei bleibt
            mark:SetPoint("BOTTOMLEFT", self.Icon, "BOTTOMLEFT", 1, 1)
            self.mcMark = mark
        end
        self.mcMark:SetShown(MiniCompanion.IsPermanentPet(petID))
    end)
end

local function SetupRematch()
    if MiniCompanion._rematchMenuAdded then return end
    if not Rematch or not Rematch.menus then return end
    -- PetMenu wird von Rematch erst bei PLAYER_LOGIN registriert.
    local ok, def = pcall(function() return Rematch.menus:GetDefinition("PetMenu") end)
    if not ok or type(def) ~= "table" then return end

    -- direkt in die Definition einfügen (AddToMenu erlaubt keinen Spacer),
    -- damit unter dem Eintrag etwas Abstand entsteht
    local index = (def[1] and def[1].title) and 2 or 1
    table.insert(def, index, {
        text = function(info, petID)
            return MiniCompanion.IsPermanentPet(petID)
                and "Don't Keep Out Permanently"
                or "Keep Out Permanently"
        end,
        hidden = function(info, petID)
            return not IsOwnedPetID(petID)
        end,
        func = function(info, petID)
            MiniCompanion.TogglePermanentPet(petID)
        end,
    })
    table.insert(def, index + 1, { spacer = true })

    HookListMarker(RematchNormalPetListButtonMixin)
    HookListMarker(RematchCompactPetListButtonMixin)

    MiniCompanion._rematchMenuAdded = true
end

-- ---------------------------------------------------------------------------
-- Pfad 2: Blizzard-Pet-Journal (Marker + Alt+Klick)
-- ---------------------------------------------------------------------------

local function EnsureMarker(button)
    if button.mcMark then return button.mcMark end
    local mark = button:CreateTexture(nil, "OVERLAY", nil, 7)
    mark:SetTexture(MARKER_TEXTURE)
    mark:SetSize(16, 16)
    mark:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    mark:Hide()
    button.mcMark = mark
    return mark
end

local function HookButtonOnce(button)
    if button.mcHooked then return end
    button.mcHooked = true
    button:HookScript("OnClick", function(self)
        if IsAltKeyDown() and self.petID then
            MiniCompanion.TogglePermanentPet(self.petID)
        end
    end)
end

function MiniCompanion.RefreshMarkers()
    if not PetJournal or not PetJournal.ScrollBox then return end
    local permanent = MiniCompanion.GetPermanentPet()
    for _, button in ipairs(PetJournal.ScrollBox:GetFrames()) do
        if button.petID then
            HookButtonOnce(button)
            local mark = EnsureMarker(button)
            if button.petID == permanent then
                mark:Show()
            else
                mark:Hide()
            end
        elseif button.mcMark then
            button.mcMark:Hide()
        end
    end
end

local function SetupBlizzard()
    if not PetJournal or not PetJournal.ScrollBox then return end
    PetJournal.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnUpdate, function()
        MiniCompanion.RefreshMarkers()
    end, MiniCompanion)
    PetJournal:HookScript("OnShow", function()
        MiniCompanion.RefreshMarkers()
    end)
    MiniCompanion.RefreshMarkers()
end

-- ---------------------------------------------------------------------------
-- Initialisierung
-- ---------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", SetupBlizzard)

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    -- 0-Delay stellt sicher, dass Rematchs eigener PLAYER_LOGIN-Handler
    -- (der PetMenu registriert) bereits gelaufen ist.
    C_Timer.After(0, SetupRematch)
end)
