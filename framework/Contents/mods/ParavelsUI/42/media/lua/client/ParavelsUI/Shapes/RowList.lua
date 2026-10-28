--[[
    Paravel's UI - lists of rows

    Rows of a label and a value, or of a label and a bar, in two columns (the
    labels from the left, the values against the right edge), in the theme's
    text, colours and bars: the lines of an item's
    tooltip, a panel of stats. A row is a table with any of:
      label     text at the left.
      value     text at the right.
      progress  0..1; a bar at the right instead of the value.
      meaning   "good", "bad" or "warning": the theme's colour for it (the
                value's; the label too, when it has no value or bar). Nothing is plain text,
                "muted" is dimmed text.
      labelMeaning  the label's own meaning, when it has a value or bar.
      scale     "up" or "down": colours the bar along the theme's colours from bad
                to good through warning: "up" when a fuller bar is better
                (empty is bad), "down" when it is worse (empty is good).
                A bar whose labelMeaning is "bad" is "down" too.
      icons     a list of textures, a row of small icons in the row's own
                line (after its label, if it has one), as many as fit its
                width (the layout's width does not grow for them).
    A row with only a label is a note across both columns. A text with line
    breaks takes a line of its own height for each.

    It knows nothing of what the rows say: whoever has the data builds them.
    RowList.layout measures them once; RowList.draw paints that layout, as
    wide as the caller's box asks (what the rows leave over goes between the
    columns).
]]

require "ParavelsUI/Draw/Draw"
require "ParavelsUI/Draw/Text"
require "ParavelsUI/Shapes/ProgressBar"
require "ParavelsUI/Theme/Theme"

local Draw = PUI.Draw
local ProgressBar = PUI.ProgressBar
local Text = PUI.Text
local Theme = PUI.Theme

local RowList = PUI.RowList or {}
PUI.RowList = RowList

-- Icons keep their own colours.
local UNTINTED = { r = 1, g = 1, b = 1, a = 1 }

-- An icon row's icons are as tall as the text, and at least this many pixels.
local MIN_ICON_SIZE = 16

-- How many icon sizes wide the value column is at least when none is asked
-- for, so that a bar always has room.
local DEFAULT_VALUE_ICONS = 4

local function meaningColor(meaning)
    if meaning == "good" then return Theme.successColor() end
    if meaning == "bad" then return Theme.dangerColor() end
    if meaning == "warning" then return Theme.warningColor() end
    return Theme.textColor()
end

local function meaningAlpha(meaning)
    if meaning == "muted" then return Theme.mutedAlpha() end
    return 1
end

-- A bar's colour: along the theme's scale from bad to good through warning
-- when it has a direction ("up": the fuller, the better; "down": the worse;
-- the same scale with the ends swapped), else the theme's accent.
local function barColor(row)
    if row.scale == "up" then return Theme.scaleColor(row.progress, Theme.dangerColor(), Theme.successColor()) end
    if row.scale == "down" or row.labelMeaning == "bad" then
        return Theme.scaleColor(row.progress, Theme.successColor(), Theme.dangerColor())
    end
    return Theme.accentColor()
end

local function hasValueColumn(row)
    return row.value ~= nil or row.progress ~= nil
end

local function widest(rows, widthOf)
    local widest = 0
    for _, row in ipairs(rows) do widest = math.max(widest, widthOf(row)) end
    return widest
end

-- How many lines a text takes: one more than it has line breaks.
local function lineCount(text)
    local _, breaks = (text or ""):gsub("\n", "")
    return breaks + 1
end

-- A row is as tall as its icons, or as the lines of its longest text.
local function heightOf(row, rowHeight, iconSize)
    if row.icons then return iconSize end
    return math.max(lineCount(row.label), lineCount(row.value)) * rowHeight
end

-- The rows measured. Optional in `options`: `font` (UIFont.Small when nil),
-- `minLabelWidth` and `minValueWidth` for the columns and `minWidth` for the
-- whole list. The result holds what draw needs, plus `width` and `height`
-- for the caller's box.
function RowList.layout(rows, options)
    options = options or {}
    local font = options.font or UIFont.Small
    local rowHeight = getTextManager():getFontHeight(font)
    local iconSize = math.max(MIN_ICON_SIZE, rowHeight)
    local labelWidth = math.max(options.minLabelWidth or 0, widest(rows, function(row)
        return hasValueColumn(row) and Text.width(row.label or "", font) or 0
    end))
    local valueWidth = math.max(options.minValueWidth or Theme.iconSize() * DEFAULT_VALUE_ICONS, widest(rows, function(row)
        return row.value ~= nil and row.progress == nil and Text.width(row.value, font) or 0
    end))
    local noteWidth = widest(rows, function(row)
        return hasValueColumn(row) and 0 or Text.width(row.label or "", font)
    end)
    local columnsWidth = labelWidth + Theme.gap() + valueWidth
    local height, tops = 0, {}
    for index, row in ipairs(rows) do
        tops[index] = height
        height = height + heightOf(row, rowHeight, iconSize) + Theme.halfGap()
    end
    return {
        rows = rows, font = font, rowHeight = rowHeight, iconSize = iconSize, tops = tops,
        labelWidth = labelWidth, valueWidth = valueWidth,
        width = math.max(columnsWidth, noteWidth, options.minWidth or 0), height = math.max(0, height - Theme.halfGap()),
    }
end

local function drawBar(element, x, y, layout, row)
    local thickness = ProgressBar.height()
    local barY = y + math.floor((layout.rowHeight - thickness) / 2)
    ProgressBar.draw(element, x, barY, layout.valueWidth, row.progress, barColor(row), thickness)
end

-- The icons that fit between x and `right`, one after another.
local function drawIcons(element, x, y, layout, row, right)
    local size = layout.iconSize
    local iconX = x
    if row.label then
        Draw.text(element, row.label, x, y, Theme.textColor(), 1, layout.font)
        iconX = x + Text.width(row.label, layout.font) + Theme.gap()
    end
    for _, texture in ipairs(row.icons) do
        if iconX + size > right then return end
        Draw.texture(element, texture, iconX, y, size, size, UNTINTED, 1, "aspect")
        iconX = iconX + size + 1
    end
end

local function drawRow(element, x, y, layout, row, right)
    if row.icons then return drawIcons(element, x, y, layout, row, right) end
    local font = layout.font
    local valueX = right - layout.valueWidth
    -- The label is plain text next to a value or bar that carries the meaning.
    local labelMeaning = row.labelMeaning or ((not hasValueColumn(row)) and row.meaning or nil)
    if row.label then
        Draw.text(element, row.label, x, y, meaningColor(labelMeaning), meaningAlpha(labelMeaning), font)
    end
    if row.progress then
        drawBar(element, valueX, y, layout, row)
    elseif row.value then
        local textX = right - Text.width(row.value, font)
        Draw.text(element, row.value, textX, y, meaningColor(row.meaning), meaningAlpha(row.meaning), font)
    end
end

-- Paints a layout from RowList.layout with its top left corner at x, y,
-- `width` wide (the layout's own width when nil).
function RowList.draw(element, x, y, layout, width)
    local right = x + (width or layout.width)
    for index, row in ipairs(layout.rows) do
        drawRow(element, x, y + layout.tops[index], layout, row, right)
    end
end
