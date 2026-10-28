--[[
    Paravel's UI - drawing primitives

    The game's UI API only draws rectangles, textures and text. Everything
    themed is built here from those, on any ISUIElement:

    - Everything goes straight to the Java object: ISUIElement's drawRect
      and drawText draw nothing while a window is collapsed, which would
      leave a collapsed window's title bar empty, and its texture methods
      add Lua calls that cost real time on a grid's hundreds of draws.
      This file is the only one that calls the Java object's draw methods,
      so whatever is drawn through it can be recorded (DrawRecording).
    - Rounded shapes use white anti-aliased sprites (tools/textures.js,
      media/ui/ParavelsUI/Tile_*.png) tinted at draw time: a rounded square whose
      curve fills a quarter of its side ("Fill"), its outline ("Ring") and a
      soft radial glow ("Glow"), plus the other tile shapes' sets
      (Shapes/Tile.lua). A box that is not square gets each corner
      from the matching quarter of the Fill sprite and plain rectangles
      between them.
    - Outlines have their own thickness, which no sprite has, so their
      corners are built from anti-aliased one-pixel-tall runs, and so is
      what lies outside a rounded corner (to fill around one). Each such
      shape is dozens of calls: it is recorded once (DrawRecording) and
      replayed.
    - Icons are Lucide PNGs (tools/icons.js), drawn through Draw.icon only.

    Colours are { r, g, b } tables followed by an opacity (0..1). Nothing
    here reads the theme: what to draw comes in the arguments. Shapes drawn
    in the theme's look are built on these: Shapes/ and Controls/.
]]

require "ParavelsUI/Core/PUI"
require "ParavelsUI/Draw/DrawRecording"

local Draw = PUI.Draw or {}
PUI.Draw = Draw

local DrawRecording = PUI.DrawRecording

-- Textures drawn as they are, untinted.
Draw.UNTINTED = { r = 1, g = 1, b = 1 }

-- Corners are named tl, tr, bl, br; these sets say which are rounded.
Draw.ALL_CORNERS = { tl = true, tr = true, bl = true, br = true }
Draw.TOP_CORNERS = { tl = true, tr = true }
Draw.LEFT_CORNERS = { tl = true, bl = true }
Draw.ALL_SIDES = { top = true, right = true, bottom = true, left = true }

-- ------------------------------------------------------------------ --
-- Basic shapes
-- ------------------------------------------------------------------ --

function Draw.rect(element, x, y, w, h, color, alpha)
    element.javaObject:DrawTextureScaledColor(nil, x, y, w, h, color.r, color.g, color.b, alpha)
end

function Draw.text(element, text, x, y, color, alpha, font)
    element.javaObject:DrawText(font or UIFont.Small, text, x, y, color.r, color.g, color.b, alpha)
end

-- A texture in a w x h box. `fit` says how it fills it, as the game's
-- calls do: "scaled" stretches it over the box, "aspect" scales its opaque
-- part evenly to fit and centres it, "icon" keeps that part's own offset in
-- the texture (the game's way for icons with a fluid mask).
function Draw.texture(element, texture, x, y, w, h, color, alpha, fit)
    local java = element.javaObject
    if fit == "aspect" then
        java:DrawTextureScaledAspect(texture, x, y, w, h, color.r, color.g, color.b, alpha)
    elseif fit == "icon" then
        java:DrawTextureIcon(texture, x, y, w, h, color.r, color.g, color.b, alpha)
    else
        java:DrawTextureScaledColor(texture, x, y, w, h, color.r, color.g, color.b, alpha)
    end
end

-- An inventory item's icon in a w x h box, as the game draws it.
function Draw.itemIcon(element, item, x, y, w, h, alpha)
    element.javaObject:DrawItemIcon(item, x, y, alpha, w, h)
end

-- A Lucide icon (tools/icons.js) in a size x size box at x, y, the box being
-- the icon's whole canvas. The icons load untrimmed (offsets 0); the offsets
-- are still honoured, as drawTextureScaled would stretch a trimmed
-- texture's opaque part over the whole box.
-- Each icon's texture and the box it is drawn into, as fractions of the
-- icon's size, read once: icons are drawn every frame.
local iconCache = {}

local function iconLook(name)
    local look = iconCache[name]
    if look then return look end
    -- PNGs added while the game runs only load after re-entering it, so a
    -- miss is not cached.
    local texture = getTexture("media/ui/ParavelsUI/icons/" .. name .. ".png")
    if not texture then return nil end
    local widthOrig, heightOrig = texture:getWidthOrig(), texture:getHeightOrig()
    look = { texture = texture,
             x = texture:getOffsetX() / widthOrig, y = texture:getOffsetY() / heightOrig,
             w = texture:getWidth() / widthOrig, h = texture:getHeight() / heightOrig }
    iconCache[name] = look
    return look
end

function Draw.icon(element, name, x, y, size, color, alpha)
    local look = iconLook(name)
    if not look then return end
    element.javaObject:DrawTextureScaledColor(look.texture, x + look.x * size, y + look.y * size,
        look.w * size, look.h * size, color.r, color.g, color.b, alpha)
end

-- ------------------------------------------------------------------ --
-- Sprites
-- ------------------------------------------------------------------ --

local spriteCache = {}

-- "Fill", "Ring", "Glow" or a tile shape's sprite. PNGs added while the game runs only load after
-- re-entering it, so a miss is not cached.
function Draw.sprite(name)
    local texture = spriteCache[name]
    if not texture then
        texture = getTexture("media/ui/ParavelsUI/Tile_" .. name .. ".png")
        if texture then spriteCache[name] = texture end
    end
    return texture
end

-- A sprite stretched over a box. Only square boxes keep the curve's shape.
function Draw.spriteScaled(element, name, x, y, w, h, color, alpha)
    local texture = Draw.sprite(name)
    if texture then element.javaObject:DrawTextureScaledColor(texture, x, y, w, h, color.r, color.g, color.b, alpha) end
end

-- Rows [fromRow, toRow) of a rounded square of w x h at x, y: the same slice
-- of a fill sprite ("Fill" when nil), stretched to those rows. Bands cut
-- this way share the square's curve and anti-aliasing exactly, at any
-- thickness or size.
function Draw.roundedBand(element, x, y, w, h, fromRow, toRow, color, alpha, spriteName)
    local texture = Draw.sprite(spriteName or "Fill")
    if not texture or toRow <= fromRow then return end
    local texelsPerRow = texture:getHeight() / h
    element.javaObject:DrawSubTextureRGBA(texture, 0, fromRow * texelsPerRow, texture:getWidth(),
        (toRow - fromRow) * texelsPerRow, x, y + fromRow, w, toRow - fromRow, color.r, color.g, color.b, alpha)
end

-- ------------------------------------------------------------------ --
-- Rounded boxes
-- ------------------------------------------------------------------ --

-- The radius that fits a w x h box, even a window collapsed to its title bar.
function Draw.fitRadius(radius, w, h)
    return math.max(0, math.floor(math.min(radius, w / 2, h / 2)))
end

-- Top left position of a corner's r x r square in a w x h box at x, y.
local function cornerOrigin(corner, x, y, w, h, r)
    local cornerX = (corner == "tr" or corner == "br") and x + w - r or x
    local cornerY = (corner == "bl" or corner == "br") and y + h - r or y
    return cornerX, cornerY
end

-- The left and right columns of a box, by the corners at their ends.
local SIDE_COLUMNS = {
    { top = "tl", bottom = "bl", right = false },
    { top = "tr", bottom = "br", right = true },
}

-- The matching quarter of the Fill sprite, drawn into a corner's square.
local function drawCornerQuarter(element, texture, corner, cornerX, cornerY, r, color, alpha)
    local tw, th = texture:getWidth(), texture:getHeight()
    local sourceX = (corner == "tr" or corner == "br") and tw * 3 / 4 or 0
    local sourceY = (corner == "bl" or corner == "br") and th * 3 / 4 or 0
    element.javaObject:DrawSubTextureRGBA(texture, sourceX, sourceY, tw / 4, th / 4, cornerX, cornerY, r, r,
        color.r, color.g, color.b, alpha)
end

-- The largest radius `corners` leave room for in a w x h box. The side
-- columns are a radius wide each; a column with a rounded corner at both
-- ends needs two radii of height, one with a single rounded corner only one
-- (a box with only its top corners rounded can be as short as the radius).
local function radiusThatFits(radius, w, h, corners)
    local roundedTop, roundedBottom = corners.tl or corners.tr, corners.bl or corners.br
    local tallest = (roundedTop and roundedBottom) and h / 2 or h
    return math.floor(math.min(radius, w / 2, tallest))
end

-- A filled box. `corners` says which corners are rounded (all when nil);
-- the rest are square. The radius is cut down to what fits. Seven calls at
-- most: the middle column, the two side columns between the corners, and
-- each rounded corner from the matching quarter of the Fill sprite (a
-- square corner is the side column running on to the edge).
function Draw.roundedRect(element, x, y, w, h, radius, color, alpha, corners)
    if w <= 0 or h <= 0 then return end
    corners = corners or Draw.ALL_CORNERS
    local texture = Draw.sprite("Fill")
    local r = texture and radiusThatFits(radius, w, h, corners) or 0
    if r <= 0 then return Draw.rect(element, x, y, w, h, color, alpha) end
    Draw.rect(element, x + r, y, w - r * 2, h, color, alpha)
    for _, side in ipairs(SIDE_COLUMNS) do
        local top = corners[side.top] and r or 0
        local bottom = corners[side.bottom] and r or 0
        local columnX = side.right and x + w - r or x
        if h - top - bottom > 0 then Draw.rect(element, columnX, y + top, r, h - top - bottom, color, alpha) end
        if top > 0 then drawCornerQuarter(element, texture, side.top, columnX, y, r, color, alpha) end
        if bottom > 0 then drawCornerQuarter(element, texture, side.bottom, columnX, y + h - r, r, color, alpha) end
    end
end

-- ------------------------------------------------------------------ --
-- Anti-aliased corner runs
-- ------------------------------------------------------------------ --

local function coverage(value)
    return PUI.clamp(value, 0, 1)
end

local runCache = {}

-- Part of the top left r x r corner square of a circle of radius r centred
-- at (r, r), as runs { x, y, width, coverage } one pixel tall.
-- `coverageAt(distance)` gives a pixel's coverage from the distance of its
-- centre to the circle's centre, so the curve is anti-aliased. Fully
-- covered pixels next to each other make one run.
local function computeCornerRuns(r, coverageAt)
    local runs = {}
    for py = 0, r - 1 do
        local run
        for px = 0, r - 1 do
            local dx, dy = r - px - 0.5, r - py - 0.5
            local pixelCoverage = coverageAt(math.sqrt(dx * dx + dy * dy))
            if pixelCoverage >= 0.999 and run and run[4] >= 0.999 then
                run[3] = run[3] + 1
            elseif pixelCoverage > 0.01 then
                run = { px, py, 1, pixelCoverage }
                table.insert(runs, run)
            else
                run = nil
            end
        end
    end
    return runs
end

-- The ring between the circle and one `thickness` pixels smaller. Cached.
local function ringCornerRuns(r, thickness)
    local key = "ring:" .. r .. ":" .. thickness
    if not runCache[key] then
        local inner = r - thickness
        runCache[key] = computeCornerRuns(r, function(distance)
            local covered = coverage(r - distance + 0.5)
            if inner > 0 then covered = covered - coverage(inner - distance + 0.5) end
            return covered
        end)
    end
    return runCache[key]
end

-- What lies outside the circle, in its corner square. Cached.
local function outsideCornerRuns(r)
    local key = "outside:" .. r
    if not runCache[key] then
        runCache[key] = computeCornerRuns(r, function(distance)
            return 1 - coverage(r - distance + 0.5)
        end)
    end
    return runCache[key]
end

-- The top left corner's runs mirrored into `corner` of a w x h box at 0, 0,
-- each drawn as drawRun(x, y, width, coverage).
local function eachRunIn(corner, runs, w, h, r, drawRun)
    local cornerX, cornerY = cornerOrigin(corner, 0, 0, w, h, r)
    local isRight, isBottom = corner == "tr" or corner == "br", corner == "bl" or corner == "br"
    for _, run in ipairs(runs) do
        local runX = isRight and r - run[1] - run[3] or run[1]
        local runY = isBottom and r - 1 - run[2] or run[2]
        drawRun(cornerX + runX, cornerY + runY, run[3], run[4])
    end
end

-- A name for each set of corners or sides, for the recordings' keys.
local setNames = {}
local function setName(set)
    local name = setNames[set]
    if name then return name end
    name = ""
    for _, part in ipairs({ "tl", "tr", "bl", "br", "top", "right", "bottom", "left" }) do
        if set[part] then name = name .. part end
    end
    setNames[set] = name
    return name
end

local function colorKey(color, alpha)
    return color.r .. ":" .. color.g .. ":" .. color.b .. ":" .. alpha
end

local function drawOutline(element, w, h, r, corners, sides, color, alpha, thickness)
    local function segment(sx, sy, sw, sh, segmentAlpha)
        if sw > 0 and sh > 0 then Draw.rect(element, sx, sy, sw, sh, color, segmentAlpha or alpha) end
    end
    -- Straight sides, between the corners.
    if sides.top then segment(r, 0, w - r * 2, thickness) end
    if sides.bottom then segment(r, h - thickness, w - r * 2, thickness) end
    if sides.right then segment(w - thickness, r, thickness, h - r * 2) end
    if sides.left then segment(0, r, thickness, h - r * 2) end
    if r <= 0 then return end
    for corner in pairs(Draw.ALL_CORNERS) do
        local cornerX, cornerY = cornerOrigin(corner, 0, 0, w, h, r)
        local isRight, isBottom = corner == "tr" or corner == "br", corner == "bl" or corner == "br"
        if corners[corner] then
            eachRunIn(corner, ringCornerRuns(r, thickness), w, h, r, function(runX, runY, runW, runCoverage)
                segment(runX, runY, runW, 1, alpha * runCoverage)
            end)
        else
            -- A square corner: its sides run on to its edges.
            if sides[isBottom and "bottom" or "top"] then
                segment(cornerX, isBottom and cornerY + r - thickness or cornerY, r, thickness)
            end
            if sides[isRight and "right" or "left"] then
                segment(isRight and cornerX + r - thickness or cornerX, cornerY, thickness, r)
            end
        end
    end
end

-- The outline of a w x h box at x, y, `thickness` pixels thick. `corners`
-- says which corners are rounded with radius r and `sides` which sides are
-- drawn (all when nil). Its rounded corners are dozens of calls, so it is
-- recorded once and replayed (DrawRecording.replayCached): the key names
-- everything that changes what is drawn, so an outline that looks the same
-- shares its recording.
function Draw.outline(element, x, y, w, h, r, corners, sides, color, alpha, thickness)
    corners, sides = corners or Draw.ALL_CORNERS, sides or Draw.ALL_SIDES
    local key = "outline:" .. w .. ":" .. h .. ":" .. r .. ":" .. thickness .. ":" .. setName(corners) .. ":"
        .. setName(sides) .. ":" .. colorKey(color, alpha)
    DrawRecording.replayCached(element, key, x, y, drawOutline, w, h, r, corners, sides, color, alpha, thickness)
end

local function drawOutsideCorners(element, w, h, r, corners, color, alpha)
    for corner in pairs(corners) do
        eachRunIn(corner, outsideCornerRuns(r), w, h, r, function(runX, runY, runW, runCoverage)
            Draw.rect(element, runX, runY, runW, 1, color, alpha * runCoverage)
        end)
    end
end

-- Fills what lies outside the curve of the rounded `corners` (radius r) of
-- a w x h box at x, y, within each corner's square: what joins a surface
-- drawn around the box to the box's own rounded corners.
function Draw.outsideCorners(element, x, y, w, h, r, corners, color, alpha)
    if r <= 0 then return end
    local key = "outside:" .. w .. ":" .. h .. ":" .. r .. ":" .. setName(corners) .. ":" .. colorKey(color, alpha)
    DrawRecording.replayCached(element, key, x, y, drawOutsideCorners, w, h, r, corners, color, alpha)
end
