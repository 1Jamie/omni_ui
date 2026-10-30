-- Cyberpunk Neon Theme (v2.4)
-- Authentic industrial/sci-fi HUD with functional L-bracket corner anchors,
-- calibration scale micro-greebles, strict semantic color roles (Navy ground, Cyan bus, Magenta alert-only),
-- and solid high-contrast modal popups.

local Layout = nil
local function getLayout()
  if not Layout then Layout = require("mods.omni_ui.core.Layout") end
  return Layout
end

local theme = {
  id = "cyber",
  label = "Cyberpunk Neon",
  author = "Cartridge Studio",
  version = "2.4.0",

  colors = {
    -- Structural Ground (Deep Translucent / Opaque Navy)
    bg          = "#040711",
    surface     = "#09111E",
    surfaceHigh = "#060B14",
    raised      = "#102238",
    ink         = "#F8FAFC",

    -- Primary System Bus (Crisp Electric Cyan)
    border       = "#00F0FF35",
    borderStrong = "#00F0FF",
    accent       = "#00F0FF",
    accentDark   = "#102238",
    accentHover  = "#70F3FF",

    -- Priority / Action / State Shift Only (Hot Neon Magenta)
    magenta      = "#FF0055",
    purple       = "#7C3AED",

    -- Primary Data & Telemetry (Pure White & Slate)
    heading     = "#FFFFFF",
    text        = "#E2E8F0",
    detail      = "#94A3B8",
    textDim     = "#8899AC",
    textMuted   = "#475569",
    textInverse = "#040711",

    -- Functional Status Colors
    hpGreen     = "#00FF9D",
    hpYellow    = "#FFE600",
    hpRed       = "#FF0055",
    expBlue     = "#00F0FF",
  },

  metrics = {
    radius = {
      card     = 0,
      slot     = 0,
      button   = 0,
      badge    = 0,
      modal    = 0,
      dialogue = 0,
      pill     = 0,
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
      lg = 16,
      xl = 24,
    },
    gap = {
      xs = 4,
      sm = 6,
      md = 10,
      lg = 16,
    },
  },

  styles = {
    cardStyle   = "angled",
    buttonStyle = "sharp",
    badgeStyle  = "tag",
  },

  layout = {
    dock = {
      align         = "left",
      width         = 340,
      marginX       = 24,
      marginY       = 24,
      profileHeight = 72,
      itemHeight    = 44,
      itemGap       = 6,
      footerHeight  = 38,
    },
    dialogue = {
      maxWidth        = 740,
      height          = 118,
      marginBottom    = 22,
      nameplateHeight = 32,
      nameplateAlign  = "right",
      nameplateMargin = 20,
    },
    container = {
      maxWidth     = 860,
      maxHeight    = 530,
      headerHeight = 46,
      footerHeight = 38,
      gap          = 14,
    },
    pokedex = {
      leftWidth      = 330,
      rowHeight      = 40,
      rowGap         = 5,
      portraitHeight = 145,
    },
    bag = {
      leftRatio  = 0.52,
      rowHeight  = 42,
      rowGap     = 5,
      tabHeight  = 46,
    },
    party = {
      cardGap         = 6,
      previewBoxWidth = 58,
      meterHeight     = 6,
    },
    summary = {
      leftWidth      = 250,
      portraitHeight = 140,
      tabWidth       = 108,
    },
    shop = {
      leftRatio  = 0.52,
      rowHeight  = 42,
      rowGap     = 5,
    },
    options = {
      rowHeight = 48,
      rowGap    = 6,
    },
  },
}

-- =========================================================================
-- Geometry Helpers: 45-Degree Chamfer Polygons
-- =========================================================================

local function getChamferVerts(x, y, w, h, cut)
  cut = math.max(2, math.min(cut or 6, math.min(w, h) / 4))
  return {
    x + cut, y,
    x + w - cut, y,
    x + w, y + cut,
    x + w, y + h - cut,
    x + w - cut, y + h,
    x + cut, y + h,
    x, y + h - cut,
    x, y + cut,
  }
end

local function drawChamferPoly(mode, x, y, w, h, cut)
  local verts = getChamferVerts(x, y, w, h, cut)
  love.graphics.polygon(mode, verts)
end

-- =========================================================================
-- 1. Atmospheric Sci-Fi Background: Ambient Dot-Matrix & Corner HUD Framing
-- =========================================================================

function theme:drawBackground(vw, vh, kind, alpha)
  if kind == "start_menu" or kind == "dialogue" or kind == "save" or kind == "battle" then
    return
  end
  alpha = alpha or 1.0
  local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()

  -- 1. Planar Ambient Tech Dot-Matrix Grid
  local dotStep = 32
  local dotAlpha = 0.08 * alpha
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], dotAlpha)
  for dy = dotStep, vh - dotStep, dotStep do
    for dx = dotStep, vw - dotStep, dotStep do
      love.graphics.rectangle("fill", dx, dy, 1.5, 1.5)
    end
  end

  -- 2. Ambient Floating Data Packets
  local motes = 12
  for m = 1, motes do
    local seed = m * 97.31
    local mx = (math.sin(seed + now * 0.35) * 0.5 + 0.5) * vw
    local my = ((seed * 17.3 - now * 20) % vh)
    local mAlpha = (math.sin(now * 2.0 + seed) * 0.3 + 0.5) * 0.28 * alpha
    love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], mAlpha)
    love.graphics.rectangle("fill", mx, my, 2, 2)
  end

  -- 3. Viewport Perimeter HUD Tech Brackets
  local bPad = 12
  local bSize = 16
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.40 * alpha)
  love.graphics.setLineWidth(1.5)

  -- Top-Left Bracket
  love.graphics.line(bPad, bPad + bSize, bPad, bPad, bPad + bSize, bPad)
  -- Top-Right Bracket
  love.graphics.line(vw - bPad - bSize, bPad, vw - bPad, bPad, vw - bPad, bPad + bSize)
  -- Bottom-Left Bracket
  love.graphics.line(bPad, vh - bPad - bSize, bPad, vh - bPad, bPad + bSize, vh - bPad)
  -- Bottom-Right Bracket
  love.graphics.line(vw - bPad - bSize, vh - bPad, vw - bPad, vh - bPad, vw - bPad, vh - bPad - bSize)

  -- Top-Right Priority Alert Tag (Only place where magenta header status belongs)
  local L = getLayout()
  L.drawText("SYS.HUD // v2.4", bPad + bSize + 8, bPad - 1, { font = "tiny", color = { self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.55 * alpha }, bold = true })
  L.drawText("NET_LINK // ONLINE", vw - bPad - 130, bPad - 1, { font = "tiny", color = { self.colors.magenta[1], self.colors.magenta[2], self.colors.magenta[3], 0.70 * alpha }, bold = true })
end

-- =========================================================================
-- 2. Card Composition: Chamfered Navy Polygon with Functional L-Brackets
-- =========================================================================

function theme:drawCard(x, y, w, h, opts)
  opts = opts or {}
  local color = opts.color or self.colors.surface
  local borderColor = opts.borderColor or self.colors.border
  local cut = opts.cut or 8

  -- 1. Base Navy Fill (Chamfered Tech Polygon)
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.98)
  drawChamferPoly("fill", x, y, w, h, cut)

  if opts.border ~= false then
    -- 2. Connecting Perimeter Wireframe (Clean 1px muted line)
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.35)
    love.graphics.setLineWidth(opts.borderWidth or 1)
    drawChamferPoly("line", x, y, w, h, cut)

    -- 3. Functional Corner Reticle L-Brackets (2px Electric Cyan)
    local kLen = math.min(10, math.floor(math.min(w, h) / 4))
    if kLen >= 4 then
      love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.85)
      love.graphics.setLineWidth(2)

      -- Top-Left L-Bracket
      love.graphics.line(x + cut, y, x + cut + kLen, y)
      love.graphics.line(x, y + cut, x, y + cut + kLen)

      -- Top-Right L-Bracket
      love.graphics.line(x + w - cut - kLen, y, x + w - cut, y)
      love.graphics.line(x + w, y + cut, x + w, y + cut + kLen)

      -- Bottom-Left L-Bracket
      love.graphics.line(x + cut, y + h, x + cut + kLen, y + h)
      love.graphics.line(x, y + h - cut - kLen, x, y + h - cut)

      -- Bottom-Right L-Bracket
      love.graphics.line(x + w - cut - kLen, y + h, x + w - cut, y + h)
      love.graphics.line(x + w, y + h - cut - kLen, x + w, y + h - cut)
    end

    -- 4. Measurement Scale Hash Ticks (Top-Right Calibration Scale)
    if w >= 120 and h >= 44 then
      love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.60)
      local tickX = x + w - cut - 32
      local tickY = y + 2
      for t = 0, 3 do
        love.graphics.rectangle("fill", tickX + t * 4, tickY, 1, 3)
      end
    end

    -- 5. Data Bus Segmented Rail (Bottom-Center Cadence)
    if w >= 160 and h >= 50 then
      love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.40)
      local railStartX = x + math.floor((w - 32) / 2)
      for r = 0, 3 do
        love.graphics.rectangle("fill", railStartX + r * 8, y + h - 1, 5, 1)
      end
    end
  end
end

-- =========================================================================
-- 3. Slot Composition: Recessed Navy Bay with Precision Corner Notches
-- =========================================================================

function theme:drawSlot(x, y, w, h, opts)
  opts = opts or {}
  local color = opts.color or self.colors.surfaceHigh
  local borderColor = opts.borderColor or self.colors.border
  local cut = opts.cut or 4

  -- 1. Dark Solid Bay Fill
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.96)
  drawChamferPoly("fill", x, y, w, h, cut)

  if opts.border ~= false then
    -- 2. Precision Muted Wireframe
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.32)
    love.graphics.setLineWidth(opts.borderWidth or 1)
    drawChamferPoly("line", x, y, w, h, cut)

    -- 3. Corner Notch Pins
    love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.65)
    love.graphics.rectangle("fill", x + cut, y, 3, 1)
    love.graphics.rectangle("fill", x + w - cut - 3, y + h - 1, 3, 1)
  end
end

-- =========================================================================
-- 4. Button Composition: High-Contrast Active Accent Rail & Reticle Brackets
-- =========================================================================

function theme:drawButton(x, y, w, h, label, opts)
  opts = opts or {}
  local L = getLayout()
  local kind = opts.kind or "ghost"
  local isSel = opts.selected or false
  local cut = opts.cut or 6

  local fill = self.colors.surface
  local textColor = self.colors.text
  local borderColor = self.colors.border
  local borderWidth = 1
  local isBold = false

  local isDanger = (kind == "danger")

  if kind == "primary" or kind == "good" then
    fill = isSel and self.colors.raised or self.colors.hpGreen
    textColor = isSel and self.colors.heading or self.colors.textInverse
    borderColor = isSel and self.colors.borderStrong or self.colors.hpGreen
    borderWidth = isSel and 2 or 1
    isBold = true
  elseif isDanger then
    fill = isSel and self.colors.raised or self.colors.surfaceHigh
    textColor = self.colors.hpRed
    borderColor = isSel and self.colors.hpRed or self.colors.border
    borderWidth = isSel and 2 or 1
    isBold = true
  elseif isSel then
    -- Deep Focused Navy-Cyan Fill with High Contrast White Text
    fill = self.colors.raised
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

  local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
  local breathPulse = math.sin(now * 3.2) * 0.5 + 0.5
  local scanPhase   = math.sin(now * 2.2) * 0.5 + 0.5
  local laserPulse  = math.sin(now * 4.4) * 0.5 + 0.5

  -- 1. Outer Neon Aura Bloom when Selected
  if isSel then
    local auraAlpha = 0.14 + 0.08 * breathPulse
    love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], auraAlpha)
    drawChamferPoly("fill", x - 2, y - 2, w + 4, h + 4, cut + 2)
  end

  -- 2. Button Core Fill
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 1.0)
  drawChamferPoly("fill", x, y, w, h, cut)

  -- 3. Dynamic Scanning Laser Beam across entry background
  if isSel then
    local beamW = math.max(24, math.floor(w * 0.30))
    local beamX = x + math.floor((w - beamW) * scanPhase)
    local beamAlpha = 0.12 + 0.08 * laserPulse
    local bColor = isDanger and self.colors.hpRed or self.colors.accent
    love.graphics.setColor(bColor[1], bColor[2], bColor[3], beamAlpha)
    drawChamferPoly("fill", beamX, y + 1, beamW, h - 2, math.min(cut, 3))
  end

  -- 4. Perimeter Wireframe
  local borderAlpha = isSel and (0.85 + 0.15 * breathPulse) or (borderColor[4] or 1.0)
  love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderAlpha)
  love.graphics.setLineWidth(borderWidth)
  drawChamferPoly("line", x, y, w, h, cut)

  -- 5. Typography Label
  if label and label ~= "" then
    local fontName = opts.font or "button"
    local fh = L.textHeight(fontName)
    local textY = y + math.floor((h - fh) / 2)
    local align = opts.align or "center"
    local padLeft = (align == "left") and (opts.padX or 18) or 0
    local padRight = (align == "right") and (opts.padRight or opts.padX or 18) or 0
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

-- =========================================================================
-- 5. Status Badge: Microchip Tag with Illuminated Pip
-- =========================================================================

function theme:drawBadge(x, y, text, opts)
  opts = opts or {}
  local L = getLayout()
  text = tostring(text or ""):upper()

  local kind = opts.kind or "ghost"
  local fontName = opts.font or "tiny"
  local fw = L.textWidth(text, fontName)
  local fh = L.textHeight(fontName)
  local padX = opts.padX or 9
  local padY = opts.padY or 3
  local bw = opts.width or (fw + padX * 2 + 10)
  local bh = opts.height or (fh + padY * 2)
  local cut = 4

  local fill = self.colors.surfaceHigh
  local textColor = self.colors.textDim
  local borderColor = self.colors.border
  local ledColor = self.colors.accent

  if kind == "good" or kind == "loaded" or kind == "on" then
    fill = self.colors.raised
    textColor = self.colors.hpGreen
    borderColor = self.colors.hpGreen
    ledColor = self.colors.hpGreen
  elseif kind == "ready" then
    fill = self.colors.surfaceHigh
    textColor = self.colors.hpGreen
    borderColor = self.colors.hpGreen
    ledColor = self.colors.hpGreen
  elseif kind == "warn" or kind == "staged" then
    fill = self.colors.raised
    textColor = self.colors.hpYellow
    borderColor = self.colors.hpYellow
    ledColor = self.colors.hpYellow
  elseif kind == "danger" or kind == "err" then
    fill = self.colors.raised
    textColor = self.colors.hpRed
    borderColor = self.colors.hpRed
    ledColor = self.colors.hpRed
  elseif kind == "accent" or kind == "blue" or kind == "primary" or kind == "team" then
    fill = self.colors.raised
    textColor = self.colors.accent
    borderColor = self.colors.accent
    ledColor = self.colors.accent
  elseif kind == "gold" then
    fill = self.colors.raised
    textColor = self.colors.hpYellow
    borderColor = self.colors.hpYellow
    ledColor = self.colors.hpYellow
  end

  if opts.color then fill = opts.color end
  if opts.textColor then textColor = opts.textColor end
  if opts.borderColor then borderColor = opts.borderColor end

  -- 1. Microchip Tag Fill
  love.graphics.setColor(fill[1], fill[2], fill[3], fill[4] or 0.95)
  drawChamferPoly("fill", x, y, bw, bh, cut)

  -- 2. Perimeter Wireframe
  if borderColor then
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.8)
    love.graphics.setLineWidth(1)
    drawChamferPoly("line", x, y, bw, bh, cut)
  end

  -- 3. Illuminated LED Status Pip
  local ledY = y + math.floor(bh / 2)
  love.graphics.setColor(ledColor[1], ledColor[2], ledColor[3], 0.35)
  love.graphics.circle("fill", x + 8, ledY, 4)
  love.graphics.setColor(ledColor[1], ledColor[2], ledColor[3], 1.0)
  love.graphics.circle("fill", x + 8, ledY, 2)

  -- 4. Tag Text
  local textY = y + math.floor((bh - fh) / 2)
  L.drawText(text, x + 10, textY, {
    font = fontName,
    color = textColor,
    align = "center",
    width = bw - 12,
    bold = true,
  })

  return bw
end

-- =========================================================================
-- 6. Button Hint Pill: Tactile Terminal Keycap
-- =========================================================================

function theme:drawButtonHint(x, y, keyText, labelText, opts)
  opts = opts or {}
  local L = getLayout()
  local fontName = opts.font or "caption"
  local keyFont = opts.keyFont or "tiny"
  local kh = opts.height or 20
  local kw = math.max(kh, L.textWidth(keyText, keyFont) + 12)
  local kfh = L.textHeight(keyFont)
  local lfh = L.textHeight(fontName)

  -- Keycap Chamfered Base
  love.graphics.setColor(self.colors.surfaceHigh[1], self.colors.surfaceHigh[2], self.colors.surfaceHigh[3], 0.95)
  drawChamferPoly("fill", x, y, kw, kh, 3)

  -- Laser Neon Key Border
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.70)
  love.graphics.setLineWidth(1)
  drawChamferPoly("line", x, y, kw, kh, 3)

  -- Key Glyph
  local keyTextY = y + math.floor((kh - kfh) / 2)
  L.drawText(keyText, x, keyTextY, {
    font = keyFont,
    color = self.colors.heading,
    align = "center",
    width = kw,
    bold = true,
  })

  -- Action Description Label
  local labelX = x + kw + 8
  local labelY = y + math.floor((kh - lfh) / 2)
  L.drawText(labelText, labelX, labelY, {
    font = fontName,
    color = opts.textColor or self.colors.textDim,
  })

  local lw = L.textWidth(labelText, fontName)
  return kw + 8 + lw
end

-- =========================================================================
-- 7. Segmented Digital Health Meter & Energy Cells
-- =========================================================================

function theme:drawHealthBar(x, y, w, h, current, max, opts)
  opts = opts or {}
  local ratio = math.max(0, math.min(1, max > 0 and (current / max) or 0))

  -- 1. Outer Wireframe Housing
  love.graphics.setColor(self.colors.surfaceHigh[1], self.colors.surfaceHigh[2], self.colors.surfaceHigh[3], 0.95)
  love.graphics.rectangle("fill", x, y, w, h)
  love.graphics.setColor(self.colors.border[1], self.colors.border[2], self.colors.border[3], 0.45)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h)

  -- 2. Discrete Digital Energy Cells
  local totalBlocks = math.max(6, math.min(24, math.floor(w / 8)))
  local activeBlocks = math.ceil(totalBlocks * ratio)
  local blockGap = 1
  local blockW = math.max(2, math.floor((w - (totalBlocks + 1) * blockGap) / totalBlocks))

  local barColor = opts.color or self.colors.hpGreen
  if not opts.color then
    if ratio <= 0.20 then
      barColor = self.colors.hpRed
    elseif ratio <= 0.50 then
      barColor = self.colors.hpYellow
    end
  end

  for b = 1, totalBlocks do
    local bx = x + blockGap + (b - 1) * (blockW + blockGap)
    if b <= activeBlocks then
      love.graphics.setColor(barColor[1], barColor[2], barColor[3], 0.95)
      love.graphics.rectangle("fill", bx, y + 1, blockW, h - 2)
    else
      love.graphics.setColor(self.colors.raised[1], self.colors.raised[2], self.colors.raised[3], 0.40)
      love.graphics.rectangle("fill", bx, y + 1, blockW, h - 2)
    end
  end
end

-- =========================================================================
-- 8. Segmented Plasma Progress & Data Stream Meter
-- =========================================================================

function theme:drawProgressBar(x, y, w, h, current, max, opts)
  opts = opts or {}
  local ratio = math.max(0, math.min(1, max > 0 and (current / max) or 0))

  -- 1. Track Housing
  love.graphics.setColor(self.colors.surfaceHigh[1], self.colors.surfaceHigh[2], self.colors.surfaceHigh[3], 0.95)
  love.graphics.rectangle("fill", x, y, w, h)
  love.graphics.setColor(self.colors.border[1], self.colors.border[2], self.colors.border[3], 0.40)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h)

  -- 2. Segmented Plasma Blocks
  local totalBlocks = math.max(8, math.min(32, math.floor(w / 6)))
  local activeBlocks = math.ceil(totalBlocks * ratio)
  local blockGap = 1
  local blockW = math.max(2, math.floor((w - (totalBlocks + 1) * blockGap) / totalBlocks))
  local pColor = opts.color or self.colors.accent

  for b = 1, totalBlocks do
    local bx = x + blockGap + (b - 1) * (blockW + blockGap)
    if b <= activeBlocks then
      love.graphics.setColor(pColor[1], pColor[2], pColor[3], 0.95)
      love.graphics.rectangle("fill", bx, y + 1, blockW, h - 2)
    end
  end
end

-- =========================================================================
-- 9. Segmented Laser Scrollbar
-- =========================================================================

function theme:drawScrollBar(trackX, trackY, trackW, trackH, totalItems, visibleCount, scrollOffset, opts)
  opts = opts or {}
  if not totalItems or not visibleCount or totalItems <= visibleCount then return end
  trackW = trackW or 6
  local minThumbH = opts.minThumbH or 20
  local thumbH = math.max(minThumbH, math.floor(trackH * (visibleCount / totalItems)))
  local maxScroll = math.max(1, totalItems - visibleCount)
  local curScroll = scrollOffset or 0
  if opts.is1Indexed then curScroll = curScroll - 1 end
  curScroll = math.max(0, math.min(maxScroll, curScroll))
  local thumbY = trackY + math.floor((trackH - thumbH) * (curScroll / maxScroll))

  -- 1. Dark Laser Track
  love.graphics.setColor(self.colors.surfaceHigh[1], self.colors.surfaceHigh[2], self.colors.surfaceHigh[3], 0.9)
  love.graphics.rectangle("fill", trackX, trackY, trackW, trackH)
  love.graphics.setColor(self.colors.border[1], self.colors.border[2], self.colors.border[3], 0.3)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", trackX, trackY, trackW, trackH)

  -- 2. Glowing Neon Cyan Thumb
  love.graphics.setColor(self.colors.raised[1], self.colors.raised[2], self.colors.raised[3], 0.95)
  drawChamferPoly("fill", trackX, thumbY, trackW, thumbH, 2)
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 1.0)
  love.graphics.setLineWidth(1)
  drawChamferPoly("line", trackX, thumbY, trackW, thumbH, 2)

  -- 3. Center Crosshair Pip on Thumb
  if thumbH >= 12 then
    love.graphics.setColor(self.colors.heading[1], self.colors.heading[2], self.colors.heading[3], 0.9)
    love.graphics.rectangle("fill", trackX + 1, thumbY + math.floor(thumbH / 2) - 1, trackW - 2, 2)
  end
end

-- =========================================================================
-- 10. Holographic Scanning Pedestal for Monsters
-- =========================================================================

function theme:drawPedestal(x, y, rx, ry, opts)
  local L = getLayout()
  -- Outer laser field
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.16)
  L.drawEllipse("fill", x, y, rx, ry)
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.65)
  love.graphics.setLineWidth(1.5)
  L.drawEllipse("line", x, y, rx, ry)

  -- Inner concentric ring
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.35)
  love.graphics.setLineWidth(1)
  L.drawEllipse("line", x, y, math.floor(rx * 0.62), math.floor(ry * 0.62))

  -- Laser optical node ticks
  love.graphics.setColor(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.80)
  love.graphics.line(x - rx - 3, y, x - rx + 3, y)
  love.graphics.line(x + rx - 3, y, x + rx + 3, y)
  love.graphics.line(x, y - ry - 2, x, y - ry + 2)
  love.graphics.line(x, y + ry - 2, x, y + ry + 2)
end

return theme
