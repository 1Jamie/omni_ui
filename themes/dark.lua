-- Dark Modern Theme (Default)
-- Sleek graphite surfaces, crisp contrast, sapphire accents.

return {
  id = "dark",
  label = "Dark Modern",
  author = "Cartridge Studio",
  version = "2.0.0",

  colors = {
    bg          = "#14181D",
    surface     = "#1D2229",
    surfaceHigh = "#181D23",
    raised      = "#2A313B",
    ink         = "#F0F4F9",

    border       = "#8B9DB459",
    borderStrong = "#FFFFFF",

    accent       = "#4CA3F0",
    accentDark   = "#246AB5",
    accentHover  = "#78B9FF",

    heading     = "#F5F7FA",
    text        = "#EAEFF5",
    detail      = "#C8C8C8",
    textDim     = "#A1ACBB",
    textMuted   = "#7D8796",
    textInverse = "#12161C",

    hpGreen     = "#55E887",
    hpYellow    = "#FFD600",
    hpRed       = "#FF505A",
    expBlue     = "#4CA3F0",
  },

  metrics = {
    radius = {
      card     = 8,
      slot     = 6,
      button   = 6,
      badge    = 4,
      modal    = 10,
      dialogue = 12,
      pill     = 14,
    },
    borderWidth = {
      hairline = 1,
      normal   = 1.5,
      focus    = 2,
    },
  },

  styles = {
    cardStyle   = "flat",
    buttonStyle = "rounded",
    badgeStyle  = "pill",
  },

  layout = {
    dock = {
      align = "right",
      width = 290,
    },
    dialogue = {
      nameplateAlign = "left",
    },
  },
}
