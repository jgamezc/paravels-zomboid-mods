--[[
    Paravel's Enhanced Inventory - grid geometry

    Where every cell of the grid goes and what is under a point, worked out
    from the pane's entries in order (pane.items) and the grid's model
    (Grid/GridState.lua: which stacks are open). A cell is
        { key, entry, idx, x, y }                for an entry (idx: its index
                                                 in pane.items)
        { key, entry, item, sub = true, x, y }   for one item of an open
                                                 stack, right after its stack
    in content space. `key` names the cell in the selection and in what is
    kept between frames: the entry's name for an entry, the Java item for a
    stack's item; the two never compare equal.
]]

require "ParavelsEnhancedInventory/Inventory/Entries"
require "ParavelsEnhancedInventory/Inventory/Options"
require "ParavelsUI/Theme/Theme"
require "ParavelsUI/Controls/ScrollBar"

local Entries = PEI.Entries
local Options = PEI.Options
local ScrollBar = PUI.ScrollBar
local Theme = PUI.Theme

local GridLayout = PEI.GridLayout or {}
PEI.GridLayout = GridLayout

-- The grid's measures for the pane as it is now, a new table. Cells are
-- square: the icon plus the padding on each side, so the icon can fill more
-- or less of the cell while keeping its own pixel-exact size.
function GridLayout.measure(pane)
    local iconSize = Options.gridIconSize()
    local gap = Theme.halfGap()
    local cellSize = Options.gridCellSize()
    -- The scroll bar's width is always kept free, whether the content
    -- overflows or not, so the columns and the window's width never depend
    -- on how many items a container holds, and nothing shifts between one
    -- that scrolls and one that does not. The scroll bar also keeps a gap
    -- on its left, away from the cells.
    local scrollLane = ScrollBar.WIDTH + Theme.gap()
    -- How far the list's marks may stick out of a cell (GridRowContent).
    -- The cells keep that much room around them, and one pixel more, which
    -- vanilla's clip takes off the pane's bottom and right, so they and
    -- their marks are drawn whole inside the pane.
    local markOverhang = Theme.borderWidth() * 2
    local inset = markOverhang + 1
    local stepX = cellSize + gap
    local usableWidth = pane.width - scrollLane - inset
    return {
        iconSize = iconSize,
        gap = gap,
        cellW = cellSize,
        cellH = cellSize,
        stepX = stepX,
        stepY = cellSize + gap,
        columns = math.max(1, math.floor((usableWidth + gap) / stepX)),
        markOverhang = markOverhang,
        -- The first cell's x and y; the rows also end this far above the
        -- content's bottom. On the right the scroll lane leaves room.
        inset = inset,
        -- The window is sized to whole columns (Window/Window.lua), which
        -- needs what the cells leave free around them.
        scrollLane = scrollLane,
    }
end

-- Whether two tables from GridLayout.measure hold the same measures. Every
-- field is compared, so a layout never keeps a measure that has changed.
local function sameMeasures(a, b)
    for name, value in pairs(a) do
        if b[name] ~= value then return false end
    end
    return true
end

-- The cells grouped by row, top to bottom: { y, byColumn = { [column] = cell } }.
-- Cells fill each row left to right, so a row is a run of cells with one y.
local function rowsOf(cells, measures)
    local rows, row = {}, nil
    for _, cell in ipairs(cells) do
        if not row or row.y ~= cell.y then
            row = { y = cell.y, byColumn = {} }
            rows[#rows + 1] = row
        end
        row.byColumn[math.floor((cell.x - measures.inset) / measures.stepX)] = cell
    end
    return rows
end

-- The content's height for `rows` rows: the rows, and the margin above and
-- below them.
function GridLayout.rowsHeight(measures, rows)
    return rows * measures.stepY - measures.gap + measures.inset * 2
end

-- The content's width for `columns` columns: the margin on their left, the
-- columns, and the scroll bar's lane on their right.
function GridLayout.columnsWidth(measures, columns)
    return measures.inset + columns * measures.stepX - measures.gap + measures.scrollLane
end

-- Every cell placed, in on-screen order. Each open stack adds its items
-- right after its own cell, flowing on like any other cell: one reading
-- order for everything keeps Shift ranges continuous. Every row is one step
-- tall, so the content is always a whole number of rows (the window's
-- resize snaps to them).
local function build(pane, model, measures)
    local columns = measures.columns
    local cells, byKey = {}, {}
    local slot = 0
    local function place(cell)
        cell.x = measures.inset + (slot % columns) * measures.stepX
        cell.y = measures.inset + math.floor(slot / columns) * measures.stepY
        cells[#cells + 1] = cell
        byKey[cell.key] = cell
        slot = slot + 1
    end
    for index, entry in ipairs(pane.items) do
        place({ key = entry.name, entry = entry, idx = index })
        if model.expanded[entry.name] then
            for i = Entries.FIRST_ITEM, #entry.items do
                local item = entry.items[i]
                place({ key = item, entry = entry, item = item, sub = true })
            end
        end
    end
    local rowCount = math.ceil(slot / columns)
    return {
        model = model,
        version = model.version,
        measures = measures,
        cells = cells,
        byKey = byKey,
        rows = rowsOf(cells, measures),
        contentHeight = GridLayout.rowsHeight(measures, rowCount),
    }
end

-- The layout: { measures, cells, byKey (cell by key), rows, contentHeight }.
-- Made again only when the model's entries or open stacks change
-- (model.version), the model is new or a measure changes.
function GridLayout.layout(pane, model)
    local measures = GridLayout.measure(pane)
    local layout = pane.pei_layout
    if layout and layout.model == model and layout.version == model.version
        and sameMeasures(layout.measures, measures) then
        return layout
    end
    layout = build(pane, model, measures)
    pane.pei_layout = layout
    return layout
end

-- The cell under content-space point x, y, or nil.
function GridLayout.cellAt(layout, x, y)
    local measures = layout.measures
    if x < measures.inset then return nil end
    local column = math.floor((x - measures.inset) / measures.stepX)
    for _, row in ipairs(layout.rows) do
        if y < row.y then return nil end
        if y < row.y + measures.cellH then
            local cell = row.byColumn[column]
            if cell and x < cell.x + measures.cellW then return cell end
            return nil
        end
    end
    return nil
end

function GridLayout.cellUnderMouse(pane, layout)
    return GridLayout.cellAt(layout, pane:getMouseX(), pane:getMouseY())
end
