--[[
    Paravel's Enhanced Inventory - grid selection

    What is selected is the model's set of cell keys (Grid/GridLayout.lua):
    entry names and Java items, which can both be in it at once, as in
    vanilla's list, where a stack and some of its items mix freely. Names
    survive refreshContainer(), which rebuilds every entry table, and so do
    Java items. One anchor (model.anchor, a cell key) serves Shift ranges.
    These are the rules; Grid/GridState.lua keeps the model, prunes it and
    tells vanilla (pane.selected).
]]

require "ParavelsEnhancedInventory/Inventory/Entries"

local Entries = PEI.Entries

local GridSelection = PEI.GridSelection or {}
PEI.GridSelection = GridSelection

function GridSelection.isSelected(model, cell)
    return model.selected[cell.key] == true
end

-- What the selection acts on, in on-screen order: selected entries, with the
-- selected items of each open stack right after it. A mixed list of entries
-- and InventoryItems is what vanilla's list produces too, and both
-- ISInventoryPaneContextMenu and ISInventoryPane.getActualItems() accept it.
function GridSelection.selectedThings(pane, model)
    local things = {}
    local selected = model.selected
    for _, entry in ipairs(pane.items) do
        if selected[entry.name] then
            things[#things + 1] = entry
        elseif model.expanded[entry.name] then
            -- A selected stack already covers all its items.
            for i = Entries.FIRST_ITEM, #entry.items do
                local item = entry.items[i]
                if selected[item] then things[#things + 1] = item end
            end
        end
    end
    return things
end

function GridSelection.clear(model)
    table.wipe(model.selected)
    model.anchor = nil
end

function GridSelection.selectOnly(model, cell)
    table.wipe(model.selected)
    model.selected[cell.key] = true
    model.anchor = cell.key
end

-- Every entry, as vanilla's Ctrl+A selects every row.
function GridSelection.selectAll(pane, model)
    table.wipe(model.selected)
    for _, entry in ipairs(pane.items) do model.selected[entry.name] = true end
end

-- Keeps only what still has a cell in `layout` (stacks closed, items gone).
function GridSelection.prune(model, layout)
    for key in pairs(model.selected) do
        if not layout.byKey[key] then model.selected[key] = nil end
    end
    if model.anchor ~= nil and not layout.byKey[model.anchor] then model.anchor = nil end
end

-- Positions of the anchor and of `key` in on-screen order, when both are shown.
local function rangeEnds(cells, anchorKey, key)
    local anchorIndex, clickedIndex
    for index, cell in ipairs(cells) do
        if cell.key == anchorKey then anchorIndex = index end
        if cell.key == key then clickedIndex = index end
    end
    return anchorIndex, clickedIndex
end

-- A left click on `cell`, with the modifier keys held: `keys` is
-- { shift, ctrl }. Returns true when a plain click hit an already selected
-- cell: the caller collapses the selection to it on mouse-up, unless a drag
-- started.
function GridSelection.click(model, layout, cell, keys)
    local selected, key = model.selected, cell.key
    local cells = layout.cells
    local anchorIndex, clickedIndex
    if keys.shift and model.anchor ~= nil then
        anchorIndex, clickedIndex = rangeEnds(cells, model.anchor, key)
    end

    if anchorIndex and clickedIndex then
        -- The anchor stays put. Ctrl+Shift adds the range to the current
        -- selection instead of replacing it.
        if not keys.ctrl then table.wipe(selected) end
        for index = math.min(anchorIndex, clickedIndex), math.max(anchorIndex, clickedIndex) do
            selected[cells[index].key] = true
        end
        return false
    end
    if keys.ctrl then
        -- Toggling leaves the rest alone, so entries and stack items combine.
        selected[key] = not selected[key] or nil
        model.anchor = key
        return false
    end
    model.anchor = key
    if selected[key] then return true end
    table.wipe(selected)
    selected[key] = true
    return false
end
