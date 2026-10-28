--[[
    Paravel's Enhanced Tooltips - what every item says

    The game's tooltip of an item is its name and a list of lines: some every
    kind of item has (weight, the weight of the stack, foraging categories,
    condition, the note of its script...) and some its own kind adds in the
    middle of them. This source writes the first and takes the second from
    the kind of the item (Plain.lua, Food.lua...), which registers itself
    here with Common.addKind:
        category  the item's category (item:getCategory()).
        weightOf  function(item) answering the weight to show, when it is not
                  the item's unequipped one (animals).
        equippedWeight  true (or a function of the item answering it) when
                  the weight line also says what the item weighs equipped
                  (weapons, clothing).
        leadRows  function(item, context) answering rows that go before the
                  foraging ones, when the kind has any.
        minWidth  the least width of the tooltip, when more than the usual.
        ownsSharpness  true when the kind writes its own sharpness line
                  (weapons).
        ownsCondition  true when the kind writes its own condition line
                  (weapons, clothing).
        refusal   function(item, player) answering why the kind does not
                  cover this item, or nil when it does.
        rows      function(item, context) answering the kind's rows.
    The game's code adds many more lines for particular items (leaks,
    repairs, recipes, tags...) than are rebuilt, so an item that any of them
    could apply to, or whose answer cannot be asked from Lua, is refused and
    keeps the game's tooltip. `Common.refusal` says why, for finding out why
    a tooltip is not drawn here.
]]

require "ParavelsEnhancedTooltips/Content/Fluids"
require "ParavelsEnhancedTooltips/Content/Format"
require "ParavelsEnhancedTooltips/Content/ItemLines"
require "ParavelsEnhancedTooltips/Content/Questions"

local Fluids = PET.Fluids
local Format = PET.Format
local ItemLines = PET.ItemLines
local Questions = PET.Questions

local Common = PET.Common or {}
PET.Common = Common

Common.kinds = Common.kinds or {}

function Common.addKind(kind)
    Common.kinds[kind.category] = kind
end

-- Each question about an item, with the answers that mean a line not
-- rebuilt here.
local ITEM_QUESTIONS = {
    "getFluidContainer", "getAttributes",
    "getTooltip", "isFishingLure",
    "isEquipped", "isFakeEquipped",
    "getAttachedSlot", "getHotbarEquippedWeight", "getMechanicType",
    "hasHeadCondition", "hasSharpness",
    "getEquippedWeight",
}

-- The foraging categories come from the item's script, which must be askable.
local function scriptRefusal(item)
    local script = Questions.ask(item, "getScriptItem")
    if script == Questions.UNKNOWN then return "getScriptItem" end
    if script == nil then return nil end
    return Questions.askRefusal(script, "getForageFocusCategories")
end

-- The attributes the item's components give it (script "Attributes"): what
-- must be askable of each.
local ATTRIBUTE_QUESTIONS = {
    "isHiddenUI", "getNameUI",
    "isDisplayAsBar", "getDisplayAsBarUnit",
    "stringValue",
}

local function attributesRefusal(item)
    local container = item:getAttributes()
    if container == nil then return nil end
    if Questions.refuses(getDebugOptions(), "getBoolean", Questions.isTrue, "Tooltip.Attributes") then
        return "Tooltip.Attributes"
    end
    local reason = Questions.askRefusal(container, "size")
        or Questions.refusalIfMissing(container, "getAttribute")
    if reason or container:size() == 0 then return reason end
    return Questions.firstRefusal(container:getAttribute(0), ATTRIBUTE_QUESTIONS)
end

-- Extra lines for administrators, for the debug option of item info and for
-- the mod an item comes from if the player asked for it.
local function debugRefusal(item)
    if isAdmin() then return "admin" end
    if Questions.refuses(getDebugOptions(), "getBoolean", Questions.isTrue, "Tooltip.Info") then return "Tooltip.Info" end
    if Questions.refuses(getCore(), "getOptionShowItemModInfo", Questions.isTrue)
        and Questions.refuses(item, "isVanilla", Questions.isFalse) then
        return "modInfo"
    end
    return nil
end

-- The reason this source refuses `item`, or nil when it covers it.
function Common.refusal(item, player)
    local kind = Common.kinds[item:getCategory()]
    if not kind then return "category " .. tostring(item:getCategory()) end
    if ItemTag == nil then return "ItemTag" end
    local context = { player = player }
    return debugRefusal(item)
        or Questions.firstRefusal(item, ITEM_QUESTIONS)
        or scriptRefusal(item)
        or ItemLines.contents.refusal(item)
        or ItemLines.recipes.refusal(item, context)
        or ItemLines.ammo.refusal(item)
        or ItemLines.fatigue.refusal(item)
        or ItemLines.upkeep.refusal(item)
        or ItemLines.reading.refusal(item, context)
        or ItemLines.modifiers.refusal(item)
        or attributesRefusal(item)
        or Fluids.refusal(item)
        or kind.refusal(item, player)
end

-- A "Search focus" row for each foraging category the item belongs to.
local function forageRows(item)
    local rows = {}
    local script = item:getScriptItem()
    if not script then return rows end
    local categories = script:getForageFocusCategories():iterator()
    while categories:hasNext() do
        local category = categories:next()
        table.insert(rows, {
            label = Format.label("UI_search_mode_item_focus"),
            value = getText("IGUI_SearchMode_Categories_" .. category),
        })
    end
    return rows
end

-- A kind's flag, which can be a function of the item.
function Common.flag(value, item)
    if type(value) == "function" then return value(item) end
    return value
end

-- The weight line. Items that can be equipped say the weight in the other
-- state too, in brackets.
local function weightText(item, kind)
    local equippedWeight = Common.flag(kind.equippedWeight, item)
    local special = kind.weightOf and kind.weightOf(item)
    if special then return Format.number(special) end
    local unequipped = Format.number(item:getUnequippedWeight())
    local equipped = equippedWeight and (item:isEquipped() or item:isFakeEquipped())
    -- On the hotbar it weighs what it does there, and the weight off it in brackets.
    if item:getAttachedSlot() > -1 and not equipped then
        return Format.number(item:getHotbarEquippedWeight()) .. "    (" .. unequipped .. " " .. getText("Tooltip_item_Unattached") .. ")"
    end
    if not equippedWeight then return Format.weight(item:getUnequippedWeight()) end
    local equippedText = Format.number(item:getEquippedWeight())
    if equipped then
        return equippedText .. "    (" .. unequipped .. " " .. getText("Tooltip_item_Unequipped") .. ")"
    end
    return unequipped .. "    (" .. equippedText .. " " .. getText("Tooltip_item_Equipped") .. ")"
end

local function weightRows(item, context, kind)
    local rows = { { label = Format.label("Tooltip_item_Weight"), value = weightText(item, kind) } }
    if context.weightOfStack > 0 then
        table.insert(rows, { label = Format.label("Tooltip_item_StackWeight"), value = Format.weight(context.weightOfStack) })
    end
    return rows
end

-- The note the item's script gives it, a row for each of its lines (the
-- text breaks them with <br>).
local function noteRows(item)
    local note = item:getTooltip()
    if not note then return {} end
    local rows = {}
    for line in (getText(note):gsub("<[Bb][Rr]%s*/?>", "\n") .. "\n"):gmatch("(.-)\n") do
        table.insert(rows, { label = line })
    end
    return rows
end

-- The sharpness bar of an item that is not a weapon.
local function sharpnessRows(item)
    if not item:hasSharpness() then return {} end
    return { { label = Format.label("Tooltip_weapon_Sharpness"), progress = item:getSharpness(), scale = "up" } }
end

-- The condition bar, shown when the item is damaged or always asks for it.
local function conditionRows(item)
    local max = item:getConditionMax()
    if max <= 0 then return {} end
    local condition = item:getCondition()
    if condition >= max and item:getMechanicType() <= 0 and not ItemLines.hasTag(item, "SHOW_CONDITION") then return {} end
    local key = item:hasHeadCondition() and "Tooltip_weapon_HandleCondition" or "Tooltip_weapon_Condition"
    return { { label = Format.label(key), progress = condition / max, scale = "up" } }
end

local function lureRows(item)
    if not item:isFishingLure() then return {} end
    return { { label = getText("Tooltip_IsFishingLure") } }
end

-- A row for each attribute of the item that shows, by name: a bar or a value.
local function attributeRows(item)
    local container = item:getAttributes()
    local rows, attributes = {}, {}
    if container == nil then return rows end
    for index = 0, container:size() - 1 do
        local attribute = container:getAttribute(index)
        if not attribute:isHiddenUI() then table.insert(attributes, attribute) end
    end
    table.sort(attributes, function(a, b) return a:getNameUI() < b:getNameUI() end)
    for _, attribute in ipairs(attributes) do
        local label = attribute:getNameUI() .. ":"
        if attribute:isDisplayAsBar() then
            table.insert(rows, { label = label, progress = attribute:getDisplayAsBarUnit() })
        else
            table.insert(rows, { label = label, value = attribute:stringValue() })
        end
    end
    return rows
end

-- What the tooltip of `item` says, or nil when this source does not cover it
-- (`context`: `player` and `weightOfStack`): { title, rows, minWidth }.
function Common.of(item, context)
    if Common.refusal(item, context.player) then return nil end
    local kind = Common.kinds[item:getCategory()]
    local rows = ItemLines.contents.rows(item)
    ItemLines.append(rows, ItemLines.recipes.rows(item, context))
    ItemLines.append(rows, weightRows(item, context, kind))
    ItemLines.append(rows, ItemLines.ammo.rows(item))
    if kind.leadRows then ItemLines.append(rows, kind.leadRows(item, context)) end
    ItemLines.append(rows, forageRows(item))
    ItemLines.append(rows, ItemLines.fatigue.rows(item))
    ItemLines.append(rows, kind.rows(item, context))
    ItemLines.append(rows, ItemLines.upkeep.rows(item))
    if not Common.flag(kind.ownsSharpness, item) then ItemLines.append(rows, sharpnessRows(item)) end
    if not Common.flag(kind.ownsCondition, item) then ItemLines.append(rows, conditionRows(item)) end
    ItemLines.append(rows, ItemLines.reading.rows(item, context))
    ItemLines.append(rows, lureRows(item))
    ItemLines.append(rows, attributeRows(item))
    ItemLines.append(rows, Fluids.rows(item))
    ItemLines.append(rows, ItemLines.modifiers.rows(item))
    ItemLines.append(rows, noteRows(item))
    return { title = item:getName(context.player), rows = rows, minWidth = kind.minWidth }
end
