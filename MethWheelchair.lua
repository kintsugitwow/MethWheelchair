MethWheelchair = {}
mw = MethWheelchair

BINDING_HEADER_METHWHEELCHAIR = "MethWheelchair"
local ADDON_PREFIX = "METHWHEELCHAIR"
local ADDON_VERSION = 1.02

local CONFIG_DEFAULT_VALUE = {
    LOGIN_INFO = true, -- display in chat window
    BLOCK_LMB = true, -- blocks moving my pressing both mouse buttons but disables Left Mouse Button clicks in world - only registered by UI - can't target enemies by clicking models, do it by clicking nameplates or tab target
    SUPER_WOW = true, -- use superwow functions, (as for now most important for position)
    UNIT_CASTEVENT = false, -- combat log should be better
    INCLUDE_START_EVENT = false, -- just anoying, player should know when to stop moving, not block him 2 sec before
    -- silent debug
    LISTEN = true,
    -- saved stats for debug
    TOTAL_TRIGGER_COUNT = 0,
    TOTAL_MAP_POSITION_FAILS = 0,
    TOTAL_MAP_POSITION_CRITICAL_FAILS = 0,
}

-- assign default values on VARIABLES_LOADED event if nil
METHWHEELCHAIR_CONFIG = {}

local SettingKeys = {
    ["logininfo"] = "LOGIN_INFO",
    ["blocklmb"] = "BLOCK_LMB",
    ["superwow"] = "SUPER_WOW",
    ["unitcastevent"] = "UNIT_CASTEVENT",
    ["includestartevent"] = "INCLUDE_START_EVENT",
    ["listen"] = "LISTEN",
    ["totaltriggercount"] = "TOTAL_TRIGGER_COUNT",
    ["totalmappositionfails"] = "TOTAL_MAP_POSITION_FAILS",
    ["totalmappositioncriticalfails"] = "TOTAL_MAP_POSITION_CRITICAL_FAILS",
}

local ShouldUnbind = false
local Unbound = false
local PreviousPosition_X = 0
local PreviousPosition_Y = 0
local ShackleCastTime = 0
local Stats = {
    TriggerCount = 0,
    MapPositionFails = 0,
    MapPositionCriticalFails = 0,
}

local SpellTriggers = {
    "Shackles of the Legion",
    --"Weakened Soul", -- (test)
}

local MovementTypes = {
    "MOVEFORWARD",
    "MOVEBACKWARD",
    "TURNLEFT",
    "TURNRIGHT",
    "STRAFELEFT",
    "STRAFERIGHT",
    "MOVEANDSTEER",
    "TOGGLEAUTORUN",
    "CAMERAORSELECTORMOVE", -- safer way to block left mouse button, BLOCK_LMB setting handled in unbind handler
}

local Keybinds = {}

for k, mt in MovementTypes do
    Keybinds[mt] = {}
end

-- hook
--local old_CameraOrSelectOrMoveStart = CameraOrSelectOrMoveStart

local strfind = string.find
local strlower = string.lower

local VersionCheckTimeLimit = nil
local VersionCheckRepliers = {}

local function Print(msg, r, g, b, a)
    return DEFAULT_CHAT_FRAME:AddMessage("\124cffffffff[\124r\124cffa044b9MethWheelchair\124r\124cffffffff]:\124r "..tostring(msg), r, g, b, a)
end


local function GetClassColor(unit)
	local _, class = UnitClass(unit)
	if (class == "DRUID") then return "FF7C0A" end
	if (class == "HUNTER") then return "AAD372" end
	if (class == "MAGE") then return "3FC7EB" end
	if (class == "PALADIN") then return "F48CBA" end
	if (class == "PRIEST") then return "FFFFFF" end
	if (class == "ROGUE") then return "FFF468" end
	if (class == "SHAMAN") then return "0070DD" end
	if (class == "WARLOCK") then return "8788EE" end
	if (class == "WARRIOR") then return "C69B6D" end
    return "FFFFFF"
end


local function InitSetting(setting)
    if (METHWHEELCHAIR_CONFIG[setting] == nil) then
        if (CONFIG_DEFAULT_VALUE[setting] == nil) then
            Print("\124cffff0000Setting '"..tostring(setting).."'doesnt exist!\124r")
            return false
        end

        METHWHEELCHAIR_CONFIG[setting] = CONFIG_DEFAULT_VALUE[setting]
    end
    return true
end


local function PrintVersion()
    Print("Version: "..tostring(ADDON_VERSION))
end


-- by default keybinds saved in addon memory
local function PrintKeybinds(keybinds)
    Print("\124cff4488ffMovement configuration\124r:")

    if (not keybinds) then
        keybinds = Keybinds
    end

    for mt, keybind in keybinds do

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

        Print("\124cff4488ff"..mt.."\124r: key1: "..key1..", key2: "..key2)
    end
end
MethWheelchair.PrintKeybinds = PrintKeybinds


-- save keybinds in addon memory
local function SaveKeybinds(show)
    if (show == nil) then
        show = true
    end

    for k, mt in MovementTypes do
        local key1, key2 = GetBindingKey(mt)
        Keybinds[mt][1] = key1
        Keybinds[mt][2] = key2
    end

    if (show) then
        PrintKeybinds()
    end
end


-- keybinds in use by game 
local function PrintCurrentKeybinds()
    for k, mt in MovementTypes do
        local key1, key2 = GetBindingKey(mt)
        Print(mt..": key1: "..tostring(key1)..", key2: "..tostring(key2))
    end
end


-- affects game settings
local function UnbindAllKeybinds()
    local replacementActionId = 1
    for mt, keybind in Keybinds do

        if (
            (mt == "CAMERAORSELECTORMOVE" and METHWHEELCHAIR_CONFIG.BLOCK_LMB == false)
        ) then
            -- continue...
        else
            -- unbind
            if (keybind[1]) then
                SetBinding(keybind[1], "METHWHEELCHAIR_REPLACEMENT_ACTION_"..tostring(replacementActionId))
            end
            if (keybind[2]) then
                SetBinding(keybind[2], "METHWHEELCHAIR_REPLACEMENT_ACTION_"..tostring(replacementActionId))
            end
            replacementActionId = replacementActionId + 1
        end
    end

    --MoveForwardStop() -- protected function, blocked

    for k, mt in MovementTypes do
        local key1, key2 = GetBindingKey(mt)

        if (
            (mt == "CAMERAORSELECTORMOVE" and METHWHEELCHAIR_CONFIG.BLOCK_LMB == false)
        ) then
            -- continue...
        else
            -- check fail
            if (key1) then
                Print("\124cffffbb00Failed to unbind key: \124r"..tostring(key1))
            end
        end
    end

    Unbound = true
end


local function RestoreKeybinds()
    for mt, keybind in Keybinds do
        --if (mt == "MOVEANDSTEER" and METHWHEELCHAIR_CONFIG.BLOCK_LMB) then
        --    -- do nothing, otherwise protected function error pops up
        --    -- because blocking Left Mouse Button involves hooking and reassigning semi-protected function
        --else
            if (keybind[1]) then
                SetBinding(keybind[1], mt)
            end
            if (keybind[2]) then
                SetBinding(keybind[2], mt)
            end
        --end
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


function MethWheelchair.ReplacementAction()
    SpellStopCasting()
    METHWHEELCHAIR_CONFIG.TOTAL_TRIGGER_COUNT = METHWHEELCHAIR_CONFIG.TOTAL_TRIGGER_COUNT + 1
    Stats.TriggerCount = Stats.TriggerCount + 1
end


local function MsgArgs(msg, argCount, separator)
    if (not separator) then
        separator = " "
    end

	if (not argCount) then
		argCount = 1
	end

    msg = msg..separator
    argCount = argCount + 1

	local args = {}
	local i = 1

	while i < argCount do
		local _, stop = strfind(msg, separator)
		if (stop) then
			args[i] = strsub(msg, 1, stop - 1)
			msg = strsub(msg, stop + 1)
		end
		i = i + 1
	end
	args[i] = msg

	if (not args[1]) then
		args[1] = args[i]
	end

	return args
end



-------------------------------------------------------------------------------------------
---------------------------------------- EVENTS -------------------------------------------
-------------------------------------------------------------------------------------------



local EventFrame = CreateFrame("FRAME")
local EventHandlers = {}

local function RegisterEvent(event, handler)
    if (not handler) then
        Print("Handler for event "..event.." is nil!")
        return
    end
    EventHandlers[event] = handler
    EventFrame:RegisterEvent(event)
end

local function UnregisterEvent(event)
    EventHandlers[event] = nil
    EventFrame:UnregisterEvent(event)
end

EventFrame:SetScript("OnEvent", function()
    EventHandlers[event]()
end)




-- VARIABLES_LOADED
RegisterEvent("VARIABLES_LOADED",
function()
    UnregisterEvent("VARIABLES_LOADED")

    -- ensure compatibility between previous versions
    for settingName, settingValue in CONFIG_DEFAULT_VALUE do
        InitSetting(settingName)
    end

    if ((not SUPERWOW_VERSION) or 
        (not METHWHEELCHAIR_CONFIG.SUPER_WOW) or
        (not METHWHEELCHAIR_CONFIG.UNIT_CASTEVENT)
    ) then
        UnregisterEvent("UNIT_CASTEVENT")
    end

    if ((not METHWHEELCHAIR_CONFIG.LISTEN)) then
        UnregisterEvent("CHAT_MSG_ADDON")
    end
end)


-- PLAYER_ENTERING_WORLD
RegisterEvent("PLAYER_ENTERING_WORLD",
function()
    UnregisterEvent("PLAYER_ENTERING_WORLD")
    local loginInfo = METHWHEELCHAIR_CONFIG.LOGIN_INFO

    if (loginInfo) then
        PrintVersion()
    end

    SaveKeybinds(loginInfo)

    if (loginInfo) then
        if (METHWHEELCHAIR_CONFIG.BLOCK_LMB) then
            Print("Blocking Left Mouse Button is \124cff00ff00enabled\124r.")
        else
            Print("Blocking Left Mouse Button is \124cffff0000disabled\124r.")
        end
    end
end)


-- CHAT_MSG_SPELL_AURA_GONE_SELF
RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF",
function()
    for k, spell in SpellTriggers do
        if (
            strfind(arg1, spell.." fades from you") or
            strfind(arg1, spell.." fades from "..tostring(UnitName("PLAYER")))
        ) then
            MethWheelchair.Restore()
            Print("Movement \124cff00ff00restored\124r.")
        end
    end
end)


-- CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE
RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE",
function()
    for k, spell in SpellTriggers do
        if (
            strfind(arg1, "You are afflicted by "..spell) or
            strfind(arg1, UnitName("PLAYER").." is afflicted by "..spell)
        ) then
            MethWheelchair.Unbind(0)
        end
    end
end)


-- UNIT_CASTEVENT
RegisterEvent("UNIT_CASTEVENT",
function()
    local casterGUID = arg1
    local targetGUID = arg2
    local eventType = arg3
    local spellID = arg4
    local castDuration = arg5

    if (METHWHEELCHAIR_CONFIG.INCLUDE_START_EVENT and
        eventType == "START" and (
        spellID == 51916 -- Shackles of the Legion
        --or spellID == 168 -- Frost Armor (Rank 1) (test)
    )) then
        MethWheelchair.Unbind(castDuration)
    end

    if (eventType == "CAST" and (
        spellID == 51916 -- Shackles of the Legion
        --or spellID == 168 -- Frost Armor (Rank 1) (test)
    )) then
        MethWheelchair.Unbind(0)
    end
end)


-- CHAT_MSG_ADDON
RegisterEvent("CHAT_MSG_ADDON",
function()
    if (arg1 == ADDON_PREFIX) then
        local args = MsgArgs(arg2, 10, ";")

        if (args[1] == "query") then

            if (args[3] == "version") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local version = tostring(ADDON_VERSION)

                local msg = "answer;"..requester..";version;"..name..";"..version..";"
                SendAddonMessage(ADDON_PREFIX, msg, "RAID")
            end

            if (args[3] == "superwowversion") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local version = tostring(SUPERWOW_VERSION)

                local msg = "answer;"..requester..";superwowversion;"..name..";"..version..";"
                SendAddonMessage(ADDON_PREFIX, msg, "RAID")
            end

            if (args[3] == "setting") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local setting = args[4]
                local settingValue = METHWHEELCHAIR_CONFIG[SettingKeys[args[4]]]

                local msg = "answer;"..requester..";setting;"..name..";"..setting..";"..tostring(settingValue)..";"
                SendAddonMessage(ADDON_PREFIX, msg, "RAID")
            end

            if (args[3] == "triggercount") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local triggerCount = tostring(Stats.TriggerCount)

                local msg = "answer;"..requester..";triggercount;"..name..";"..triggerCount..";"
                SendAddonMessage(ADDON_PREFIX, msg, "RAID")
            end

            if (args[3] == "triggercounttotal") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local totalTriggerCount = tostring(METHWHEELCHAIR_CONFIG.TOTAL_TRIGGER_COUNT)

                local msg = "answer;"..requester..";triggercounttotal;"..name..";"..totalTriggerCount..";"
                SendAddonMessage(ADDON_PREFIX, msg, "RAID")
            end

            if (args[3] == "mappositionfails") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local mapPositionFails = tostring(Stats.MapPositionFails)

                local msg = "answer;"..requester..";mappositionfails;"..name..";"..mapPositionFails..";"
                SendAddonMessage(ADDON_PREFIX, msg, "RAID")
            end

            if (args[3] == "mappositioncriticalfails") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local mapPositionCriticalFails = tostring(Stats.MapPositionCriticalFails)

                local msg = "answer;"..requester..";mappositioncriticalfails;"..name..";"..mapPositionCriticalFails..";"
                SendAddonMessage(ADDON_PREFIX, msg, "RAID")
            end

            if (args[3] == "mappositionfailstotal") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local mapPositionFailsTotal = tostring(METHWHEELCHAIR_CONFIG.TOTAL_MAP_POSITION_FAILS)

                local msg = "answer;"..requester..";mappositionfailstotal;"..name..";"..mapPositionFailsTotal..";"
                SendAddonMessage(ADDON_PREFIX, msg, "RAID")
            end

            if (args[3] == "mappositioncriticalfailstotal") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local mapPositionCriticalFailsTotal = tostring(METHWHEELCHAIR_CONFIG.TOTAL_MAP_POSITION_CRITICAL_FAILS)

                local msg = "answer;"..requester..";mappositioncriticalfailstotal;"..name..";"..mapPositionCriticalFailsTotal..";"
                SendAddonMessage(ADDON_PREFIX, msg, "RAID")
            end


        elseif (args[1] == "answer" and args[2] == UnitName("PLAYER")) then

            if (args[3] == "version") then
                local sender = args[4]
                local version = args[5]
                VersionCheckRepliers[sender] = version
                if (tonumber(version) < ADDON_VERSION) then
                    version = "\124cffff0000"..version.."\124r"
                else
                    version = "\124cff00ff00"..version.."\124r"
                end

                Print("Version check: "..sender..": "..version)
            end

            if (args[3] == "superwowversion") then
                local sender = args[4]
                local version = args[5]
                VersionCheckRepliers[sender] = version
                if ((not tonumber(version)) or (not SUPERWOW_VERSION)) then
                    version = "\124cffff0000"..version.."\124r"
                elseif (tonumber(version) < tonumber(SUPERWOW_VERSION)) then
                    version = "\124cffff0000"..version.."\124r"
                else
                    version = "\124cff00ff00"..version.."\124r"
                end

                Print("SuperWoW version check: "..sender..": "..version)
            end

            if (args[3] == "setting") then
                local sender = args[4]
                local setting = args[5]
                local settingValue = args[6]
                Print("Setting ("..setting.."): "..sender..": "..settingValue)
            end

            if (args[3] == "triggercount") then
                local sender = args[4]
                local value = args[5]
                Print("Trigger count: "..sender..": "..value)
            end

            if (args[3] == "triggercounttotal") then
                local sender = args[4]
                local value = args[5]
                Print("Total trigger count: "..sender..": "..value)
            end

            if (args[3] == "mappositionfails") then
                local sender = args[4]
                local value = args[5]
                Print("Map position fails: "..sender..": "..value)
            end

            if (args[3] == "mappositioncriticalfails") then
                local sender = args[4]
                local value = args[5]
                Print("Map position critical fails: "..sender..": "..value)
            end

            if (args[3] == "mappositionfailstotal") then
                local sender = args[4]
                local value = args[5]
                Print("Total map position fails: "..sender..": "..value)
            end

            if (args[3] == "mappositioncriticalfailstotal") then
                local sender = args[4]
                local value = args[5]
                Print("Total map position critical fails: "..sender..": "..value)
            end

        end

    end
end)



-------------------------------------------------------------------------------------------
---------------------------------------- UPDATE -------------------------------------------
-------------------------------------------------------------------------------------------



local function TryUnbind(px, py)
    -- stand still
    if (px == PreviousPosition_X and py == PreviousPosition_Y) then
        if (ShouldUnbind) then
            Print("Movement \124cffff0000disabled\124r.")
            UnbindAllKeybinds()
            -- disable camera movement on left click,
            -- results in not being able to move using left and right mouse buttons
            --if (METHWHEELCHAIR_CONFIG.BLOCK_LMB) then
            --    CameraOrSelectOrMoveStart = function()
            --        -- try to do something similar to left click
            --        --TurnOrActionStart() -- fail - protected function
            --    end
            --end

            ShouldUnbind = false
        end
    end

    PreviousPosition_X = px
    PreviousPosition_Y = py
end


EventFrame:SetScript("OnUpdate", function()
    -- check if player is moving and try to unbind keybinds if scheduled
    if (SUPERWOW_VERSION and METHWHEELCHAIR_CONFIG.SUPER_WOW) then
        local px, py = UnitPosition("PLAYER")
        TryUnbind(px, py)

    -- non superwow position, hope map is correctly bound in ??? zone
    elseif (ShouldUnbind -- check to prevent lags while map is open, can result in one frame delay
            or (GetZoneText() == "???") -- even one frame is too long in boss fight, map shouldn't be open
        ) then
        local px, py = GetPlayerMapPosition("PLAYER")
        if ((not px) or (not py) or (px == 0 and py == 0)) then

            local prevContinent = GetCurrentMapContinent()
            local prevZone = GetCurrentMapZone()
            
            SetMapToCurrentZone()
            px, py = GetPlayerMapPosition("PLAYER")

            -- for some reason changing world map while it's open lags game a lot
            -- but it's better than not being able to use it at all
            SetMapZoom(prevContinent, prevZone)

            Stats.MapPositionFails = Stats.MapPositionFails + 1
            METHWHEELCHAIR_CONFIG.TOTAL_MAP_POSITION_FAILS = METHWHEELCHAIR_CONFIG.TOTAL_MAP_POSITION_FAILS + 1
        end

        if ((not px) or (not py) or (px == 0 and py == 0)) then
            Stats.MapPositionCriticalFails = Stats.MapPositionCriticalFails + 1
            METHWHEELCHAIR_CONFIG.TOTAL_MAP_POSITION_CRITICAL_FAILS = METHWHEELCHAIR_CONFIG.TOTAL_MAP_POSITION_CRITICAL_FAILS + 1
        end

        TryUnbind(px, py)
    end

    local currentTime = GetTime()
    -- debuff lasts 6 sec, 0.5 sec for error
    if (Unbound and (currentTime > ShackleCastTime + 6.5)) then
        MethWheelchair.Restore()
        Print("Movement \124cff00ff00restored\124r.")
    end

    if (VersionCheckTimeLimit and GetTime() > VersionCheckTimeLimit) then
        local didnotrespond = {}
        for i = 1, GetNumRaidMembers(), 1 do
            local unit = "RAID"..i
            local unitName = UnitName(unit)
            local found = false
            for sender, version in VersionCheckRepliers do
                if (sender == unitName) then
                    found = true
                    break
                end
            end
            if (not found) then
                tinsert(didnotrespond, "\124cff"..GetClassColor(unit)..unitName.."\124r")
            end
        end

        if (table.getn(didnotrespond) > 0) then
            local message = "Did not respond to version check: "
            for i = 1, table.getn(didnotrespond), 1 do
                message = message..didnotrespond[i]
                if (i ~= table.getn(didnotrespond)) then
                    message = message..", "
                end
            end
            Print(message..".")
        else
            Print("Everybody responded to version check.")
        end

        VersionCheckTimeLimit = nil
        VersionCheckRepliers = {}
    end
end)



-------------------------------------------------------------------------------------------
--------------------------------------- COMMANDS ------------------------------------------
-------------------------------------------------------------------------------------------



local function IsCmd(cmd, input)
	for k, v in cmd do
		if (v == input) then
			return true
		end
	end
	return false
end


local function CmdUnbind(msg)
    local cmd = { "unbind", "test", "u" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    MethWheelchair.Unbind(0)

    return true
end

local function CmdRestore(msg)
    local cmd = { "restore", "r" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    MethWheelchair.Restore()
    Print("Movement \124cff00ff00restored\124r.")

    return true
end

local function CmdKeybinds(msg)
    local cmd = { "keybinds", "k" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    MethWheelchair.PrintKeybinds()

    return true
end

local function CmdLoginInfo(msg)
    local cmd = { "logininfo", "l", "li", "login", "info" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    if (METHWHEELCHAIR_CONFIG.LOGIN_INFO == true) then
        METHWHEELCHAIR_CONFIG.LOGIN_INFO = false
        Print("Login info \124cffff0000disabled\124r.")
    else
        METHWHEELCHAIR_CONFIG.LOGIN_INFO = true
        Print("login info \124cff00ff00enabled\124r.")
    end

    return true
end

local function CmdLMB(msg)
    local cmd = { "lmb", "leftmousebutton" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.BLOCK_LMB = true
        Print("Blocking Left Mouse button is now \124cff00ff00enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.BLOCK_LMB = false
        Print("Blocking Left Mouse button is now \124cffff0000disabled\124r.")
    else
        if (METHWHEELCHAIR_CONFIG.BLOCK_LMB == true) then
            METHWHEELCHAIR_CONFIG.BLOCK_LMB = false
            Print("Blocking Left Mouse button is now \124cffff0000disabled\124r.")
        else
            METHWHEELCHAIR_CONFIG.BLOCK_LMB = true
            Print("Blocking Left Mouse button is now \124cff00ff00enabled\124r.")
        end
    end

    return true
end

local function CmdTrigger(msg)
    local cmd = { "trigger" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "cast") then
        METHWHEELCHAIR_CONFIG.INCLUDE_START_EVENT = false
        Print("Trigger set to CAST event only.")
    elseif (args[2] == "start") then
        METHWHEELCHAIR_CONFIG.INCLUDE_START_EVENT = true
        Print("Trigger set to both START and CAST events.")
    else
        Print("Invalid argument, valid arguments: { CAST, START }.")
    end

    return true
end

local function CmdSuperWoW(msg)
    local cmd = { "superwow" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.SUPER_WOW = true
        Print("SuperWoW functions are now \124cffff0000enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.SUPER_WOW = false
        Print("SuperWoW functions are now \124cffff0000disabled\124r.")
    else
        if (METHWHEELCHAIR_CONFIG.SUPER_WOW) then
            METHWHEELCHAIR_CONFIG.SUPER_WOW = false
            Print("SuperWoW functions are now \124cffff0000disabled\124r.")
        else
            METHWHEELCHAIR_CONFIG.SUPER_WOW = true
            Print("SuperWoW functions are now \124cffff0000enabled\124r.")
        end
    end

    return true
end

local function CmdUnitCastevent(msg)
    local cmd = { "unitcastevent" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.UNIT_CASTEVENT = true
        Print("UNIT_CASTEVENT is now \124cffff0000enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.UNIT_CASTEVENT = false
        Print("UNIT_CASTEVENT is now \124cffff0000disabled\124r.")
    else
        if (METHWHEELCHAIR_CONFIG.UNIT_CASTEVENT) then
            METHWHEELCHAIR_CONFIG.UNIT_CASTEVENT = false
            Print("UNIT_CASTEVENT is now \124cffff0000disabled\124r.")
        else
            METHWHEELCHAIR_CONFIG.UNIT_CASTEVENT = true
            Print("UNIT_CASTEVENT is now \124cffff0000enabled\124r.")
        end
    end

    return true
end

local function CmdHelp(msg)
    Print("Use '/mw restore' to restore your keybinds.")
    Print("Use '/mw unbind' or '/mw test' to test how preventing movement works.")
    Print("Use '/mw keybinds' to display list of saved keybinds.")
    Print("Use '/mw logininfo' to toggle display of saved keybinds on login.")
    Print("Use '/mw lmb' to toggle blocking left mouse button.")

    --if (SUPERWOW_VERSION) then
    --    Print("Use '/mw trigger <trigger_type>' to change trigger type. Replace <trigger_type> with one of values: { CAST, START }. Default value is CAST.")
    --end

    return true
end

local function CmdQuery(msg)
    local cmd = { "query" }
    local args = MsgArgs(msg, 10)
    if (not IsCmd(cmd, args[1])) then return false end

    local playerName = UnitName("PLAYER")

    if (args[2] == "version") then
        VersionCheckTimeLimit = GetTime() + 5.0
        local message = "query;"..playerName..";version;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing version check...\124r")
    end

    if (args[2] == "superwowversion") then
        VersionCheckTimeLimit = GetTime() + 5.0
        local message = "query;"..playerName..";superwowversion;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing SuperWoW version check...\124r")
    end

    if (args[2] == "triggercount") then
        local message = "query;"..playerName..";triggercount;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing trigger count check...\124r")
    end

    if (args[2] == "triggercounttotal") then
        local message = "query;"..playerName..";triggercounttotal;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing total trigger count check...\124r")
    end

    if (args[2] == "setting") then
        if (SettingKeys[args[3]] == nil) then
            Print("\124cffff0000Invalid setting name!\124r")
            return true
        end

        local message = "query;"..playerName..";setting;"..args[3]..";"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing setting ("..args[3]..") check...\124r")
    end

    if (args[2] == "mappositionfails") then
        local message = "query;"..playerName..";mappositionfails;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing map position fail check...\124r")
    end

    if (args[2] == "mappositioncriticalfails") then
        local message = "query;"..playerName..";mappositioncriticalfails;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing map position critical fail check...\124r")
    end

    if (args[2] == "mappositionfailstotal") then
        local message = "query;"..playerName..";mappositionfailstotal;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing total map position fail check...\124r")
    end

    if (args[2] == "mappositioncriticalfailstotal") then
        local message = "query;"..playerName..";mappositioncriticalfailstotal;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing total map position critical fail check...\124r")
    end

    return true
end

local function CmdListen(msg)
    local cmd = { "listen" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.LISTEN = true
        Print("Listening to addon channel \124cff00ff00enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.LISTEN = false
        Print("Listening to addon channel \124cffff0000disabled\124r.")
    else
        if (METHWHEELCHAIR_CONFIG.LISTEN) then
            METHWHEELCHAIR_CONFIG.LISTEN = false
            Print("Listening to addon channel \124cffff0000disabled\124r.")
        else
            METHWHEELCHAIR_CONFIG.LISTEN = true
            Print("Listening to addon channel \124cff00ff00enabled\124r.")
        end
    end

    --if (METHWHEELCHAIR_CONFIG.LISTEN) then
    --    RegisterEvent("CHAT_MSG_ADDON", OnChatMsgAddon)
    --else
    --    UnregisterEvent("CHAT_MSG_ADDON")
    --end

    return true
end

local function CmdResetTrackers(msg)
    local cmd = { "resettrackers" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    Stats.TriggerCount = 0
    Stats.MapPositionFails = 0
    Stats.MapPositionCriticalFails = 0

    return true
end

local function CmdResetTrackersTotal(msg)
    local cmd = { "resettrackerstotal" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    METHWHEELCHAIR_CONFIG.TOTAL_TRIGGER_COUNT = 0
    METHWHEELCHAIR_CONFIG.TOTAL_MAP_POSITION_FAILS = 0
    METHWHEELCHAIR_CONFIG.TOTAL_MAP_POSITION_CRITICAL_FAILS = 0

    return true
end

local function CmdReload(msg)
    local cmd = { "reload", "rl" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    ReloadUI()

    return true
end


SLASH_METHWHEELCHAIR1 = "/methwheelchair"
SLASH_METHWHEELCHAIR2 = "/mw"

SlashCmdList["METHWHEELCHAIR"] = function(msg)
    msg = strlower(msg)

    if (CmdRestore(msg)) then return end
    if (CmdUnbind(msg)) then return end
    if (CmdKeybinds(msg)) then return end
    if (CmdLoginInfo(msg)) then return end
    if (CmdLMB(msg)) then return end
    if (CmdTrigger(msg)) then return end
    if (CmdSuperWoW(msg)) then return end
    if (CmdUnitCastevent(msg)) then return end
    if (CmdQuery(msg)) then return end
    if (CmdListen(msg)) then return end
    if (CmdResetTrackers(msg)) then return end
    if (CmdResetTrackersTotal(msg)) then return end
    if (CmdReload(msg)) then return end

    if (CmdHelp(msg)) then return end
end

