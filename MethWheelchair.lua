MethWheelchair = {}
mw = MethWheelchair
BINDING_HEADER_METHWHEELCHAIR = "MethWheelchair"
local ADDON_PREFIX = "METHWHEELCHAIR"


local DEBUG_MODE = false
MethWheelchair.DebugMode = DEBUG_MODE


local CONFIG_DEFAULT_VALUE = {
    -- display in chat window
    LOGIN_INFO = true,

    -- blocks moving my pressing both mouse buttons
    -- but disables Left Mouse Button clicks in World Frame - only registered by UI
    -- can't target enemies by clicking models, do it by clicking nameplates or tab target
    BLOCK_LMB = true,

    MUTUAL_MOUSE_BLOCK = true,

    -- use SuperWoW functions
    SUPERWOW = true,

    -- just annoying, player should know when to stop moving, not block him 2 sec before
    FULLSCREENEFFECT = true,

    EARLY_UNBIND = false,
    EARLY_UNBIND_VALUE = 1500,

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
    ["li"] = "LOGIN_INFO",
    ["login"] = "LOGIN_INFO",
    ["info"] = "LOGIN_INFO",

    ["lmbblock"] = "BLOCK_LMB",
    ["blocklmb"] = "BLOCK_LMB",
    ["lmb"] = "BLOCK_LMB",
    ["leftmousebuttonblock"] = "BLOCK_LMB",
    ["leftmousebuttonblocking"] = "BLOCK_LMB",

    ["mmb"] = "MUTUAL_MOUSE_BLOCK",
    ["mutualmouseblock"] = "MUTUAL_MOUSE_BLOCK",
    ["mutualmousebuttonblock"] = "MUTUAL_MOUSE_BLOCK",
    ["mutual_mouse_block"] = "MUTUAL_MOUSE_BLOCK",
    ["mutual_mouse_button_block"] = "MUTUAL_MOUSE_BLOCK",

    ["superwow"] = "SUPERWOW",

    ["listen"] = "LISTEN",

    ["totaltriggercount"] = "TOTAL_TRIGGER_COUNT",
    ["total_trigger_count"] = "TOTAL_TRIGGER_COUNT",

    ["totalmappositionfails"] = "TOTAL_MAP_POSITION_FAILS",
    ["total_map_position_fails"] = "TOTAL_MAP_POSITION_FAILS",

    ["totalmappositioncriticalfails"] = "TOTAL_MAP_POSITION_CRITICAL_FAILS",
    ["total_map_position_critical_fails"] = "TOTAL_MAP_POSITION_CRITICAL_FAILS",
}


local FullScreenEffect = nil
local TestInProgress = false
local ShouldUnbind = false
local Unbound = false
local PreviousPosition_X = 0
local PreviousPosition_Y = 0
local ShackleCastTime = 0
local EarlyUnbindTime = nil
local EarlyUnbindAddedCastDuration = 0


local ShackleDuration = 6.0
local ShackleCastDuration = 3.0

-- on combat log aura change
local ShackleSpellNameTriggers = {
    "Shackles of the Legion",
}

-- on UNIT_CASTEVENT
local ShackleSpellIDTriggers = {
    51916,
}

-- on UnitDebuff
local ShackleTextureTriggers = {
    "INV_Belt_18",
}

if (DEBUG_MODE) then
    -- names
    tinsert(ShackleSpellNameTriggers, "Weakened Soul")
    -- ids
    tinsert(ShackleSpellIDTriggers, 2060) -- Greater Heal (Rank 1)
    -- texture
    tinsert(ShackleTextureTriggers, "AshesToAshes") -- Weakened Soul
end


-- keyboard
local MovementTypes = {
    "MOVEFORWARD",
    "MOVEBACKWARD",
    "TURNLEFT",
    "TURNRIGHT",
    "STRAFELEFT",
    "STRAFERIGHT",
    "MOVEANDSTEER",
    "TOGGLEAUTORUN",
}

local Keybinds = {}

for k, mt in MovementTypes do
    Keybinds[mt] = {}
end


-- mouse 
local MouseButtonDebug = false

local LMB_ACTION = "CAMERAORSELECTORMOVE"
local RMB_ACTION = "TURNORACTION"

local LmbDown = false
local RmbDown = false

local LmbKeybind = nil
local RmbKeybind = nil


-- checks
local AddonVersionCheckTimeLimit = nil
local AddonVersionCheckTimeLimitDuration = 3.0
local AddonVersionCheckRepliers = {}

local SuperWoWVersionCheckTimeLimit = nil
local SuperWoWVersionCheckTimeLimitDuration = 3.0
local SuperWoWVersionCheckRepliers = {}

local SettingCheckTimeLimit = nil
local SettingCheckTimeLimitDuration = 3.0
local SettingCheckRepliers = {}
local SettingCheckSetting = nil


local Stats = {
    TriggerCount = 0,
    MapPositionFails = 0,
    MapPositionCriticalFails = 0,
}


-- hook
local old_CameraOrSelectOrMoveStart = CameraOrSelectOrMoveStart

local strfind = string.find
local strlower = string.lower



local function Print(msg, r, g, b, a)
    return DEFAULT_CHAT_FRAME:AddMessage("\124cffffffff[\124r\124cffa044b9MethWheelchair\124r\124cffffffff]:\124r "..tostring(msg), r, g, b, a)
end


local function GetAddonVersion()
    local version = GetAddOnMetadata("MethWheelchair", "Version")
    if (version) then
        return tonumber(version)
    end
    return nil
end
MethWheelchair.GetAddonVersion = GetAddonVersion


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


local function UnitHasDebuff(unit, texture)
	local i = 1
	local debuff = UnitDebuff(unit, i)
	while (debuff) do
		if (strfind(debuff, texture)) then
			return i
		end
		i = i + 1
		debuff = UnitDebuff(unit, i)
	end
	return nil
end


local function IsShackleSpellName(spellName)
    for _, name in ShackleSpellNameTriggers do
        if (name == spellName) then
            return true
        end
    end

    return false
end


local function IsShackleSpellID(spellID)
    for _, sid in ShackleSpellIDTriggers do
        if (sid == spellID) then
            return true
        end
    end

    return false
end


local function IsShackleDebuffTexture(texture)
    for _, t in ShackleTextureTriggers do
        if (strfind(texture, t)) then
            return true
        end
    end

    return false
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


local function InitUIConfig()
    MethWheelchair_Option_ShowLoginInfo:SetChecked(METHWHEELCHAIR_CONFIG.LOGIN_INFO)

    MethWheelchair_Option_EnableFullScreenEffect:SetChecked(METHWHEELCHAIR_CONFIG.FULLSCREENEFFECT)

    MethWheelchair_Option_UnbindBeforeShackle:SetChecked(METHWHEELCHAIR_CONFIG.EARLY_UNBIND)
    MethWheelchair_Option_UnbindBeforeShackle_Slider:SetValue(METHWHEELCHAIR_CONFIG.EARLY_UNBIND_VALUE)
    
    MethWheelchair_Option_BlockLeftMouseButton:SetChecked(METHWHEELCHAIR_CONFIG.BLOCK_LMB)

    MethWheelchair_Option_AllowOnlyOneMouseButtonAtATime:SetChecked(METHWHEELCHAIR_CONFIG.MUTUAL_MOUSE_BLOCK)
end


local function InitFullScreenEffect()
    if (METHWHEELCHAIR_CONFIG.FULLSCREENEFFECT) then
        FullScreenEffect = CreateFrame("FRAME")

        local width = GetScreenWidth()
        local height = GetScreenHeight()

        FullScreenEffect:SetWidth(width)
        FullScreenEffect:SetHeight(height)
        FullScreenEffect:SetPoint("CENTER", 0, 0)
        FullScreenEffect:SetFrameStrata("BACKGROUND")
        FullScreenEffect:Hide()

        local texture = FullScreenEffect:CreateTexture()
        texture:SetTexture(0.0, 0.0, 0.0, 0.5)
        texture:SetWidth(width)
        texture:SetHeight(height)
        texture:SetPoint("CENTER", 0, 0)

        local text = FullScreenEffect:CreateFontString()
        text:SetWidth(width)
        text:SetHeight(height)
        text:SetPoint("CENTER", 0, 0)
        text:SetFont("Fonts\\MORPHEUS.ttf", 18, "THINOUTLINE")
        text:SetText("!!! DO NOT MOVE !!!")
        text:SetTextColor(1.0, 0.0, 0.0, 1.0)

        FullScreenEffect.Texture = texture
        FullScreenEffect.Text = text
        
        function FullScreenEffect:Begin(endTime)
            self.EndTime = endTime
            self.Texture:SetTexture(0.0, 0.0, 0.0, 0.5)
            self.Text:SetText("!!! DO NOT MOVE !!!")
            self.Text:SetTextColor(1.0, 0.0, 0.0, 1.0)
            self:Show()
        end

        FullScreenEffect:RegisterEvent("UNIT_CASTEVENT")
        FullScreenEffect:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
        FullScreenEffect:RegisterEvent("CHAT_MSG_RAID_LEADER")
        if (DEBUG_MODE) then
            FullScreenEffect:RegisterEvent("CHAT_MSG_WHISPER") -- test
        end

        FullScreenEffect:SetScript("OnEvent", function()
            if (event == "UNIT_CASTEVENT") then
                if (METHWHEELCHAIR_CONFIG.SUPERWOW) then
                    local casterGUID = arg1
                    local targetGUID = arg2
                    local eventType = arg3
                    local spellID = arg4
                    local castDuration = arg5

                    if (METHWHEELCHAIR_CONFIG.FULLSCREENEFFECT) then
                        if (eventType == "START" and IsShackleSpellID(spellID)) then
                            FullScreenEffect:Begin(GetTime() + (castDuration / 1000) + ShackleDuration + 0.5)
                        end
                    end
                end
            elseif (event == "CHAT_MSG_RAID_BOSS_EMOTE") then
                if ((not SUPERWOW_VERSION) or (not METHWHEELCHAIR_CONFIG.SUPERWOW)) then
                    if (string.find(arg1, "Mephistroth begins to cast Shackles of the Legion")) then
                        FullScreenEffect:Begin(GetTime() + ShackleCastDuration + ShackleDuration + 0.5)
                    end
                end
            elseif (event == "CHAT_MSG_WHISPER" and DEBUG_MDOE) then -- test
                if ((not SUPERWOW_VERSION) or (not METHWHEELCHAIR_CONFIG.SUPERWOW)) then
                    if (string.find(arg1, "Mephistroth begins to cast Shackles of the Legion")) then
                        FullScreenEffect:Begin(GetTime() + ShackleCastDuration + ShackleDuration + 0.5)
                    end
                end
            end
        end)

        FullScreenEffect:SetScript("OnUpdate", function()
            local now = GetTime()

            if (FullScreenEffect.EndTime and (
                    (FullScreenEffect.EndTime < now)
                    or (FullScreenEffect.EndTime < now + ShackleDuration and (not TestInProgress))
                )
            ) then
                local hasDebuff = false
                for _, texture in ShackleTextureTriggers do
                    if (UnitHasDebuff("PLAYER", texture)) then
                        hasDebuff = true
                        break
                    end
                end

                if (hasDebuff == false) then
                    FullScreenEffect.EndTime = nil
                    FullScreenEffect:Hide()
                end
            end
        end)
    end
end


local function PrintVersion()
    Print("Version: "..tostring(GetAddonVersion()))
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

    LmbKeybind = GetBindingKey(LMB_ACTION)
    RmbKeybind = GetBindingKey(RMB_ACTION)

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

        if (mt == "MOVEANDSTEER" and SUPERWOW_VERSION and METHWHEELCHAIR_CONFIG.BLOCK_LMB) then
            -- do nothing, otherwise protected function error pops up
            -- because blocking Left Mouse Button involves hooking and reassigning semi-protected function
        else
            if (keybind[1]) then
                SetBinding(keybind[1], mt)
            end
            if (keybind[2]) then
                SetBinding(keybind[2], mt)
            end
        end
    end

    SetBinding(LmbKeybind, LMB_ACTION)
    SetBinding(RmbKeybind, RMB_ACTION)

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
    ShackleCastTime = 0
    RestoreKeybinds()
    if (SUPERWOW_VERSION and METHWHEELCHAIR_CONFIG.BLOCK_LMB) then
        CameraOrSelectOrMoveStart = old_CameraOrSelectOrMoveStart
    end
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

    if ((not SUPERWOW_VERSION) or (not METHWHEELCHAIR_CONFIG.SUPERWOW)) then
        UnregisterEvent("UNIT_CASTEVENT")
    end

    if ((not METHWHEELCHAIR_CONFIG.LISTEN)) then
        UnregisterEvent("CHAT_MSG_ADDON")
    end

    InitUIConfig()

    InitFullScreenEffect()
    
end)


local function HookMouseEvents()
    local WorldFrame_OnMouseDown = WorldFrame:GetScript("OnMouseDown")
    local WorldFrame_OnMouseUp = WorldFrame:GetScript("OnMouseUp")

    WorldFrame:SetScript("OnMouseDown", function(a1, a2)
        if (arg1 == "LeftButton") then
            LmbDown = true
            if (MouseButtonDebug) then
                Print("LMB_DOWN")
            end
        elseif (arg1 == "RightButton") then
            RmbDown = true
            if (MouseButtonDebug) then
                Print("RMB_DOWN")
            end
        end

        if (WorldFrame_OnMouseDown) then
            WorldFrame_OnMouseDown()
        end
    end)

    WorldFrame:SetScript("OnMouseUp", function(a1, a2)
        if (arg1 == "LeftButton") then
            LmbDown = false
            if (MouseButtonDebug) then
                Print("LMB_UP")
            end
        elseif (arg1 == "RightButton") then
            RmbDown = false
            if (MouseButtonDebug) then
                Print("RMB_UP")
            end
        end

        if (WorldFrame_OnMouseUp) then
            WorldFrame_OnMouseUp()
        end
    end)

    -- can't cover most frames anyway, no reason to work on only some
    --for k, frame in {UIParent:GetChildren()} do
    --
    --    local onMouseDown = frame:GetScript("OnMouseDown")
    --    local onMouseUp = frame:GetScript("OnMouseUp")
    --
    --    frame:SetScript("OnMouseDown", function(a1, a2)
    --        if (arg1 == "LeftButton") then
    --            LmbDown = true
    --            if (MouseButtonDebug) then
    --                Print("LMB_DOWN")
    --            end
    --        elseif (arg1 == "RightButton") then
    --            RmbDown = true
    --            if (MouseButtonDebug) then
    --                Print("RMB_DOWN")
    --            end
    --        end
    --
    --        if (onMouseDown) then
    --            onMouseDown()
    --        end
    --    end)
    --
    --    frame:SetScript("OnMouseUp", function(a1, a2)
    --        if (arg1 == "LeftButton") then
    --            LmbDown = false
    --            if (MouseButtonDebug) then
    --                Print("LMB_UP")
    --            end
    --        elseif (arg1 == "RightButton") then
    --            RmbDown = false
    --            if (MouseButtonDebug) then
    --                Print("RMB_UP")
    --            end
    --        end
    --
    --        if (onMouseUp) then
    --            onMouseUp()
    --        end
    --    end)
    --
    --end
end


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

    HookMouseEvents()
end)


-- CHAT_MSG_SPELL_AURA_GONE_SELF
RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF",
function()
    for _, spell in ShackleSpellNameTriggers do
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
    for _, spell in ShackleSpellNameTriggers do
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

    if (METHWHEELCHAIR_CONFIG.EARLY_UNBIND) then
        if (eventType == "START" and IsShackleSpellID(spellID)) then
            EarlyUnbindAddedCastDuration = ((castDuration - METHWHEELCHAIR_CONFIG.EARLY_UNBIND_VALUE) / 1000)
            EarlyUnbindTime = GetTime() + EarlyUnbindAddedCastDuration
        end
    end
end)


-- CHAT_MSG_RAID_BOSS_EMOTE
RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE",
function()
    if (METHWHEELCHAIR_CONFIG.EARLY_UNBIND and ((not SUPERWOW_VERSION) or (not METHWHEELCHAIR_CONFIG.SUPERWOW))) then
        if (string.find(arg1, "Mephistroth begins to cast Shackles of the Legion")) then
            EarlyUnbindAddedCastDuration = ((ShackleCastDuration - METHWHEELCHAIR_CONFIG.EARLY_UNBIND_VALUE) / 1000)
            EarlyUnbindTime = GetTime() + EarlyUnbindAddedCastDuration
        end
    end
end)


if (DEBUG_MODE) then
-- CHAT_MSG_WHISPER
RegisterEvent("CHAT_MSG_WHISPER", -- test
function()
    if (METHWHEELCHAIR_CONFIG.EARLY_UNBIND and ((not SUPERWOW_VERSION) or (not METHWHEELCHAIR_CONFIG.SUPERWOW))) then
        if (string.find(arg1, "Mephistroth begins to cast Shackles of the Legion")) then
            EarlyUnbindAddedCastDuration = ((ShackleCastDuration - METHWHEELCHAIR_CONFIG.EARLY_UNBIND_VALUE) / 1000)
            EarlyUnbindTime = GetTime() + EarlyUnbindAddedCastDuration
        end
    end
end)
end


local function ColorVersion(version)
    if (tonumber(version) < GetAddonVersion()) then
        return"\124cffff0000"..version.."\124r"
    elseif (tonumber(version) > GetAddonVersion()) then
        return "\124cffffff00"..version.."\124r"
    elseif (tonumber(version) == GetAddonVersion()) then
        return "\124cff00ff00"..version.."\124r"
    end
end

-- CHAT_MSG_ADDON
RegisterEvent("CHAT_MSG_ADDON",
function()
    if (arg1 == ADDON_PREFIX) then
        local args = MsgArgs(arg2, 10, ";")

        if (args[1] == "query" and args[2] == arg4) then

            if (args[3] == "version") then
                local requester = args[2]
                local name = UnitName("PLAYER")
                local version = tostring(GetAddonVersion())

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
                AddonVersionCheckRepliers[sender] = version
            end

            if (args[3] == "superwowversion") then
                local sender = args[4]
                local version = args[5]
                SuperWoWVersionCheckRepliers[sender] = version
            end

            if (args[3] == "setting") then
                local sender = args[4]
                local setting = args[5]
                local settingValue = args[6]
                SettingCheckRepliers[sender] = settingValue
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
            if (SUPERWOW_VERSION and METHWHEELCHAIR_CONFIG.BLOCK_LMB) then
                CameraOrSelectOrMoveStart = function()
                    -- try to do something similar to left click
                    --TurnOrActionStart() -- fail - protected function
                end
            end

            ShouldUnbind = false
        end
    end

    PreviousPosition_X = px
    PreviousPosition_Y = py
end


local function TryUnbindMouse()
    -- only one mouse button at a time
    if (METHWHEELCHAIR_CONFIG.MUTUAL_MOUSE_BLOCK and ShackleCastTime ~= 0) then
        if (LmbDown == true) then
            local rmbKeybind = GetBindingKey(RMB_ACTION)
            if (RmbDown == false and rmbKeybind ~= nil) then
                -- unbind RMB
                SetBinding(RmbKeybind, nil)
                if (MouseButtonDebug) then
                    Print("RMB unbound")
                end
            end
        elseif (RmbDown == true) then
            local lmbKeybind = GetBindingKey(LMB_ACTION)
            if (LmbDown == false and lmbKeybind ~= nil) then
                -- unbind LMB
                SetBinding(LmbKeybind, nil)
                if (MouseButtonDebug) then
                    Print("LMB unbound")
                end
            end
        else
            -- restore both
            local rmbKeybind = GetBindingKey(RMB_ACTION)
            if (not rmbKeybind) then
                SetBinding(RmbKeybind, RMB_ACTION)
                MouselookStop()
                if (MouseButtonDebug) then
                    Print("RMB restored")
                end
            end
            local lmbKeybind = GetBindingKey(LMB_ACTION)
            if (not lmbKeybind) then
                SetBinding(LmbKeybind, LMB_ACTION)
                MouselookStop()
                if (MouseButtonDebug) then
                    Print("LMB restored")
                end
            end
        end
    end
end


local function GetRaidUnit(unitName)
    for i = 1, GetNumRaidMembers(), 1 do
        local unit = "RAID"..i
        if (UnitName(unit) == unitName) then
            return unit
        end
    end
end


local function HandleAddonVersionCheck()
    if (AddonVersionCheckTimeLimit and (GetTime() > AddonVersionCheckTimeLimit)) then

        local versions = {}

        for sender, version in AddonVersionCheckRepliers do
            if (version and sender) then
                if (not versions[version]) then
                    versions[version] = {}
                end
                tinsert(versions[version], "\124cff"..GetClassColor(GetRaidUnit(sender))..sender.."\124r")
            end
        end

        for version, senders in versions do
            local numSenders = table.getn(senders)
            local message = "Version "..tostring(ColorVersion(version)).." ("..numSenders.."): "
            for i = 1, numSenders, 1 do
                message = message..senders[i]
                if (i ~= numSenders) then
                    message = message..", "
                end
            end
            message = message.."."
            Print(message)
        end

        local didNotRespond = {}
        local offline = {}

        for i = 1, GetNumRaidMembers(), 1 do
            local unit = "RAID"..i
            local unitName = UnitName(unit)
            local found = false
            for sender, version in AddonVersionCheckRepliers do
                if (sender == unitName) then
                    found = true
                    break
                end
            end
            if (not found) then
                if (UnitIsConnected(unit)) then
                    tinsert(didNotRespond, "\124cff"..GetClassColor(unit)..unitName.."\124r")
                else
                    tinsert(offline, "\124cff"..GetClassColor(unit)..unitName.."\124r")
                end
            end
        end

        local numDNR = table.getn(didNotRespond)
        if (numDNR > 0) then
            local message = "\124cffff0000Did not respond to version check\124r ("..tostring(numDNR).."): "
            for i = 1, numDNR, 1 do
                message = message..didNotRespond[i]
                if (i ~= numDNR) then
                    message = message..", "
                end
            end
            Print(message..".")
        end

        local numOffline = table.getn(offline)
        if (numOffline > 0) then
            local message = "\124cffaaaaaaOffline\124r ("..tostring(numOffline).."): "
            for i = 1, numOffline, 1 do
                message = message..offline[i]
                if (i ~= numOffline) then
                    message = message..", "
                end
            end
            Print(message..".")
        end

        if (numDNR == 0 and numOffline == 0) then
            Print("Everybody responded to version check.")
        end

        AddonVersionCheckTimeLimit = nil
        AddonVersionCheckRepliers = {}
    end
end


local function HandleSuperWoWVersionCheck()
    if (SuperWoWVersionCheckTimeLimit and (GetTime() > SuperWoWVersionCheckTimeLimit)) then

        local versions = {}

        for sender, version in SuperWoWVersionCheckRepliers do
            if (version and sender) then
                if (not versions[version]) then
                    versions[version] = {}
                end
                tinsert(versions[version], "\124cff"..GetClassColor(GetRaidUnit(sender))..sender.."\124r")
            end
        end

        for version, senders in versions do
            local numSenders = table.getn(senders)
            local message = "SuperWoW version \124cffffff00"..tostring(version).."\124r ("..numSenders.."): "
            for i = 1, numSenders, 1 do
                message = message..senders[i]
                if (i ~= numSenders) then
                    message = message..", "
                end
            end
            message = message.."."
            Print(message)
        end

        local didNotRespond = {}
        local offline = {}

        for i = 1, GetNumRaidMembers(), 1 do
            local unit = "RAID"..i
            local unitName = UnitName(unit)
            local found = false
            for sender, version in SuperWoWVersionCheckRepliers do
                if (sender == unitName) then
                    found = true
                    break
                end
            end
            if (not found) then
                if (UnitIsConnected(unit)) then
                    tinsert(didNotRespond, "\124cff"..GetClassColor(unit)..unitName.."\124r")
                else
                    tinsert(offline, "\124cff"..GetClassColor(unit)..unitName.."\124r")
                end
            end
        end

        local numDNR = table.getn(didNotRespond)
        if (numDNR > 0) then
            local message = "\124cffff0000Did not respond to SuperWoW version check\124r ("..tostring(numDNR).."): "
            for i = 1, numDNR, 1 do
                message = message..didNotRespond[i]
                if (i ~= numDNR) then
                    message = message..", "
                end
            end
            Print(message..".")
        end

        local numOffline = table.getn(offline)
        if (numOffline > 0) then
            local message = "\124cffaaaaaaOffline\124r ("..tostring(numOffline).."): "
            for i = 1, numOffline, 1 do
                message = message..offline[i]
                if (i ~= numOffline) then
                    message = message..", "
                end
            end
            Print(message..".")
        end

        if (numDNR == 0 and numOffline == 0) then
            Print("Everybody responded to SuperWoW version check.")
        end

        SuperWoWVersionCheckTimeLimit = nil
        SuperWoWVersionCheckRepliers = {}
    end
end


local function HandleSettingCheck()
    if (SettingCheckTimeLimit and (GetTime() > SettingCheckTimeLimit)) then
        local values = {}

        for sender, value in SettingCheckRepliers do
            if (value and sender) then
                if (not values[value]) then
                    values[value] = {}
                end
                tinsert(values[value], "\124cff"..GetClassColor(GetRaidUnit(sender))..sender.."\124r")
            end
        end

        for value, senders in values do
            local numSenders = table.getn(senders)
            local message = "Setting \124cff00ff00"..tostring(SettingCheckSetting).."\124r = \124cffffff00"..tostring(value).."\124r ("..numSenders.."): "
            for i = 1, numSenders, 1 do
                message = message..senders[i]
                if (i ~= numSenders) then
                    message = message..", "
                end
            end
            message = message.."."
            Print(message)
        end

        local didNotRespond = {}
        local offline = {}

        for i = 1, GetNumRaidMembers(), 1 do
            local unit = "RAID"..i
            local unitName = UnitName(unit)
            local found = false
            for sender, value in SettingCheckRepliers do
                if (sender == unitName) then
                    found = true
                    break
                end
            end
            if (not found) then
                if (UnitIsConnected(unit)) then
                    tinsert(didNotRespond, "\124cff"..GetClassColor(unit)..unitName.."\124r")
                else
                    tinsert(offline, "\124cff"..GetClassColor(unit)..unitName.."\124r")
                end
            end
        end

        local numDNR = table.getn(didNotRespond)
        if (numDNR > 0) then
            local message = "\124cffff0000Did not respond to setting check\124r ("..tostring(numDNR).."): "
            for i = 1, numDNR, 1 do
                message = message..didNotRespond[i]
                if (i ~= numDNR) then
                    message = message..", "
                end
            end
            Print(message..".")
        end

        local numOffline = table.getn(offline)
        if (numOffline > 0) then
            local message = "\124cffaaaaaaOffline\124r ("..tostring(numOffline).."): "
            for i = 1, numOffline, 1 do
                message = message..offline[i]
                if (i ~= numOffline) then
                    message = message..", "
                end
            end
            Print(message..".")
        end

        if (numDNR == 0 and numOffline == 0) then
            Print("Everybody responded to setting version check.")
        end

        SettingCheckTimeLimit = nil
        SettingCheckRepliers = {}
        SettingCheckSetting = nil
    end
end



EventFrame:SetScript("OnUpdate", function()
    if (EarlyUnbindTime and GetTime() > EarlyUnbindTime) then
        MethWheelchair.Unbind(EarlyUnbindAddedCastDuration)
        EarlyUnbindTime = nil
        EarlyUnbindAddedCastDuration = 0
    end

    -- check if player is moving and try to unbind keybinds if scheduled
    if (SUPERWOW_VERSION and METHWHEELCHAIR_CONFIG.SUPERWOW) then
        local px, py = UnitPosition("PLAYER")
        TryUnbind(px, py)

    -- non superwow position, hope map is correctly bound in "The Rock of Desolation" zone
    elseif (ShouldUnbind -- check to prevent lags while map is open, can result in one frame delay
            or (GetZoneText() == "The Rock of Desolation") -- even one frame is too long in boss fight, map shouldn't be open
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
    if (Unbound and (currentTime > (ShackleCastTime + ShackleDuration + 0.5))) then
        MethWheelchair.Restore()
        Print("Movement \124cff00ff00restored\124r.")
    end

    TryUnbindMouse()

    HandleAddonVersionCheck()
    HandleSuperWoWVersionCheck()
    HandleSettingCheck()
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
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.LOGIN_INFO = true
        MethWheelchair_Option_ShowLoginInfo:SetChecked(true)
        Print("Login info \124cff00ff00enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.LOGIN_INFO = false
        MethWheelchair_Option_ShowLoginInfo:SetChecked(false)
        Print("Login info \124cffff0000disabled\124r.")
    elseif (METHWHEELCHAIR_CONFIG.LOGIN_INFO == true) then
        METHWHEELCHAIR_CONFIG.LOGIN_INFO = false
        MethWheelchair_Option_ShowLoginInfo:SetChecked(false)
        Print("Login info \124cffff0000disabled\124r.")
    else
        METHWHEELCHAIR_CONFIG.LOGIN_INFO = true
        MethWheelchair_Option_ShowLoginInfo:SetChecked(true)
        Print("Login info \124cff00ff00enabled\124r.")
    end

    return true
end

local function CmdLMB(msg)
    local cmd = { "lmb", "leftmousebutton" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.BLOCK_LMB = true
        MethWheelchair_Option_BlockLeftMouseButton:SetChecked(true)
        Print("Blocking Left Mouse button is now \124cff00ff00enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.BLOCK_LMB = false
        MethWheelchair_Option_BlockLeftMouseButton:SetChecked(false)
        Print("Blocking Left Mouse button is now \124cffff0000disabled\124r.")
    else
        if (METHWHEELCHAIR_CONFIG.BLOCK_LMB == true) then
            METHWHEELCHAIR_CONFIG.BLOCK_LMB = false
            MethWheelchair_Option_BlockLeftMouseButton:SetChecked(false)
            Print("Blocking Left Mouse button is now \124cffff0000disabled\124r.")
        else
            METHWHEELCHAIR_CONFIG.BLOCK_LMB = true
            MethWheelchair_Option_BlockLeftMouseButton:SetChecked(true)
            Print("Blocking Left Mouse button is now \124cff00ff00enabled\124r.")
        end
    end

    return true
end

local function CmdMMB(msg)
    local cmd = { "mmb", "mutualmouseblock", "mutualmouseblocking", "mutualmousebutton" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.MUTUAL_MOUSE_BLOCK = true
        MethWheelchair_Option_AllowOnlyOneMouseButtonAtATime:SetChecked(true)
        Print("Mutual Mouse Button blocking is now \124cff00ff00enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.MUTUAL_MOUSE_BLOCK = false
        MethWheelchair_Option_AllowOnlyOneMouseButtonAtATime:SetChecked(false)
        Print("Mutual Mouse Button blocking is now \124cffff0000disabled\124r.")
    else
        if (METHWHEELCHAIR_CONFIG.MUTUAL_MOUSE_BLOCK == true) then
            METHWHEELCHAIR_CONFIG.MUTUAL_MOUSE_BLOCK = false
            MethWheelchair_Option_AllowOnlyOneMouseButtonAtATime:SetChecked(false)
            Print("Mutual Mouse Button blocking is now \124cffff0000disabled\124r.")
        else
            METHWHEELCHAIR_CONFIG.MUTUAL_MOUSE_BLOCK = true
            MethWheelchair_Option_AllowOnlyOneMouseButtonAtATime:SetChecked(true)
            Print("Mutual Mouse Button blocking is now \124cff00ff00enabled\124r.")
        end
    end

    return true
end

local function CmdEarlyUnbind(msg)
    local cmd = { "eu", "earlyunbind", "eub" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.EARLY_UNBIND = true
        MethWheelchair_Option_UnbindBeforeShackle:SetChecked(true)
        Print("Early Unbind is now \124cff00ff00enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.EARLY_UNBIND = false
        MethWheelchair_Option_UnbindBeforeShackle:SetChecked(false)
        Print("Early Unbind is now \124cffff0000disabled\124r.")
    elseif (tonumber(args[2])) then
        local value = tonumber(args[2])
        METHWHEELCHAIR_CONFIG.EARLY_UNBIND_VALUE = value
        Print("Early Unbind value is now set to \124cffffff00"..string.format("%.2f", value).."\124r.")
        MethWheelchair_Option_UnbindBeforeShackle_Slider:SetValue(value * 1000)

    -- toggle
    elseif (METHWHEELCHAIR_CONFIG.EARLY_UNBIND == true) then
        -- disable
        METHWHEELCHAIR_CONFIG.EARLY_UNBIND = false
        MethWheelchair_Option_UnbindBeforeShackle:SetChecked(false)
        Print("Early Unbind is now \124cffff0000disabled\124r.")
    else
        -- enable
        METHWHEELCHAIR_CONFIG.EARLY_UNBIND = true
        MethWheelchair_Option_UnbindBeforeShackle:SetChecked(true)
        Print("Early Unbind is now \124cff00ff00enabled\124r.")
    end

    return true
end

local function CmdFullScreenEffect(msg)
    local cmd = { "fse", "fullscreeneffect" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.FULLSCREENEFFECT = true
        MethWheelchair_Option_EnableFullScreenEffect:SetChecked(true)
        Print("Full-Screen Effect is now \124cff00ff00enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.FULLSCREENEFFECT = false
        MethWheelchair_Option_EnableFullScreenEffect:SetChecked(false)
        Print("Full-Screen Effect is now \124cffff0000disabled\124r.")
    elseif (METHWHEELCHAIR_CONFIG.FULLSCREENEFFECT == true) then
        METHWHEELCHAIR_CONFIG.FULLSCREENEFFECT = false
        MethWheelchair_Option_EnableFullScreenEffect:SetChecked(false)
        Print("Full-Screen Effect is now \124cffff0000disabled\124r.")
    else
        METHWHEELCHAIR_CONFIG.FULLSCREENEFFECT = true
        MethWheelchair_Option_EnableFullScreenEffect:SetChecked(true)
        Print("Full-Screen Effect is now \124cff00ff00enabled\124r.")
    end

    return true
end

local function CmdSuperWoW(msg)
    local cmd = { "superwow" }
    local args = MsgArgs(msg, 2)
    if (not IsCmd(cmd, args[1])) then return false end

    if (args[2] == "enable") then
        METHWHEELCHAIR_CONFIG.SUPERWOW = true
        Print("SuperWoW functions are now \124cff00ff00enabled\124r.")
    elseif (args[2] == "disable") then
        METHWHEELCHAIR_CONFIG.SUPERWOW = false
        Print("SuperWoW functions are now \124cffff0000disabled\124r.")
    else
        if (METHWHEELCHAIR_CONFIG.SUPERWOW) then
            METHWHEELCHAIR_CONFIG.SUPERWOW = false
            Print("SuperWoW functions are now \124cffff0000disabled\124r.")
        else
            METHWHEELCHAIR_CONFIG.SUPERWOW = true
            Print("SuperWoW functions are now \124cff00ff00enabled\124r.")
        end
    end

    if (METHWHEELCHAIR_CONFIG.SUPERWOW) then
        EventFrame:RegisterEvent("UNIT_CASTEVENT")
    else
        EventFrame:UnregisterEvent("UNIT_CASTEVENT")
    end

    return true
end

local function CmdQuery(msg)
    local cmd = { "query" }
    local args = MsgArgs(msg, 10)
    if (not IsCmd(cmd, args[1])) then return false end

    local playerName = UnitName("PLAYER")

    if (args[2] == "version") then
        AddonVersionCheckTimeLimit = GetTime() + AddonVersionCheckTimeLimitDuration
        local message = "query;"..playerName..";version;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing version check...\124r")
        return true
    end

    if (args[2] == "superwowversion" or args[2] == "superwow") then
        SuperWoWVersionCheckTimeLimit = GetTime() + SuperWoWVersionCheckTimeLimitDuration
        local message = "query;"..playerName..";superwowversion;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing SuperWoW version check...\124r")
        return true
    end

    if (args[2] == "setting") then
        if (SettingKeys[args[3]] == nil) then
            Print("\124cffff0000Invalid setting name!\124r")
            return true
        end

        SettingCheckTimeLimit = GetTime() + SettingCheckTimeLimitDuration
        SettingCheckSetting = SettingKeys[args[3]]
        local message = "query;"..playerName..";setting;"..args[3]..";"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing setting ("..SettingKeys[args[3]]..") check...\124r")
        return true
    end

    if (args[2] == "triggercount") then
        local message = "query;"..playerName..";triggercount;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing trigger count check...\124r")
        return true
    end

    if (args[2] == "triggercounttotal") then
        local message = "query;"..playerName..";triggercounttotal;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing total trigger count check...\124r")
        return true
    end

    if (args[2] == "mappositionfails") then
        local message = "query;"..playerName..";mappositionfails;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing map position fail check...\124r")
        return true
    end

    if (args[2] == "mappositioncriticalfails") then
        local message = "query;"..playerName..";mappositioncriticalfails;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing map position critical fail check...\124r")
        return true
    end

    if (args[2] == "mappositionfailstotal") then
        local message = "query;"..playerName..";mappositionfailstotal;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing total map position fail check...\124r")
        return true
    end

    if (args[2] == "mappositioncriticalfailstotal") then
        local message = "query;"..playerName..";mappositioncriticalfailstotal;"
        SendAddonMessage(ADDON_PREFIX, message, "RAID")
        Print("\124cff00ff00Initializing total map position critical fail check...\124r")
        return true
    end

    Print("\124cffff0000Invalid query!\124r")

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

    if (METHWHEELCHAIR_CONFIG.LISTEN) then
        EventFrame:RegisterEvent("CHAT_MSG_ADDON")
    else
        EventFrame:UnregisterEvent("CHAT_MSG_ADDON")
    end

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

local function CmdFullTest(msg)
    local cmd = { "fulltest" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    MethWheelchair.FullTest()

    return true
end

local function CmdShowUI(msg)
    local cmd = { "show" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    MethWheelchairMainFrame:Show()
    return true
end

local function CmdHideUI(msg)
    local cmd = { "hide" }
    local args = MsgArgs(msg, 1)
    if (not IsCmd(cmd, args[1])) then return false end

    MethWheelchairMainFrame:Hide()
    return true
end

local function ToggleUI(msg)
    local args = MsgArgs(msg, 1)
    if (args[1] == "") then

        if (not MethWheelchairMainFrame:IsShown()) then
            MethWheelchairMainFrame:Show()
        else
            MethWheelchairMainFrame:Hide()
        end

        return true
    end

    return false
end

local function CmdHelp(msg)
    --local cmd = { "help" }
    --local args = MsgArgs(msg, 1)
    --if (not IsCmd(cmd, args[1])) then return false end

    Print("Use '/mw' to toggle UI.")
    Print("Use '/mw restore' to restore your keybinds.")
    Print("Use '/mw unbind' or '/mw test' to test how preventing movement works.")
    Print("Use '/mw keybinds' to display list of saved keybinds.")
    Print("Use '/mw logininfo' to toggle display of saved keybinds on login.")
    Print("Use '/mw lmb' to toggle blocking left mouse button.")
    Print("Use '/mw fulltest' to conduct more complex test.")

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
    if (CmdMMB(msg)) then return end
    if (CmdEarlyUnbind(msg)) then return end
    if (CmdFullScreenEffect(msg)) then return end
    if (CmdSuperWoW(msg)) then return end
    --if (CmdTrigger(msg)) then return end
    --if (CmdUnitCastevent(msg)) then return end
    if (CmdQuery(msg)) then return end
    if (CmdListen(msg)) then return end
    if (CmdResetTrackers(msg)) then return end
    if (CmdResetTrackersTotal(msg)) then return end
    if (CmdReload(msg)) then return end
    if (CmdFullTest(msg)) then return end

    if (CmdShowUI(msg)) then return end
    if (CmdHideUI(msg)) then return end
    if (ToggleUI(msg)) then return end

    if (CmdHelp(msg)) then return end
end



-------------------------------------------------------------------------------------------
----------------------------------------- TEST --------------------------------------------
-------------------------------------------------------------------------------------------



local TestEventFrame = CreateFrame("FRAME")
TestEventFrame:Hide()
TestEventFrame:SetScript("OnUpdate", function()
    if (TestEventFrame.TestStartTime) then
        local now = GetTime()

        if (METHWHEELCHAIR_CONFIG.EARLY_UNBIND) then
            if (now > TestEventFrame.TestStartTime + (ShackleCastDuration - METHWHEELCHAIR_CONFIG.EARLY_UNBIND_VALUE / 1000)) then
                MethWheelchair.Unbind(METHWHEELCHAIR_CONFIG.EARLY_UNBIND_VALUE / 1000)
                TestEventFrame.TestStartTime = nil
            end
        else
            if (now > TestEventFrame.TestStartTime + ShackleCastDuration) then
                MethWheelchair.Unbind(0)
                TestEventFrame.TestStartTime = nil
            end
        end
    end

    if (TestEventFrame.TestEndTime) then
        local now = GetTime()

        -- shackle shatter, 0.1 sec delay because of OnUpdate order
        if ((not TestEventFrame.TestStartTime) and (not Unbound)
            and (now > TestEventFrame.TestEndTime - (ShackleDuration + 0.4))
        ) then
            FullScreenEffect.Texture:SetTexture(0.9, 0.1, 0.1, 0.4)
            FullScreenEffect.Text:SetText(")': You killed yourself and your friends :'(")
            FullScreenEffect.Text:SetTextColor(0.1, 1.0, 1.0, 1.0)
        end

        -- end test
        if (now > TestEventFrame.TestEndTime) then
            TestInProgress = false
            TestEventFrame.TestEndTime = nil
            MethWheelchairMainFrame:Show()
        end
    end
end)


function MethWheelchair.FullTest()
    if (UnitAffectingCombat("PLAYER")) then
        Print("\124cffffff00This test is not available in combat.\124r")
        return false
    end

    TestInProgress = true

    if (BigWigs) then
        BigWigs:ToggleActive(true)
        BigWigs:EnableModule("Mephistroth")
        BigWigs:TriggerEvent("UNIT_CASTEVENT", "PLAYER", "PLAYER", "START", 51916, ShackleCastDuration * 1000)
    end

    TestEventFrame:Show()
    TestEventFrame.TestStartTime = GetTime()
    TestEventFrame.TestEndTime = GetTime() + ShackleCastDuration + ShackleDuration + 0.5
    
    MethWheelchairMainFrame:Hide()

    if (METHWHEELCHAIR_CONFIG.FULLSCREENEFFECT) then
        FullScreenEffect:Begin(TestEventFrame.TestEndTime)
    end

    return true
end