--[[
    Paravel's UI - tiles

    A tile is a square box drawn in the theme's tile shape (Theme.tileShape):
    square, soft, round or circle. Grid cells are tiles, and so is anything
    else small and square that wants to match them (an icon's backdrop in a
    list row). Each rounded shape is a set of sprites (tools/textures.js):
    its fill and its outline at two thicknesses, each scaled to the tile in
    one call. The square shape uses plain rectangles instead, so it costs
    one call per fill and four per outline, at any thickness. A grid draws
    hundreds of tiles a frame, so the shape, which asks the game for its
    sprites, is worked out once per change of look.
]]

require "ParavelsUI/Core/Look"
require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Theme/Theme"

local Draw = PUI.Draw
local Theme = PUI.Theme

local Tile = PUI.Tile or {}
PUI.Tile = Tile

-- `radius`: the corner's share of the side, as drawn in the sprites.
local SHAPES = {
    square = { radius = 0 },
    soft   = { radius = 1 / 8, fill = "SoftFill",   ring = "SoftRing",   boldRing = "SoftRing2" },
    round  = { radius = 1 / 4, fill = "Fill",       ring = "Ring",       boldRing = "Ring2" },
    circle = { radius = 1 / 2, fill = "CircleFill", ring = "CircleRing", boldRing = "CircleRing2" },
}

-- The theme's tile shape. A shape whose sprites the game has not loaded
-- (PNGs added while it runs only load after re-entering it) is drawn round
-- instead of not at all.
local currentShape = PUI.Look.derived(function()
    local shape = SHAPES[Theme.tileShape()] or SHAPES.round
    if shape.fill and not Draw.sprite(shape.fill) then shape = SHAPES.round end
    return shape
end)

-- The corner radius of a tile `size` pixels wide, in pixels.
function Tile.radius(size)
    return currentShape().radius * size
end

function Tile.fill(element, x, y, w, h, color, alpha)
    if alpha <= 0 then return end
    local current = currentShape()
    if current.fill then return Draw.spriteScaled(element, current.fill, x, y, w, h, color, alpha) end
    Draw.rect(element, x, y, w, h, color, alpha)
end

-- Rows [fromRow, toRow) of the tile's fill, following its curve.
function Tile.band(element, x, y, w, h, fromRow, toRow, color, alpha)
    if alpha <= 0 or toRow <= fromRow then return end
    local current = currentShape()
    if current.fill then
        return Draw.roundedBand(element, x, y, w, h, fromRow, toRow, color, alpha, current.fill)
    end
    Draw.rect(element, x, y + fromRow, w, toRow - fromRow, color, alpha)
end

-- The tile's outline in the theme's line colour, opacity and thickness
-- (a sprite ring is about 1 or 2 px at a cell's usual size).
function Tile.outline(element, x, y, w, h, alpha)
    local thickness, color = Theme.borderWidth(), Theme.borderColor()
    alpha = alpha * Theme.borderAlpha()
    if thickness <= 0 or alpha <= 0 then return end
    local current = currentShape()
    if current.ring then
        local ring = thickness >= 2 and current.boldRing or current.ring
        return Draw.spriteScaled(element, ring, x, y, w, h, color, alpha)
    end
    Draw.rect(element, x, y, w, thickness, color, alpha)
    Draw.rect(element, x, y + h - thickness, w, thickness, color, alpha)
    Draw.rect(element, x, y + thickness, thickness, h - thickness * 2, color, alpha)
    Draw.rect(element, x + w - thickness, y + thickness, thickness, h - thickness * 2, color, alpha)
end
