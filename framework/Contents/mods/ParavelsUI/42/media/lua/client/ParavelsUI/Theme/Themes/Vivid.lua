--[[
    Paravel's UI - theme: Vivid

    Accessibility: pure black, white, thick bright lines and colours at
    full saturation and strength, a little lighter so they stand out.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Vivid", {
    bg = rgb(0, 0, 0),                 bgOpacity = 100,
    hover = 18,                        selected = 32,
    header = 10,                       stripe = 8,
    nested = 12,                       fillOpacity = 80,
    stateOpacity = 45,
    text = rgb(1, 1, 1),               muted = 85,
    textOnImage = "outline",
    border = rgb(1, 1, 1),             borderOpacity = 90,
    borderWidth = 2,
    radius = 4,                        radiusSmall = 3,
    tileShape = "soft",
    barShape = "soft",
    barThickness = 6,                  trackOpacity = 35,
    shadow = rgb(0, 0, 0),             shadowOpacity = 100,
    shadowOffset = 1,
    glow = rgb(1, 1, 1),               glowOpacity = 28,
    iconSize = 24,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 14,
    padding = 14,                      scrollWidth = 8,
    accent = rgb(0, 1, 0.3),
    success = rgb(0, 1, 0.5),          warning = rgb(1, 0.9, 0),
    danger = rgb(1, 0.1, 0.1),
    lightnessOffset = 18,              saturationOffset = 0,
    alphaOffset = 20,
    paletteColor1 = rgb(1, 0, 0),               paletteColor2 = rgb(0, 0.8, 0),
    paletteColor3 = rgb(1, 0.3, 1),             paletteColor4 = rgb(0.1, 0.4, 1),
    paletteColor5 = rgb(1, 0.5, 0),             paletteColor6 = rgb(0, 0.6, 0.45),
    paletteColor7 = rgb(0.65, 0.3, 1),          paletteColor8 = rgb(0.54, 0.26, 0.06),
    paletteColor9 = rgb(0, 0.917, 1),           paletteColor10 = rgb(0.75, 0.75, 0.75),
    paletteColor11 = rgb(1, 0.967, 0),          paletteColor12 = rgb(0.087, 0.035, 0.665),
})
