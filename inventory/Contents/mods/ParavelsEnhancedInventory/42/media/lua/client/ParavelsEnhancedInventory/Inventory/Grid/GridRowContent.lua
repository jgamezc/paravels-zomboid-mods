--[[
    Paravel's Enhanced Inventory - what the list draws over each item

    A cell's icon and its marks (worn, broken, frozen, poison, read,
    favourite... and whatever other mods add) come from vanilla's own list
    drawing, ISInventoryPane:renderdetails(), so the grid shows what the
    list shows without a copy of the game's rules or any mod's.

    renderdetails() runs on the pane with one collapsed row per cell and
    its draw calls swapped: textures and icons drawn in the icon column are
    kept, everything else (row backgrounds, text, bars) is dropped, and the
    rows' other effects (the pane's items, its scroll height, its clips)
    are left out. The icon is drawn in the cell's icon box; every other
    draw keeps its own size and its place against the nearer corner of the
    row's icon, now against the cell's (the cell is to the grid what the
    icon's backdrop is to the list): a mark at the icon's bottom left,
    sticking out a little, sits at the cell's bottom left, sticking out as
    much, but never more than the grid lets marks stick out (GridLayout
    keeps that much room around the cells, so they show whole).
]]

require "ISUI/ISInventoryPane"
require "ParavelsEnhancedInventory/Core/PEI"
require "ISUI/ISUITextureGetter"
require "ISUI/ISInventoryItem"
require "ParavelsUI/Draw/DrawOverrides"

local DrawOverrides = PUI.DrawOverrides

local GridRowContent = PEI.GridRowContent or {}
PEI.GridRowContent = GridRowContent

-- Where the rows' icon column ends while they are drawn here. Any width
-- holds the icon: draws are measured from it.
local ICON_COLUMN = 100

-- Row textures the cells leave out: the stack arrows.
local LEFT_OUT = { "treeexpicon", "treecolicon" }

-- The favourite star is drawn at the size vanilla gives the recipe stars
-- that share its corner (ISInventoryPane's favoriteRecipeInputStarSize),
-- larger than its own, so it stands out in a cell as it does in a row.
local FAVOURITE_STAR_SIZE = 16

local ALL_COLLAPSED = setmetatable({}, { __index = function() return true end })
local NO_SELECTION = {}

-- The draws of the pass running: { kind, texture or item, x, y, w, h, a, r, g, b }.
local collected = nil

local function isLeftOut(pane, texture)
    for _, name in ipairs(LEFT_OUT) do
        if texture == pane[name] then return true end
    end
    return false
end

local function keep(pane, kind, texture, x, y, w, h, a, r, g, b)
    if not texture or x >= ICON_COLUMN then return end
    if kind ~= "icon" and isLeftOut(pane, texture) then return end
    collected[#collected + 1] = { kind = kind, texture = texture, x = x, y = y, w = w, h = h, a = a or 1,
                                  r = r, g = g, b = b }
end

local function keepTexture(pane, texture, x, y, a, r, g, b)
    texture = ISUITextureGetter.checkGetTexture(texture)
    if not texture then return end
    if texture == pane.favoriteStar then
        keep(pane, "aspect", texture, x, y, FAVOURITE_STAR_SIZE, FAVOURITE_STAR_SIZE, a, r, g, b)
        return
    end
    keep(pane, "texture", texture, x, y, texture:getWidthOrig(), texture:getHeightOrig(), a, r, g, b)
end

local function keepScaled(pane, texture, x, y, w, h, a, r, g, b)
    keep(pane, "scaled", ISUITextureGetter.checkGetTexture(texture), x, y, w, h, a, r, g, b)
end

local function keepAspect(pane, texture, x, y, w, h, a, r, g, b)
    keep(pane, "aspect", ISUITextureGetter.checkGetTexture(texture), x, y, w, h, a, r, g, b)
end

local function keepIcon(pane, item, x, y, a, w, h)
    keep(pane, "icon", item, x, y, w, h, a)
end

local function zero() return 0 end
local function unlimited() return math.huge end

local PASS_OVERRIDES = {
    drawTexture = keepTexture,
    drawTextureScaled = keepScaled,
    drawTextureScaledAspect = keepAspect,
    drawItemIcon = keepIcon,
    drawRect = DrawOverrides.skip,
    drawRectStatic = DrawOverrides.skip,
    drawRectBorder = DrawOverrides.skip,
    drawRectBorderStatic = DrawOverrides.skip,
    drawText = DrawOverrides.skip,
    drawTextRight = DrawOverrides.skip,
    drawTextCentre = DrawOverrides.skip,
    drawTextZoomed = DrawOverrides.skip,
    drawProgressBar = DrawOverrides.skip,
    drawTextAndProgressBar = DrawOverrides.skip,
    drawItemDetails = DrawOverrides.skip,
    setStencilRect = DrawOverrides.skip,
    clearStencilRect = DrawOverrides.skip,
    repaintStencilRect = DrawOverrides.skip,
    suspendStencil = DrawOverrides.skip,
    resumeStencil = DrawOverrides.skip,
    updateScrollbars = DrawOverrides.skip,
    refreshContainer = DrawOverrides.skip,
    setScrollHeight = DrawOverrides.skip,
    setScrollWidth = DrawOverrides.skip,
    getYScroll = zero,
    getMouseX = zero,
    getMouseY = zero,
    getHeight = unlimited,
    column2 = ICON_COLUMN,
    headerHgt = 0,
    collapsed = ALL_COLLAPSED,
    equippedCollapsed = false,
    selected = NO_SELECTION,
    mouseOverOption = 0,
}

-- A row for one item of an open stack: an entry holding only that item.
local function rowForItem(entry, item)
    return { name = entry.name, cat = entry.cat, invPanel = entry.invPanel, equipped = entry.equipped,
             inHotbar = entry.inHotbar, items = { item, item }, count = 2, weight = 0 }
end

local function runRows(pane)
    pane:renderdetails(false)
end

local lastError = nil

-- What the list draws over each of `cells` (Grid/GridLayout.lua cells), as
-- an array in the same order: each a list of draws measured from the row's
-- icon, { kind, texture or item, x, y, w, h, a, r, g, b }, with
-- contents.iconSize the row icon's size. When the rows fail (another mod's
-- drawing), every cell is left empty and the error printed once.
function GridRowContent.collect(pane, cells)
    local rows, contents = {}, {}
    for i, cell in ipairs(cells) do
        rows[i] = cell.sub and rowForItem(cell.entry, cell.item) or cell.entry
        contents[i] = {}
    end
    local rowHeight = pane.itemHgt
    local iconSize = math.min(rowHeight - 2, 32)
    local inset = (rowHeight - iconSize) / 2
    contents.iconSize = iconSize
    if #cells == 0 then return contents end

    collected = {}
    local fields = { itemslist = rows, items = {} }
    for name, value in pairs(PASS_OVERRIDES) do fields[name] = value end
    local ok, err = pcall(PUI.withFields, pane, fields, runRows, pane)
    local draws = collected
    collected = nil
    if not ok then
        if err ~= lastError then
            print("[PEI] the list's drawing failed while the grid read it: " .. tostring(err))
            lastError = err
        end
        return contents
    end

    -- Each draw belongs to the row its middle falls in.
    local iconLeft = ICON_COLUMN - iconSize - inset
    for _, draw in ipairs(draws) do
        local row = math.floor((draw.y + (draw.h or 0) / 2) / rowHeight)
        local content = contents[row + 1]
        if content then
            draw.x = draw.x - iconLeft
            draw.y = draw.y - (row * rowHeight + inset)
            content[#content + 1] = draw
        end
    end
    return contents
end

-- Where a draw `size` long goes along one axis: as far from the cell's edge
-- as it was from the nearer edge of the row's icon (`from`, out of
-- `rowIcon`), sticking out of the cell by `overhang` at most.
local function place(from, size, rowIcon, cellStart, cellSize, overhang)
    local at
    if from + size / 2 >= rowIcon / 2 then
        at = cellStart + cellSize - (rowIcon - from)
    else
        at = cellStart + from
    end
    return math.floor(PUI.clamp(at, cellStart - overhang, cellStart + cellSize + overhang - size))
end

-- Draws one cell's content (from GridRowContent.collect) for a cell at
-- x, y, w, h with its icon at iconX, iconY, iconSize; no mark sticks out of
-- the cell by more than `overhang`. Returns whether the content held an icon.
function GridRowContent.draw(pane, content, rowIconSize, x, y, w, h, iconX, iconY, iconSize, fade, overhang)
    local hasIcon = false
    for _, draw in ipairs(content) do
        local alpha = draw.a * fade
        if draw.kind == "icon" then
            -- Through vanilla's renderItemIcon again, which keeps some fluid
            -- containers opaque whatever the fade.
            ISInventoryItem.renderItemIcon(pane, draw.texture, iconX, iconY, alpha, iconSize, iconSize)
            hasIcon = true
        else
            local drawX = place(draw.x, draw.w, rowIconSize, x, w, overhang)
            local drawY = place(draw.y, draw.h, rowIconSize, y, h, overhang)
            if draw.kind == "texture" then
                ISUIElement.drawTexture(pane, draw.texture, drawX, drawY, alpha, draw.r, draw.g, draw.b)
            elseif draw.kind == "scaled" then
                ISUIElement.drawTextureScaled(pane, draw.texture, drawX, drawY, draw.w, draw.h, alpha,
                    draw.r, draw.g, draw.b)
            else
                ISUIElement.drawTextureScaledAspect(pane, draw.texture, drawX, drawY, draw.w, draw.h, alpha,
                    draw.r, draw.g, draw.b)
            end
        end
    end
    return hasIcon
end
