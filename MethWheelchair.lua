MethWheelchair = {}


local ShouldUnbind = false
local PreviousPostion_X = 0
local PreviousPosition_Y = 0
local ShackleCastTime = 0
local Unbound = false


local MovementTypes = {
    "MOVEFORWARD",
    "MOVEBACKWARD",
    "TURNLEFT",
    "TURNRIGHT",
    "STRAFELEFT",
    "STRAFERIGHT",
}

local Keybinds = {}

for k, mt in MovementTypes do
    Keybinds[mt] = {}
end

local function Print(msg, r, g, b, a)
    return DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b, a)
end

-- keybinds saved in addon memory
local function PrintKeybinds()
    Print("\124cff4488ffMovement configuration\124r:")
    for mt, keybind in Keybinds do

        local key1 = nil
        if (keybind[1]) then
            key1 = "\124cff11ff11"..tostring(keybind[1]).."\124r"
        else
            key1 = "\124cffff0000"..tostring(keybind[1]).."\124r"
        end

        local key2 = nil
        if (keybind[2]) then
            key2 = "\124cff11ff11"..tostring(keybind[2]).."\124r"
        else
            key2 = "\124cffff0000"..tostring(keybind[2]).."\124r"
        end

        Print("\124cff4488ff"..mt.."\124r: key1: "..key1.."; key2: "..key2)
    end
end

local function SaveKeybinds()
    --Print("Movement configuration:")
    for k, mt in MovementTypes do
        local key1, key2 = GetBindingKey(mt)
        Keybinds[mt][1] = key1
        Keybinds[mt][2] = key2
        --Print("key1: \124cff00ff00"..tostring(keybind[1]).."\124r key2: \124cff00ff00"..tostring(keybind[2]).."\124r")
    end
    PrintKeybinds()
end

-- keybinds in use by game 
local function PrintCurrentKeybinds()
    for k, mt in MovementTypes do
        local key1, key2 = GetBindingKey(mt)
        Print(mt..": key1: "..tostring(key1).." key2: "..tostring(key2))
    end
end

local function UnbindAllKeybinds()
    for mt, keybind in Keybinds do
        if (keybind[1]) then
            SetBinding(keybind[1], nil)
        end
        if (keybind[2]) then
            SetBinding(keybind[2], nil)
        end
    end

    --MoveForwardStop() -- blocked

    for k, mt in MovementTypes do
        local key1, key2 = GetBindingKey(mt)
        if (key1) then
            Print("Failed to unbind key: "..tostring(key1))
        end
    end

    Unbound = true
end

local function RestoreKeybinds()
    for mt, keybind in Keybinds do
        if (keybind[1]) then
            SetBinding(keybind[1], mt)
        end
        if (keybind[2]) then
            SetBinding(keybind[2], mt)
        end
    end

    Unbound = false
end



function MethWheelchair.Unbind(castDuration)
    ShackleCastTime = GetTime() + (castDuration or 0)
    ShouldUnbind = true
end

function MethWheelchair.PrintKeybinds()
    PrintKeybinds()
end

function MethWheelchair.PrintCurrentKeybinds()
    PrintCurrentKeybinds()
end

function MethWheelchair.Restore()
    ShouldUnbind = false
    RestoreKeybinds()
end


local EventFrame = CreateFrame("FRAME")

--EventFrame:RegisterEvent("VARIABLES_LOADED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
EventFrame:RegisterEvent("UNIT_CASTEVENT")

EventFrame:SetScript("OnEvent", function()
    if (event == "PLAYER_ENTERING_WORLD") then
        --Print("player entering world")
        SaveKeybinds()
    elseif (event == "CHAT_MSG_SPELL_AURA_GONE_SELF") then
        if (--arg1 == "Frost Armor fades from you." or
            arg1 == "Shackles of the Legion fades from you." or
            arg1 == "Shackles of the Legion fades from "..tostring(UnitName("PLAYER"))
        ) then
            MethWheelchair.Restore()
            Print("Movement \124cff00ff00restored\124r.")
        end

    elseif (event == "UNIT_CASTEVENT") then
        local casterGUID = arg1
        local targetGUID = arg2
        local event = arg3
        local spellID = arg4
        local castDuration = arg5
        --local _, playerGUID = UnitExists("PLAYER")
        --local playerName = UnitName("PLAYER")

        if (event == "CAST" and (
            spellID == 51916 -- Shackles of the Legion
            --or spellID == 168 -- Frost Armor (Rank 1) (test)
        )) then
            MethWheelchair.Unbind(castDuration)
        end
    end
end)


local function TryUnbind(px, py)
    -- stand still
    if (px == PreviousPosition_X and py == PreviousPosition_Y) then
        if (ShouldUnbind) then
            Print("Movement \124cffff0000disabled\124r.")
            UnbindAllKeybinds()
            ShouldUnbind = false
        end
    end

    PreviousPosition_X = px
    PreviousPosition_Y = py
    
end

EventFrame:SetScript("OnUpdate", function()
    -- check if player is moving and try to unbind keybinds if scheduled
    if (SUPERWOW_VERSION) then
        local px, py = UnitPosition("PLAYER")
        TryUnbind(px, py)

    -- non superwow position but still need to know when cast starts 
    else
        local px, py = GetPlayerMapPosition("PLAYER")
        TryUnbind(px, py)
    end

    local currentTime = GetTime()
    -- debuff lasts 6 sec, 0.5 sec for error
    if (Unbound and (currentTime > ShackleCastTime + 6.5)) then
        MethWheelchair.Restore()
        Print("Movement \124cff00ff00restored\124r.")
    end
end)



