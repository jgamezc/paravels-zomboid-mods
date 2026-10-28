--[[
    Paravel's Enhanced Tooltips - weapon parts, clocks and keys

    The small kinds of item:
      - A part of a weapon says what kind of part it is, what it can be
        mounted on and, if it uses a battery, how much is left.
      - An alarm clock (or the clothing that is one) says the time and when
        its alarm rings. The clothing one says nothing of the clothing.
      - Keys say nothing of their own, and a key ring weighs by its equipped
        state too.
]]

require "ParavelsEnhancedTooltips/Content/Common"

local Common = PET.Common
local ItemLines = PET.ItemLines
local Format = PET.Format
local Questions = PET.Questions

local Gadgets = PET.Gadgets or {}
PET.Gadgets = Gadgets

-- ------------------------------------------------------------------ --
-- Weapon parts
-- ------------------------------------------------------------------ --

local function partRefusal(item)
    return Questions.firstRefusal(item, { "getPartType", "getMountOn" })
        or ItemLines.battery.refusal(item)
end

-- The names of what the part mounts on, as the game lists them.
local function mountNames(item)
    local names, mounts = {}, item:getMountOn()
    for index = 0, mounts:size() - 1 do
        local script = getScriptManager():FindItem(mounts:get(index))
        if script ~= nil then table.insert(names, script:getDisplayName()) end
    end
    return table.concat(names, ", ")
end

local function partRows(item)
    local rows = {
        { label = getText("Tooltip_weapon_Type") .. ": ", value = getText("Tooltip_weapon_" .. item:getPartType()) },
        { label = getText("Tooltip_weapon_CanBeMountOn") .. ": " .. mountNames(item) },
    }
    ItemLines.append(rows, ItemLines.battery.rows(item))
    return rows
end

Common.addKind({ category = "WeaponPart", refusal = partRefusal, rows = partRows })

-- ------------------------------------------------------------------ --
-- Alarm clocks
-- ------------------------------------------------------------------ --

local function isClothing(item)
    return instanceof(item, "Clothing")
end

local function clockRefusal(item)
    if GameTime == nil then return "GameTime" end
    return Questions.firstRefusal(item, { "isAlarmSet", "getHour", "getMinute" })
end

-- Minutes the way the game writes them: "00" for none.
local function minutesText(minutes)
    return minutes == 0 and "00" or tostring(minutes)
end

local function clockRows(item)
    local time = GameTime.getInstance()
    local rows = { {
        label = getText("IGUI_CurrentTime"),
        value = time:getHour() .. ":" .. minutesText(math.floor(time:getMinutes() / 10) * 10),
    } }
    if item:isAlarmSet() then
        table.insert(rows, { label = getText("IGUI_AlarmIsSetFor"), value = item:getHour() .. ":" .. minutesText(item:getMinute()) })
    end
    return rows
end

-- The clothing clock says nothing of its clothing, and so has no condition.
Common.addKind({
    category = "AlarmClock", equippedWeight = isClothing, ownsCondition = isClothing,
    refusal = clockRefusal, rows = clockRows,
})

-- ------------------------------------------------------------------ --
-- Keys
-- ------------------------------------------------------------------ --

local function noRows() return {} end

Common.addKind({ category = "Key", refusal = function() return nil end, rows = noRows })
Common.addKind({ category = "Key Ring", equippedWeight = true, refusal = function() return nil end, rows = noRows })
