--[[
    Paravel's UI - theme: Snow

    Arctic snow: frosted blue-white, slate text, round shapes, a cold palette
    of glacier, teal, lilac and slate with two warm notes, amber and coral.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Snow", {
    bg = rgb(0.9, 0.94, 0.98),         bgOpacity = 85,
    hover = 8,                         selected = 14,
    header = 5,                        stripe = 3,
    nested = 6,                        fillOpacity = 35,
    stateOpacity = 30,
    text = rgb(0.22, 0.28, 0.36),      muted = 60,
    textOnImage = "outline",
    border = rgb(0.55, 0.65, 0.78),    borderOpacity = 50,
    borderWidth = 1,
    radius = 20,                       radiusSmall = 10,
    tileShape = "round",
    barShape = "round",
    barThickness = 3,                  trackOpacity = 25,
    shadow = rgb(1, 1, 1),             shadowOpacity = 85,
    shadowOffset = 1,
    glow = rgb(1, 1, 1),               glowOpacity = 45,
    iconSize = 22,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 16,
    padding = 18,                      scrollWidth = 4,
    accent = rgb(0.35, 0.6, 0.85),
    success = rgb(0.3, 0.65, 0.6),     warning = rgb(0.9, 0.6, 0.25),
    danger = rgb(0.85, 0.35, 0.35),
    lightnessOffset = -12,             saturationOffset = 20,
    alphaOffset = 45,
    paletteColor1 = rgb(0.325, 0.625, 0.775),   paletteColor2 = rgb(0.325, 0.675, 0.646),
    paletteColor3 = rgb(0.615, 0.545, 0.755),   paletteColor4 = rgb(0.3, 0.383, 0.5),
    paletteColor5 = rgb(0.88, 0.647, 0.32),     paletteColor6 = rgb(0.58, 0.78, 0.82),
    paletteColor7 = rgb(0.37, 0.43, 0.73),      paletteColor8 = rgb(0.483, 0.561, 0.618),
    paletteColor9 = rgb(0.18, 0.583, 0.62),     paletteColor10 = rgb(0.64, 0.64, 0.76),
    paletteColor11 = rgb(0.829, 0.481, 0.411),  paletteColor12 = rgb(0.165, 0.255, 0.435),
})
