-- Hoenn Emerald Theme
-- Serene organic glassmorphism, floating glass islands, frosted jade & mint hues, and centered dock layout.

local Layout = nil
local function getLayout()
  if not Layout then Layout = require("mods.omni_ui.core.Layout") end
  return Layout
end

local theme = {
  id = "emerald",
  label = "Hoenn Emerald",
  author = "Cartridge Studio",
  version = "2.1.0",

  colors = {
    bg          = "#0B1410",
    surface     = "#122019",
    surfaceHigh = "#0E1A14",
    raised      = "#1A2E24",
    ink         = "#EEF9F2",

    border       = "#449E6E59",
    borderStrong = "#7EFFBF",

    accent       = "#00E676",
    accentDark   = "#008744",
    accentHover  = "#5CFF9F",

    heading     = "#E6FAF0",
    text        = "#D0F2E0",
    detail      = "#B0DCC1",
    textDim     = "#88BE9E",
    textMuted   = "#568269",
    textInverse = "#08160E",

    hpGreen     = "#00E676",
    hpYellow    = "#FACC15",
    hpRed       = "#FB7185",
    expBlue     = "#38BDF8",
  },

  metrics = {
    radius = {
      card     = 16,
      slot     = 12,
      button   = 14,
      badge    = 10,
      modal    = 18,
      dialogue = 18,
      pill     = 16,
    },
    borderWidth = {
      hairline = 1,
      normal   = 1.5,
      focus    = 2,
    },
    padding = {
      xs = 4,
      sm = 8,
      md = 12,
      lg = 18,
      xl = 26,
    },
    gap = {
      xs = 4,
      sm = 6,
      md = 10,
      lg = 16,
    },
  },

  styles = {
    cardStyle   = "glass",
    buttonStyle = "pill",
    badgeStyle  = "pill",
  },

  layout = {
    dock = {
      align         = "center", -- Floating center island dock
      width         = 330,
      marginX       = 24,
      marginY       = 26,
      profileHeight = 76,
      itemHeight    = 44,
      itemGap       = 8,
      footerHeight  = 38,
    },
    dialogue = {
      maxWidth        = 680,
      height          = 118,
      marginBottom    = 26,
      nameplateHeight = 32,
      nameplateAlign  = "center", -- Centered floating glass speech bubble
      nameplateMargin = 20,
    },
    container = {
      maxWidth     = 810,
      maxHeight    = 515,
      headerHeight = 46,
      footerHeight = 38,
      gap          = 14,
    },
    pokedex = {
      leftWidth      = 320,
      rowHeight      = 38,
      rowGap         = 5,
      portraitHeight = 140,
    },
    bag = {
      leftRatio  = 0.54,
      rowHeight  = 40,
      rowGap     = 5,
      tabHeight  = 46,
    },
    party = {
      cardGap         = 6,
      previewBoxWidth = 58,
      meterHeight     = 6,
    },
    summary = {
      leftWidth      = 240,
      portraitHeight = 138,
      tabWidth       = 106,
    },
    shop = {
      leftRatio  = 0.54,
      rowHeight  = 40,
      rowGap     = 5,
    },
    options = {
      rowHeight = 48,
      rowGap    = 6,
    },
  },
}

-- Custom Composition: Frosted Glass Floating Island Card
function theme:drawCard(x, y, w, h, opts)
  opts = opts or {}
  local color = opts.color or self.colors.surface
  local borderColor = opts.borderColor or self.colors.border
  local radius = opts.radius or (self.metrics and self.metrics.radius.card or 16)

  -- 1. Ambient Glass Outer Glow
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.05)
  love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, radius + 2, radius + 2)

  -- 2. Translucent Frosted Base Fill
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.94)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  -- 3. Top Glass Reflection Sheen
  if h >= 32 and w >= 32 then
    love.graphics.setColor(1, 1, 1, 0.05)
    local glossH = math.max(8, math.floor(h * 0.38))
    love.graphics.rectangle("fill", x + 6, y + 2, w - 12, glossH, math.max(4, radius - 4), math.max(4, radius - 4))
  end

  -- 4. Mint Glass Perimeter Line
  if opts.border ~= false then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.38)
    love.graphics.setLineWidth(opts.borderWidth or 1)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
  end
end

-- Custom Composition: Smooth Frosted Slot
function theme:drawSlot(x, y, w, h, opts)
  opts = opts or {}
  local color = opts.color or self.colors.surfaceHigh
  local borderColor = opts.borderColor or self.colors.border
  local radius = opts.radius or (self.metrics and self.metrics.radius.slot or 12)

  -- 1. Frosted Recessed Fill
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.92)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  -- 2. Perimeter Line
  if opts.border ~= false then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.30)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
  end
end

-- Custom Composition: Floating Pill Button with Glass Sheen
function theme:drawButton(x, y, w, h, label, opts)
  opts = opts or {}
  local L = getLayout()
  local kind = opts.kind or "ghost"
  local isSel = opts.selected or false
  local radius = opts.radius or (self.metrics and self.metrics.radius.button or 14)

  local fill = self.colors.surface
  local textColor = self.colors.text
  local borderColor = self.colors.border
  local borderWidth = 1
  local isBold = false

  if kind == "primary" or kind == "good" then
    fill = self.colors.hpGreen
    textColor = self.colors.textInverse
    borderColor = isSel and self.colors.borderStrong or self.colors.hpGreen
    borderWidth = isSel and 2 or 1
    isBold = true
  elseif kind == "accent" or (isSel and kind ~= "ghost") then
    fill = self.colors.accentDark
    textColor = self.colors.heading
    borderColor = isSel and self.colors.borderStrong or self.colors.accent
    borderWidth = isSel and 2 or 1
    isBold = true
  elseif kind == "danger" then
    fill = self.colors.surface
    textColor = self.colors.hpRed
    borderColor = isSel and self.colors.borderStrong or self.colors.hpRed
    borderWidth = isSel and 2 or 1
  elseif isSel then
    fill = self.colors.accentDark
    textColor = self.colors.heading
    borderColor = self.colors.borderStrong
    borderWidth = 2
    isBold = true
  else
    fill = self.colors.surfaceHigh
    textColor = self.colors.text
    borderColor = self.colors.border
    borderWidth = 1
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  -- 1. Outer Pill Ambient Glow on Selection
  if isSel then
    love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.16)
    love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, radius + 2, radius + 2)
  end

  -- 2. Button Fill
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1.0)
  love.graphics.rectangle("fill", x, y, w, h, radius, radius)

  -- 3. Upper Pill Glass Gloss Reflection
  if h >= 20 and (isSel or kind == "primary" or kind == "accent") then
    love.graphics.setColor(1, 1, 1, 0.16)
    love.graphics.rectangle("fill", x + 4, y + 1, w - 8, math.floor(h * 0.42), math.max(2, radius - 4), math.max(2, radius - 4))
  end

  -- 4. Pill Border
  love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1.0)
  love.graphics.setLineWidth(borderWidth)
  love.graphics.rectangle("line", x, y, w, h, radius, radius)

  -- 5. Label
  if label and label ~= "" then
    local fontName = opts.font or "button"
    local fh = L.textHeight(fontName)
    local textY = y + math.floor((h - fh) / 2)
    local align = opts.align or "center"
    local padLeft = (align == "left") and (opts.padX or 16) or 0
    local padRight = (align == "right") and (opts.padRight or opts.padX or 16) or 0
    local textW = (align == "center") and w or (w - padLeft - padRight - 6)
    L.drawText(label, x + padLeft, textY, {
      font = fontName,
      color = textColor,
      align = align,
      width = textW,
      bold = isBold,
    })
  end
end

-- Custom Composition: Capsule Status Pill Badge
function theme:drawBadge(x, y, text, opts)
  opts = opts or {}
  local L = getLayout()
  text = tostring(text or ""):upper()

  local kind = opts.kind or "ghost"
  local fontName = opts.font or "tiny"
  local fw = L.textWidth(text, fontName)
  local fh = L.textHeight(fontName)
  local padX = opts.padX or 10
  local padY = opts.padY or 4
  local bw = opts.width or (fw + padX * 2)
  local bh = opts.height or (fh + padY * 2)
  local radius = opts.radius or (self.metrics and self.metrics.radius.badge or 10)

  local fill = self.colors.surfaceHigh
  local textColor = self.colors.textDim
  local borderColor = self.colors.border

  if kind == "good" or kind == "loaded" or kind == "on" then
    fill = self.colors.hpGreen
    textColor = self.colors.textInverse
    borderColor = self.colors.hpGreen
  elseif kind == "ready" then
    fill = self.colors.surfaceHigh
    textColor = self.colors.hpGreen
    borderColor = self.colors.hpGreen
  elseif kind == "warn" or kind == "staged" then
    fill = self.colors.hpYellow
    textColor = self.colors.textInverse
    borderColor = self.colors.hpYellow
  elseif kind == "danger" or kind == "err" then
    fill = self.colors.hpRed
    textColor = self.colors.heading
    borderColor = self.colors.hpRed
  elseif kind == "accent" or kind == "blue" or kind == "primary" then
    fill = self.colors.accentDark
    textColor = self.colors.heading
    borderColor = self.colors.borderStrong
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  -- 1. Capsule Fill
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 0.95)
  love.graphics.rectangle("fill", x, y, bw, bh, radius, radius)

  -- 2. Upper Pill Highlight
  if bh >= 16 then
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.rectangle("fill", x + 3, y + 1, bw - 6, math.floor(bh * 0.40), radius, radius)
  end

  -- 3. Border
  if borderColor then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, bw, bh, radius, radius)
  end

  -- 4. Text
  local textY = y + math.floor((bh - fh) / 2)
  L.drawText(text, x, textY, {
    font = fontName,
    color = textColor,
    align = "center",
    width = bw,
    bold = (fill == self.colors.hpGreen or fill == self.colors.hpYellow or kind == "primary"),
  })

  return bw
end

-- Custom Composition: Floating Capsule Jade Scrollbar
function theme:drawScrollBar(trackX, trackY, trackW, trackH, totalItems, visibleCount, scrollOffset, opts)
  opts = opts or {}
  if not totalItems or not visibleCount or totalItems <= visibleCount then return end
  trackW = trackW or 6
  local minThumbH = opts.minThumbH or 22
  local thumbH = math.max(minThumbH, math.floor(trackH * (visibleCount / totalItems)))
  local maxScroll = math.max(1, totalItems - visibleCount)
  local curScroll = scrollOffset or 0
  if opts.is1Indexed then curScroll = curScroll - 1 end
  curScroll = math.max(0, math.min(maxScroll, curScroll))
  local thumbY = trackY + math.floor((trackH - thumbH) * (curScroll / maxScroll))
  local rad = math.floor(trackW / 2)

  -- 1. Soft Frosted Pill Track
  love.graphics.setColor(self.colors.surfaceHigh[1], self.colors.surfaceHigh[2], self.colors.surfaceHigh[3], 0.85)
  love.graphics.rectangle("fill", trackX, trackY, trackW, trackH, rad, rad)

  -- 2. Floating Jade Capsule Thumb
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.85)
  love.graphics.rectangle("fill", trackX, thumbY, trackW, thumbH, rad, rad)
  love.graphics.setColor(self.colors.borderStrong[1], self.colors.borderStrong[2], self.colors.borderStrong[3], 0.95)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", trackX, thumbY, trackW, thumbH, rad, rad)
end

return theme
