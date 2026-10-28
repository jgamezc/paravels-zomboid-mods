--[[
    Paravel's Enhanced Tooltips - bags and containers

    What a bag says on top of what every item does: a row of small icons of
    what it holds, one for each different name, as many as fit. It is wider
    than other tooltips.
]]

require "ParavelsEnhancedTooltips/Content/Common"

local Common = PET.Common
local Questions = PET.Questions

local Container = PET.Container or {}
PET.Container = Container

local MIN_WIDTH = 160

local function refusal(item)
    local container = Questions.ask(item, "getItemContainer")
    if container == Questions.UNKNOWN or container == nil then return "getItemContainer (not askable)" end
    local items = container:getItems()
    local reason = Questions.askRefusal(items, "size")
    if reason or items:size() == 0 then return reason end
    local first = items:get(0)
    return Questions.askRefusal(first, "getName")
        or Questions.askRefusal(first, "getTex")
end

-- The icons of what the bag holds, the last added first, each name once.
local function iconRows(item)
    local items = item:getItemContainer():getItems()
    if items:size() == 0 then return {} end
    local icons, names = {}, {}
    for index = items:size() - 1, 0, -1 do
        local held = items:get(index)
        local name = held:getName()
        if name == nil or not names[name] then
            if name ~= nil then names[name] = true end
            table.insert(icons, held:getTex())
        end
    end
    return { { icons = icons } }
end

Common.addKind({ category = "Container", minWidth = MIN_WIDTH, refusal = refusal, rows = iconRows })
