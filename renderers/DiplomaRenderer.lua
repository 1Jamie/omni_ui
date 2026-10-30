-- OmniUI Game Freak 151 Completion Diploma Renderer
-- Canvas-segregated presentation frame: renders authentic 160x144 pixel-art certificate
-- onto an isolated nearest-filtered canvas, mounted inside a theme-reactive commemorative plaque.

local Layout = require("mods.omni_ui.core.Layout")
local Diploma = require("src.ui.Diploma")

local DiplomaRenderer = {}

local diplomaCanvas = nil

local function getDiplomaCanvas()
  if not diplomaCanvas and love and love.graphics and love.graphics.newCanvas then
    local ok, c = pcall(love.graphics.newCanvas, 160, 144)
    if ok and c then
      c:setFilter("nearest", "nearest")
      diplomaCanvas = c
    end
  end
  return diplomaCanvas
end

function DiplomaRenderer.draw(game, state, w, h, theme, subState, progress)
  theme = theme or require("mods.omni_ui.core.Theme").get()
  local save = game and game.save or {}
  local player = save.player or {}
  local playerName = player.name or save.playerName or "TRAINER"
  local trainerId = player.id or save.playerID or save.trainerId or 0

  -- 1. Outer Frame & Velvet Backing
  Layout.drawCard(0, 0, w, h, {
    color = theme.bg,
    borderColor = theme.border,
    radius = 0,
  })

  -- Top Header
  Layout.drawCard(0, 0, w, 44, {
    color = theme.surface,
    borderColor = theme.border,
    radius = 0,
  })
  Layout.drawText("GAME FREAK • OFFICIAL POKÉDEX DIPLOMA", 20, 12, { font = "headline", color = theme.heading, bold = true })
  Layout.drawBadge(w - 180, 10, "151 / 151 COMPLETE", { kind = "gold", font = "caption", height = 24 })

  -- 2. Commemorative Presentation Plaque
  local plaqueW = math.min(w - 60, 680)
  local plaqueH = h - 96
  local plaqueX = math.floor((w - plaqueW) / 2)
  local plaqueY = 52

  Layout.drawCard(plaqueX, plaqueY, plaqueW, plaqueH, {
    color = theme.surface,
    borderColor = theme.hpYellow,
    borderWidth = 2,
    radius = 12,
  })

  -- Gold Embossed Master Seal
  Layout.drawBadge(plaqueX + 24, plaqueY + 16, "★  OFFICIAL GAME FREAK MASTER DIPLOMA  ★", { kind = "gold", font = "button" })
  Layout.drawText(("AWARDED TO: %s  •  ID NO. %05d"):format(playerName, trainerId), plaqueX + 24, plaqueY + 48, { font = "caption", color = theme.textDim })

  -- 3. Isolated Canvas Rendering of the Authentic 160x144 Certificate
  local canvas = getDiplomaCanvas()
  local certW = 160
  local certH = 144
  local scale = math.min(math.floor((plaqueW - 48) / certW), math.floor((plaqueH - 120) / certH))
  if scale < 1 then scale = 1 end
  if scale > 2.5 then scale = 2.5 end

  local drawW = certW * scale
  local drawH = certH * scale
  local cx = plaqueX + math.floor((plaqueW - drawW) / 2)
  local cy = plaqueY + 74 + math.floor((plaqueH - 140 - drawH) / 2)

  if canvas and love and love.graphics and love.graphics.setCanvas then
    -- Render authentic pixel certificate to segregated nearest-neighbor canvas
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.origin()
    Diploma.render(game)
    love.graphics.setCanvas()
    love.graphics.pop()

    -- Outer Certificate Matting Border
    Layout.drawSlot(cx - 6, cy - 6, drawW + 12, drawH + 12, {
      color = theme.surfaceHigh,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 4,
    })

    -- Draw nearest-filtered canvas onto modern plaque
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, cx, cy, 0, scale, scale)
  else
    -- Fallback inline draw if canvases are unavailable
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    Diploma.render(game)
    love.graphics.pop()
  end

  -- Plaque Footer Engraving
  local footY = plaqueY + plaqueH - 34
  Layout.drawText("CERTIFIED BY GAME FREAK INC. • ALL 151 POKÉMON CAUGHT", plaqueX + 24, footY, { font = "tiny", color = theme.textMuted })
  Layout.drawBadge(plaqueX + plaqueW - 140, footY - 4, "GAME FREAK SEAL", { kind = "gold", font = "tiny" })

  -- Action bar
  local footY = h - 38
  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait
  local hints = {
    { key = "A", label = "Close Diploma", primary = true },
    { key = "B", label = "Back" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return DiplomaRenderer
