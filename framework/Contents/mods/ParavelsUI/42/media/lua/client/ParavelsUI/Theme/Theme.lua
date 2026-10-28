--[[
    Paravel's UI - theme (design tokens)

    One set of values every themed element draws from, so all parts match
    and a theme preset (Theme/ThemePresets.lua) changes all of them at once.
    Every token is generic: it says how surfaces, lines, shapes, text and
    colour look in general, never what one window or item kind looks like.
    Components work out their own look from these (a tile's corner from the
    tile shape, a row's radius from the small radius...) instead of
    declaring values of their own; anything visual with no token here needs
    a new generic token, not a constant.

    Theme.TOKENS lists every token, and each preset gives every one of them
    its value (npm run check fails otherwise). The preset in use
    (Theme.apply) is worked out into Theme.current, by token id, as the
    accessors below hand it out: colours are { r, g, b, a } tables,
    percentages are 0..1, pixels and choices stay as the preset has them.
    Elements read tokens through the accessors; outside this file only
    Theme/Palette.lua reads Theme.current, to hand out its colours by number.
    The first preset is in use from the start, until the player's own
    (Theme/ThemeOption.lua) is read. Something worked out from the theme is
    made through PUI.Look.derived, so it follows a new theme.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Core/Look"
require "ParavelsUI/Theme/ThemePresets"

local Color = PUI.Color
local ThemePresets = PUI.ThemePresets

local Theme = PUI.Theme or {}
PUI.Theme = Theme

-- kind: "color" (r, g, b, 0..1), "percent" (0..100 in the presets, 0..1 in
-- Theme.current; offsets go -100..100), "pixels" or "choice" (one of
-- `choices`, by name).
Theme.TOKENS = {
    -- Surfaces
    { id = "bg", kind = "color" },                -- Background colour
    { id = "bgOpacity", kind = "percent" },       -- Background opacity
    { id = "hover", kind = "percent" },           -- Fill under the mouse
    { id = "selected", kind = "percent" },        -- Fill of what is selected
    { id = "header", kind = "percent" },          -- Header tint
    { id = "stripe", kind = "percent" },          -- List stripes
    { id = "nested", kind = "percent" },          -- Fill of nested content
    { id = "fillOpacity", kind = "percent" },     -- Opacity of colour fills
    { id = "stateOpacity", kind = "percent" },    -- Opacity of states (progress, blocked)
    -- Text
    { id = "text", kind = "color" },              -- Text and icons
    { id = "muted", kind = "percent" },           -- Opacity of secondary text
    { id = "textOnImage", kind = "choice", choices = { "none", "shadow", "outline" } },
    -- Lines
    { id = "border", kind = "color" },            -- Outlines and lines
    { id = "borderOpacity", kind = "percent" },   -- Outline opacity
    { id = "borderWidth", kind = "pixels" },      -- Outline thickness
    -- Shapes
    { id = "radius", kind = "pixels" },           -- Window radius
    { id = "radiusSmall", kind = "pixels" },      -- Small radius (tabs, rows)
    { id = "tileShape", kind = "choice", choices = { "square", "soft", "round", "circle" } },
    { id = "barShape", kind = "choice", choices = { "square", "soft", "round" } },  -- Bar ends
    { id = "barThickness", kind = "pixels" },     -- Bar thickness
    { id = "trackOpacity", kind = "percent" },    -- Opacity of a bar's track
    -- Shadow and glow (behind icons, under text drawn over images)
    { id = "shadow", kind = "color" },            -- Shadow colour
    { id = "shadowOpacity", kind = "percent" },   -- Shadow opacity
    { id = "shadowOffset", kind = "pixels" },     -- Shadow offset
    { id = "glow", kind = "color" },              -- Glow colour
    { id = "glowOpacity", kind = "percent" },     -- Glow opacity
    -- Sizes and spacing
    { id = "iconSize", kind = "pixels" },         -- Icon size
    { id = "iconSizeSmall", kind = "pixels" },    -- Small icon size
    { id = "gap", kind = "pixels" },              -- Gap
    { id = "sectionGap", kind = "pixels" },       -- Gap between sections
    { id = "padding", kind = "pixels" },          -- Inner margin of windows
    { id = "scrollWidth", kind = "pixels" },      -- Scroll bar thumb width
    -- Meaning
    { id = "accent", kind = "color" },            -- Accent (capacity bar, marks)
    -- An accent over a fill of its own colour (Theme.accentOf, Theme.accentAlpha)
    { id = "lightnessOffset", kind = "percent" },   -- Lightness added
    { id = "saturationOffset", kind = "percent" },  -- Saturation added
    { id = "alphaOffset", kind = "percent" },       -- Opacity added to the fill's
    { id = "success", kind = "color" },           -- Progress and success
    { id = "warning", kind = "color" },           -- Warning (bar nearly full)
    { id = "danger", kind = "color" },            -- Danger (overweight, blocked)
    -- The palette's category colours (Theme/Palette.lua)
    { id = "paletteColor1", kind = "color" },
    { id = "paletteColor2", kind = "color" },
    { id = "paletteColor3", kind = "color" },
    { id = "paletteColor4", kind = "color" },
    { id = "paletteColor5", kind = "color" },
    { id = "paletteColor6", kind = "color" },
    { id = "paletteColor7", kind = "color" },
    { id = "paletteColor8", kind = "color" },
    { id = "paletteColor9", kind = "color" },
    { id = "paletteColor10", kind = "color" },
    { id = "paletteColor11", kind = "color" },
    { id = "paletteColor12", kind = "color" },
}

-- The preset in use, by token id, ready to draw with. The same table for
-- good, rewritten by Theme.apply.
Theme.current = Theme.current or {}
local current = Theme.current

-- Makes the preset `presetId` (an id of ThemePresets.ORDER) the one in use.
function Theme.apply(presetId)
    local values = ThemePresets.byId[presetId]
    for _, token in ipairs(Theme.TOKENS) do
        local value = values[token.id]
        if token.kind == "percent" then value = value / 100 end
        current[token.id] = value
    end
    Theme.presetId = presetId
    PUI.Look.changed()
end

-- Colours
function Theme.backgroundColor() return current.bg end
function Theme.textColor()       return current.text end
function Theme.borderColor()     return current.border end
function Theme.shadowColor()     return current.shadow end
function Theme.glowColor()       return current.glow end
function Theme.accentColor()     return current.accent end
function Theme.successColor()    return current.success end
function Theme.warningColor()    return current.warning end
function Theme.dangerColor()     return current.danger end

-- Opacities, 0..1
function Theme.backgroundAlpha() return current.bgOpacity end
function Theme.mutedAlpha()      return current.muted end
function Theme.hoverAlpha()      return current.hover end
function Theme.selectedAlpha()   return current.selected end
function Theme.headerTintAlpha() return current.header end
function Theme.stripeAlpha()     return current.stripe end
function Theme.nestedAlpha()     return current.nested end
function Theme.fillAlpha()       return current.fillOpacity end
function Theme.stateAlpha()      return current.stateOpacity end
function Theme.borderAlpha()     return current.borderOpacity end
function Theme.trackAlpha()      return current.trackOpacity end
function Theme.shadowAlpha()     return current.shadowOpacity end
function Theme.glowAlpha()       return current.glowOpacity end

-- A mark drawn in the colour of the fill it sits on (a band over a tinted
-- tile): that colour with the theme's lightness and saturation added, at the
-- fills' opacity plus the theme's. Each offset leaves the others alone.
function Theme.accentOf(color)
    return PUI.Color.adjust(color, current.lightnessOffset, current.saturationOffset)
end

function Theme.accentAlpha()
    return PUI.clamp(current.fillOpacity + current.alphaOffset, 0, 1)
end

-- Sizes, in pixels
function Theme.borderWidth()     return current.borderWidth end
function Theme.radius()          return current.radius end
function Theme.smallRadius()     return current.radiusSmall end
function Theme.barThickness()    return current.barThickness end
function Theme.shadowOffset()    return current.shadowOffset end
function Theme.iconSize()        return current.iconSize end
function Theme.smallIconSize()   return current.iconSizeSmall end
function Theme.gap()             return current.gap end
function Theme.halfGap()         return math.floor(current.gap / 2) end
function Theme.sectionGap()      return current.sectionGap end
-- Between a window's border and everything inside it.
function Theme.padding()         return current.padding end
function Theme.scrollWidth()     return current.scrollWidth end

-- Choices, by name
-- How text over an image (a count over an icon) stays readable:
-- "none", "shadow" (one copy offset) or "outline" (copies all around).
function Theme.textOnImage()     return current.textOnImage end
-- "square", "soft", "round" or "circle" (Shapes/Tile.lua).
function Theme.tileShape()       return current.tileShape end
-- The ends of bars (progress, capacity, scroll thumb): "square", "soft" or
-- "round".
function Theme.barShape()        return current.barShape end

-- The corner radius of a bar `thickness` pixels across, in the theme's bar
-- shape. Square ends (and soft ones on bars too thin to show them) are
-- plain rectangles: one call instead of a rounded box's seven, which counts
-- for bars drawn in every cell.
function Theme.barRadius(thickness)
    local shape = current.barShape
    if shape == "square" then return 0 end
    if shape == "soft" then return math.floor(thickness / 4) end
    return thickness / 2
end

-- Interactive icons and labels: muted, at full strength while hovered.
function Theme.interactiveAlpha(isHovered)
    if isHovered then return 1 end
    return current.muted
end

-- A capacity bar's colour for how full something is (1 = exactly full).
local NEARLY_FULL = 0.85
function Theme.fullnessColor(fullness)
    if fullness > 1 then return current.danger end
    if fullness >= NEARLY_FULL then return current.warning end
    return current.accent
end

-- The colour `fraction` (0 .. 1) of the way along a scale that goes from
-- `from` to `to` through the warning colour at its middle: two smooth halves.
function Theme.scaleColor(fraction, from, to)
    if fraction < 0.5 then return Color.mix(from, current.warning, fraction * 2) end
    return Color.mix(current.warning, to, (fraction - 0.5) * 2)
end

-- Every preset is defined before one is applied. Running this file again
-- (with tokens changed) applies the preset in use again.
ThemePresets.loadAll()
Theme.apply(ThemePresets.byId[Theme.presetId] and Theme.presetId or ThemePresets.ORDER[1])
