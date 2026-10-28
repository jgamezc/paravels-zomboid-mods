--[[
    Paravel's UI - theme: Legible

    Made to be read: opaque, plain white on black, strong lines, secondary
    text barely muted, bigger icons, and family colours as far apart as
    the palette allows (rows pulled apart in lightness, hues at full spread).
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Legible", {
    bg = rgb(0.05, 0.05, 0.05),        bgOpacity = 100,
    hover = 12,                        selected = 25,
    header = 8,                        stripe = 6,
    nested = 10,                       fillOpacity = 60,
    stateOpacity = 40,
    text = rgb(1, 1, 1),               muted = 80,
    textOnImage = "outline",
    border = rgb(0.75, 0.75, 0.75),    borderOpacity = 70,
    borderWidth = 1,
    radius = 6,                        radiusSmall = 4,
    tileShape = "soft",
    barShape = "soft",
    barThickness = 5,                  trackOpacity = 30,
    shadow = rgb(0, 0, 0),             shadowOpacity = 90,
    shadowOffset = 1,
    glow = rgb(1, 1, 1),               glowOpacity = 22,
    iconSize = 24,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 14,
    padding = 16,                      scrollWidth = 7,
    accent = rgb(0.2, 0.75, 0.35),
    success = rgb(0.3, 0.85, 0.45),    warning = rgb(1, 0.75, 0.1),
    danger = rgb(1, 0.25, 0.2),
    lightnessOffset = 12,              saturationOffset = 15,
    alphaOffset = 40,
    paletteColor1 = rgb(0.932, 0.168, 0.168),   paletteColor2 = rgb(0.18, 0.72, 0.18),
    paletteColor3 = rgb(0.91, 0.49, 0.91),      paletteColor4 = rgb(0.168, 0.486, 0.932),
    paletteColor5 = rgb(0.978, 0.55, 0.123),    paletteColor6 = rgb(0.09, 0.51, 0.37),
    paletteColor7 = rgb(0.65, 0.423, 0.877),    paletteColor8 = rgb(0.48, 0.27, 0.12),
    paletteColor9 = rgb(0.168, 0.869, 0.932),   paletteColor10 = rgb(0.7, 0.7, 0.7),
    paletteColor11 = rgb(0.978, 0.906, 0.123),  paletteColor12 = rgb(0.14, 0.14, 0.56),
})
