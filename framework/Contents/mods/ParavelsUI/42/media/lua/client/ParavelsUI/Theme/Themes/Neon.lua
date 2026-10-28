--[[
    Paravel's UI - theme: Neon

    Neon signs in the dark: near-black violet, cyan text, magenta lines and
    accents, a strong cyan glow behind icons and a magenta shadow, round
    shapes and colours at full saturation.
]]

require "ParavelsUI/Core/Color"
require "ParavelsUI/Theme/ThemePresets"

local rgb = PUI.Color.rgb

PUI.ThemePresets.define("Neon", {
    bg = rgb(0.04, 0.02, 0.08),        bgOpacity = 90,
    hover = 12,                        selected = 22,
    header = 8,                        stripe = 4,
    nested = 8,                        fillOpacity = 45,
    stateOpacity = 40,
    text = rgb(0.6, 0.95, 1),          muted = 60,
    textOnImage = "shadow",
    border = rgb(1, 0.2, 0.85),        borderOpacity = 80,
    borderWidth = 1,
    radius = 12,                       radiusSmall = 6,
    tileShape = "round",
    barShape = "round",
    barThickness = 4,                  trackOpacity = 25,
    shadow = rgb(0.5, 0, 0.6),         shadowOpacity = 60,
    shadowOffset = 1,
    glow = rgb(0.2, 0.9, 1),           glowOpacity = 35,
    iconSize = 22,                     iconSizeSmall = 22,
    gap = 8,                           sectionGap = 14,
    padding = 16,                      scrollWidth = 5,
    accent = rgb(1, 0.2, 0.85),
    success = rgb(0.2, 1, 0.6),        warning = rgb(1, 0.85, 0.1),
    danger = rgb(1, 0.15, 0.35),
    lightnessOffset = 15,              saturationOffset = 0,
    alphaOffset = 50,
    paletteColor1 = rgb(1, 0.1, 0.7),           paletteColor2 = rgb(0, 0.917, 1),
    paletteColor3 = rgb(0.84, 0.24, 0.96),      paletteColor4 = rgb(0.1, 0.55, 1),
    paletteColor5 = rgb(1, 0.2, 0.467),         paletteColor6 = rgb(0.04, 0.76, 0.7),
    paletteColor7 = rgb(0.563, 0.278, 0.962),   paletteColor8 = rgb(0.646, 0.114, 0.646),
    paletteColor9 = rgb(0.24, 0.81, 1),         paletteColor10 = rgb(0.28, 0.28, 0.92),
    paletteColor11 = rgb(0.972, 0.468, 0.72),   paletteColor12 = rgb(0.07, 0.443, 0.63),
})
