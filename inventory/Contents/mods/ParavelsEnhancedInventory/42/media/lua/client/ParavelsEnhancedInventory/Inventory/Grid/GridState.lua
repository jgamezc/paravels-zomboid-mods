--[[
    Paravel's Enhanced Inventory - grid state

    Each grid pane has a model, pane.pei_grid:
        inventory   the container it was made for
        expanded    open stacks, as a set of entry names
        selected    selected cells, as a set of cell keys (GridSelection)
        anchor      the cell key Shift ranges start from
        version     goes up whenever the entries or the open stacks change,
                    which is what the layout is made from

    The pane's entries change only when vanilla refreshes its container:
    GridState.onRefresh, run right after every refresh of a grid pane
    (Window/PaneContents.lua), brings them and the model up to date. Drawing
    refreshes a container that changed (GridState.refreshIfStale), as
    vanilla's list does. GridState.get(pane) only reads: the model and its
    layout. What vanilla writes into pane.selected is taken in once per
    frame, after its update() (GridState.adoptVanillaSelection).

    In grid mode pane.items holds one entry per stack in the grid's order,
    which is also the on-screen order, so vanilla code that indexes
    pane.items (mouseOverOption, double-click) keeps working, and
    pane.selected holds the selected entries by that index. Only
    GridState.publish writes it.
]]

require "ParavelsEnhancedInventory/Inventory/Grid/GridLayout"
require "ParavelsEnhancedInventory/Inventory/Grid/GridSelection"
require "ParavelsEnhancedInventory/Inventory/Entries"
require "ParavelsEnhancedInventory/Inventory/Sorting"

local Entries = PEI.Entries
local GridLayout = PEI.GridLayout
local GridSelection = PEI.GridSelection
local Sorting = PEI.Sorting

local GridState = PEI.GridState or {}
PEI.GridState = GridState

local function model(pane)
    local grid = pane.pei_grid
    if not grid then
        grid = { expanded = {}, selected = {}, version = 0 }
        pane.pei_grid = grid
    end
    return grid
end

-- Writes the selected entries into vanilla's pane.selected (index -> entry)
-- and remembers the table and how many it holds, to tell when vanilla
-- replaces it or writes into it.
function GridState.publish(pane)
    local grid = model(pane)
    local selected = pane.selected
    if selected ~= grid.published or not selected then
        selected = {}
        pane.selected = selected
        grid.published = selected
    end
    table.wipe(selected)
    local count = 0
    for index, entry in ipairs(pane.items) do
        if grid.selected[entry.name] then
            selected[index] = entry
            count = count + 1
        end
    end
    grid.publishedCount = count
end

local function countRows(selected)
    local count = 0
    for _ in pairs(selected) do count = count + 1 end
    return count
end

-- Takes in what vanilla has done to pane.selected since the last publish
-- and writes the grid's selection back over it. A new table (clicking
-- another window, opening another container) empties the grid's selection;
-- every row selected is vanilla's Ctrl+A and selects every cell. Anything
-- else it wrote (a stack's header, selected with the rows after it, which
-- in the grid are other cells) is just written over.
function GridState.adoptVanillaSelection(pane)
    local grid = pane.pei_grid
    if not grid then return end
    if pane.selected ~= grid.published then
        GridSelection.clear(grid)
    else
        local count = countRows(pane.selected)
        if count == grid.publishedCount then return end
        if count > 0 and count == #pane.items then GridSelection.selectAll(pane, grid) end
    end
    GridState.publish(pane)
end

-- ------------------------------------------------------------------ --
-- After a refresh
-- ------------------------------------------------------------------ --

-- Whether two lists from refreshContainer() show the same: the same entries
-- in the same order, holding the very same items. Only Lua fields are
-- read, so it costs next to nothing next to sorting again.
local function sameContents(before, after)
    if not before or #before ~= #after then return false end
    for index = 1, #after do
        local a, b = before[index], after[index]
        if a.name ~= b.name or #a.items ~= #b.items or a.weight ~= b.weight
            or (a.equipped and true or false) ~= (b.equipped and true or false)
            or (a.inHotbar and true or false) ~= (b.inHotbar and true or false) then
            return false
        end
        local itemsA, itemsB = a.items, b.items
        for i = 1, #itemsB do
            if itemsA[i] ~= itemsB[i] then return false end
        end
    end
    return true
end

local function fillItems(pane)
    table.wipe(pane.items)
    for _, entry in ipairs(pane.itemslist) do pane.items[#pane.items + 1] = entry end
end

-- Stacks that are gone, or no longer stacks, are closed.
local function closeGoneStacks(pane, grid)
    local entriesByName = {}
    for _, entry in ipairs(pane.itemslist) do entriesByName[entry.name] = entry end
    for name in pairs(grid.expanded) do
        local entry = entriesByName[name]
        if not (entry and Entries.isStack(entry)) then grid.expanded[name] = nil end
    end
end

-- Puts the entries vanilla has just listed into the grid's order, which
-- differs from the list's: itemslist is replaced so it and pane.items agree
-- (leaving the grid refreshes the container, which restores vanilla's
-- order). The game refreshes both windows every time the player steps
-- onto another square, though the inventory has not changed: then the last
-- order is put back as it was, instead of splitting and sorting again, and
-- nothing the layout depends on changes.
function GridState.onRefresh(pane)
    local grid = model(pane)
    -- Another container: what was open or selected belonged to the last one.
    if grid.inventory ~= pane.inventory then
        grid.inventory = pane.inventory
        table.wipe(grid.expanded)
        GridSelection.clear(grid)
        grid.refreshedList, grid.gridList = nil, nil
    end
    if grid.gridList and sameContents(grid.refreshedList, pane.itemslist) then
        grid.refreshedList = pane.itemslist
        pane.itemslist = grid.gridList
        fillItems(pane)
    else
        grid.refreshedList = pane.itemslist
        pane.itemslist = Entries.splitWorn(pane.itemslist)
        Sorting.sortForGrid(pane, pane.itemslist)
        grid.gridList = pane.itemslist
        fillItems(pane)
        closeGoneStacks(pane, grid)
        grid.version = grid.version + 1
    end
    -- Vanilla restored its selection by list row; the grid's is written over it.
    GridSelection.prune(grid, GridLayout.layout(pane, grid))
    GridState.publish(pane)
end

-- Refreshes the pane when its container has changed (or it has never
-- listed it), as vanilla's list does before drawing.
function GridState.refreshIfStale(pane)
    if not pane.itemslist or pane.inventory:isDrawDirty() then pane:refreshContainer() end
end

-- ------------------------------------------------------------------ --
-- Reading
-- ------------------------------------------------------------------ --

-- The pane's model and layout.
function GridState.get(pane)
    local grid = model(pane)
    return grid, GridLayout.layout(pane, grid)
end

-- Opens or closes a stack. Items that are no longer shown leave the selection.
function GridState.toggleExpanded(pane, entry)
    local grid = model(pane)
    grid.expanded[entry.name] = not grid.expanded[entry.name] or nil
    grid.version = grid.version + 1
    GridSelection.prune(grid, GridLayout.layout(pane, grid))
    GridState.publish(pane)
end

-- Forgets selection, open stacks and order, as when the pane changes view:
-- the two views index pane.selected differently.
function GridState.reset(pane)
    pane.pei_grid = nil
    pane.selected = {}
end
