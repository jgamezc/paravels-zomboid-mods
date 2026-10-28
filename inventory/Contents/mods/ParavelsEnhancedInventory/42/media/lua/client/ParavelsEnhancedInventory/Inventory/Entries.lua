--[[
    Paravel's Enhanced Inventory - inventory entries

    An entry is one row of vanilla's inventory pane (ISInventoryPane
    refreshContainer builds them): a stack of items of the same name.
    Its fields, as vanilla sets them:
        name      unique within the container (vanilla's itemindex key)
        items     items[1] is a duplicate of the first item, used as the
                  stack's header; the real items are items[2..#items]
        count     #items, header included
        weight    the whole stack's weight
        cat, equipped, inHotbar, invPanel

    Entries are rebuilt on every refreshContainer(): never keep a reference
    to one between refreshes. Keep its name and look it up again; the Java
    items (InventoryItem) do survive.
]]

require "ParavelsEnhancedInventory/Core/PEI"

local Entries = PEI.Entries or {}
PEI.Entries = Entries

-- Index of the first real item in entry.items (items[1] is the header copy).
Entries.FIRST_ITEM = 2

function Entries.headerItem(entry)
    return entry.items[1]
end

function Entries.itemCount(entry)
    return #entry.items - 1
end

function Entries.isStack(entry)
    return #entry.items > 2
end

-- Worn, held, key rings (vanilla's `equipped`) and attached to the hotbar
-- slots (`inHotbar`): what the views keep apart from the carried items.
function Entries.isEquipped(entry)
    return (entry.equipped or entry.inHotbar) and true or false
end

-- Any loss of condition, however small, makes an item unique.
function Entries.isWorn(item)
    local max = item:getConditionMax()
    return max > 0 and item:getCondition() < max
end

local function entryWith(template, name, items)
    local entry = { name = name, cat = template.cat, invPanel = template.invPanel,
                    equipped = template.equipped, inHotbar = template.inHotbar,
                    items = { items[1] }, weight = 0 }
    for _, item in ipairs(items) do
        entry.items[#entry.items + 1] = item
        entry.weight = entry.weight + item:getUnequippedWeight()
    end
    entry.count = #entry.items
    return entry
end

-- Vanilla stacks by name alone, so worn items are pulled out of their stack
-- into entries of their own. The pristine ones keep the stack's name; each
-- worn item gets a name made unique by its id, which stays the same across
-- refreshes so expansion and selection (kept by name) still resolve.
-- Entries with a single item are left alone, which also makes this safe to
-- run twice on the same list.
function Entries.splitWorn(list)
    local result = {}
    for _, entry in ipairs(list) do
        local worn, pristine = {}, {}
        if Entries.isStack(entry) then
            for i = Entries.FIRST_ITEM, #entry.items do
                local item = entry.items[i]
                if Entries.isWorn(item) then worn[#worn + 1] = item else pristine[#pristine + 1] = item end
            end
        end
        if #worn == 0 then
            result[#result + 1] = entry
        else
            if #pristine > 0 then result[#result + 1] = entryWith(entry, entry.name, pristine) end
            for _, item in ipairs(worn) do
                result[#result + 1] = entryWith(entry, entry.name .. "#" .. tostring(item:getID()), { item })
            end
        end
    end
    return result
end
