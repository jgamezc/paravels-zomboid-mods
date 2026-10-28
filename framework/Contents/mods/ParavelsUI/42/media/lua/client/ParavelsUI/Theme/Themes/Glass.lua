--[[
    Paravel's UI - theme: Glass

    Frosted glass: see-through cool slate, round corners and round tiles,
    faint light lines, soft shadows instead of outlines.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Glass", {
    bg = rgb(0.09, 0.11, 0.15),        bgOpacity = 65,
    hover = 10,                        selected = 18,
    header = 6,                        stripe = 3,
    nested = 6,                        fillOpacity = 40,
    stateOpacity = 30,
    text = rgb(0.92, 0.95, 1),         muted = 60,
    textOnImage = "shadow",
    border = rgb(0.75, 0.82, 0.95),    borderOpacity = 25,
    borderWidth = 1,
    radius = 24,                       radiusSmall = 12,
    tileShape = "circle",
    barShape = "round",
    barThickness = 4,                  trackOpacity = 18,
    shadow = rgb(0.02, 0.03, 0.06),    shadowOpacity = 45,
    shadowOffset = 1,
    glow = rgb(0.85, 0.9, 1),          glowOpacity = 25,
    iconSize = 22,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 16,
    padding = 20,                      scrollWidth = 4,
    accent = rgb(0.35, 0.7, 0.9),
    success = rgb(0.4, 0.9, 0.75),     warning = rgb(0.95, 0.75, 0.3),
    danger = rgb(0.95, 0.35, 0.4),
    lightnessOffset = 12,              saturationOffset = 25,
    alphaOffset = 50,
    paletteColor1 = rgb(0.864, 0.456, 0.49),    paletteColor2 = rgb(0.449, 0.791, 0.449),
    paletteColor3 = rgb(0.874, 0.566, 0.771),   paletteColor4 = rgb(0.44, 0.685, 0.86),
    paletteColor5 = rgb(0.877, 0.65, 0.423),    paletteColor6 = rgb(0.348, 0.752, 0.651),
    paletteColor7 = rgb(0.675, 0.55, 0.85),     paletteColor8 = rgb(0.688, 0.509, 0.352),
    paletteColor9 = rgb(0.392, 0.772, 0.848),   paletteColor10 = rgb(0.598, 0.641, 0.703),
    paletteColor11 = rgb(0.872, 0.808, 0.488),  paletteColor12 = rgb(0.42, 0.42, 0.78),
})
