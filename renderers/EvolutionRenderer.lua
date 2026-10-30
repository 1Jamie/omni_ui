-- OmniUI Evolution Sequence Renderer
-- Modern volumetric presentation frame for generation-accurate evolution metamorphosis.
-- Preserves in-engine VM tick sync, cries, real silhouettes, and cancelability.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local PaletteFX = require("src.render.PaletteFX")
local Sprites = require("src.pokemon.Sprites")

local EvolutionRenderer = {}

local silhouetteShader = nil
local function getSilhouetteShader()
  if silhouetteShader == nil and love and love.graphics and love.graphics.newShader then
    local ok, sh = pcall(love.graphics.newShader, [[
      vec4 effect(vec4 color, Image tex, vec2 coords, vec2 screen_coords) {
        vec4 pixel = Texel(tex, coords);
        if (pixel.a < 0.05) { return vec4(0.0); }
        return vec4(color.rgb, pixel.a * color.a);
      }
    ]])
    silhouetteShader = (ok and sh) or false
  end
  return silhouetteShader
end

-- Checks which sprite form to display during the accelerating flash
local function evoShowsNew(t)
  if t < 0 then return false end
  for b = 1, 8 do
    local hold = 18 - 2 * b
    if t < hold then return false end
    t = t - hold
    local swap = b * 6
    if t < swap then return t % 6 < 3 end
    t = t - swap
  end
  return true
end

function EvolutionRenderer.draw(game, state, w, h, theme, subState, progress)
  theme = theme or require("mods.omni_ui.core.Theme").get()
  local data = game and game.data or {}
  local mon = state.mon or {}
  local newSpecies = state.newSpecies or mon.species
  local oldSpecies = mon.species or mon.speciesId or "UNKNOWN"

  local oldDef = data.pokemon and data.pokemon[oldSpecies]
  local newDef = data.pokemon and data.pokemon[newSpecies]
  local oldName = state.oldName or mon.nickname or (oldDef and oldDef.name) or oldSpecies
  local newName = (newDef and newDef.name) or newSpecies

  local t = state.t or 0
  local cancelGrace = 80
  local isDone = state.done == true
  local isCanceled = state.canceled == true
  local isCancelable = state.cancelable == true and (not isDone) and (t >= cancelGrace)

  -- 1. Outer Container & Ambient Background
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
  Layout.drawText("EVOLUTION METAMORPHOSIS", 20, 12, { font = "headline", color = theme.heading, bold = true })
  Layout.drawBadge(w - 180, 10, isDone and (isCanceled and "CANCELED" or "COMPLETED") or "IN PROGRESS", {
    kind = isDone and (isCanceled and "danger" or "good") or "team",
    font = "caption",
    height = 24,
  })

  -- 2. Center Stage & Volumetric Spotlight
  local stageW = math.min(w - 60, 560)
  local stageH = math.min(h - 180, 340)
  local stageX = math.floor((w - stageW) / 2)
  local stageY = 54
  local cx = stageX + math.floor(stageW / 2)
  local floorY = stageY + stageH - 46

  -- Darkened Stage Arena Card
  Layout.drawCard(stageX, stageY, stageW, stageH, {
    color = theme.surfaceHigh,
    borderColor = theme.border,
    radius = 12,
  })

  local pulse = math.sin((t or 0) * 0.12) * 0.5 + 0.5
  local accent = theme.accent or theme.colors.accent

  -- Overhead Spotlight Emitter Fixture
  local fixW = 72
  local fixH = 10
  local fixY = stageY + 6
  Layout.drawCard(cx - math.floor(fixW / 2), fixY, fixW, fixH, {
    color = theme.surface,
    borderColor = theme.borderStrong,
    borderWidth = 1,
    radius = 3,
  })
  -- Emitter Lens Glow
  love.graphics.setColor(theme.heading[1], theme.heading[2], theme.heading[3], 0.85)
  love.graphics.circle("fill", cx, fixY + fixH / 2, 4)
  love.graphics.setColor(accent[1], accent[2], accent[3], 0.4 + 0.3 * pulse)
  love.graphics.circle("fill", cx, fixY + fixH / 2, 8 + 3 * pulse)

  -- Volumetric Spotlight Cone Beam (Trapezoid spreading downward from emitter to stage floor)
  local beamTopHalf = 20
  local beamBottomHalf = 135
  local beamColor = { accent[1], accent[2], accent[3], 0.08 + 0.06 * pulse }
  love.graphics.setColor(beamColor)
  love.graphics.polygon("fill",
    cx - beamTopHalf, fixY + fixH,
    cx + beamTopHalf, fixY + fixH,
    cx + beamBottomHalf, floorY,
    cx - beamBottomHalf, floorY
  )

  -- Inner High-Intensity Spotlight Core
  local coreColor = { 1, 1, 1, 0.05 + 0.04 * pulse }
  love.graphics.setColor(coreColor)
  love.graphics.polygon("fill",
    cx - 10, fixY + fixH,
    cx + 10, fixY + fixH,
    cx + 70, floorY,
    cx - 70, floorY
  )

  -- Rising Ambient Energy Dust / Particles in Beam
  love.graphics.setColor(accent[1], accent[2], accent[3], 0.45 + 0.25 * pulse)
  for i = 1, 10 do
    local py = (stageY + 28) + ((t * 1.2 + i * 31) % (floorY - stageY - 36))
    local progressY = (py - (stageY + 28)) / (floorY - stageY - 36)
    local spread = 12 + progressY * 90
    local px = cx + math.sin(t * 0.04 + i * 1.7) * spread
    love.graphics.circle("fill", px, py, 1.2 + (i % 2) * 0.8)
  end

  -- 3. 3D Stage Pedestal (Cohesive Landing Base on Floor)
  -- Outer Ambient Light Pool
  love.graphics.setColor(accent[1], accent[2], accent[3], 0.14 + 0.08 * pulse)
  Layout.drawEllipse("fill", cx, floorY + 4, 146, 38)

  -- Bottom Shadow
  love.graphics.setColor(0, 0, 0, 0.45)
  Layout.drawEllipse("fill", cx, floorY + 12, 126, 28)

  -- Extruded Platform Bevel
  love.graphics.setColor(theme.surface[1], theme.surface[2], theme.surface[3], 0.95)
  Layout.drawEllipse("fill", cx, floorY + 8, 118, 26)
  love.graphics.rectangle("fill", cx - 118, floorY, 236, 8)

  -- Top Platform Disk
  love.graphics.setColor(theme.surfaceHigh[1], theme.surfaceHigh[2], theme.surfaceHigh[3], 0.98)
  Layout.drawEllipse("fill", cx, floorY, 118, 26)
  love.graphics.setColor(theme.borderStrong[1], theme.borderStrong[2], theme.borderStrong[3], 0.45)
  Layout.drawEllipse("line", cx, floorY, 118, 26)

  -- Concentric Expanding Energy Rings on Platform
  local rPhase1 = ((t * 2.0) % 80) / 80
  love.graphics.setColor(accent[1], accent[2], accent[3], (1 - rPhase1) * 0.6)
  Layout.drawEllipse("line", cx, floorY, 114 * rPhase1, 25 * rPhase1)

  local rPhase2 = ((t * 2.0 + 40) % 80) / 80
  love.graphics.setColor(accent[1], accent[2], accent[3], (1 - rPhase2) * 0.6)
  Layout.drawEllipse("line", cx, floorY, 114 * rPhase2, 25 * rPhase2)

  -- 4. In-Gen Authentic Sprite Rendering with Metamorphosis Sync
  local spriteImg = nil
  local isSilhouette = false
  local activeSpecies = oldSpecies

  if isDone then
    if isCanceled then
      activeSpecies = oldSpecies
      spriteImg = state.oldSprite
    else
      activeSpecies = newSpecies
      spriteImg = state.newSprite
    end
    isSilhouette = false
  elseif t < cancelGrace then
    activeSpecies = oldSpecies
    spriteImg = state.oldSprite
    isSilhouette = false
  else
    -- Flashing metamorphosis phase: dark silhouette alternating between forms
    local showNew = evoShowsNew(t - cancelGrace)
    activeSpecies = showNew and newSpecies or oldSpecies
    spriteImg = showNew and state.newSprite or state.oldSprite
    isSilhouette = true
  end

  -- Fallback sprite load if not already on state
  if not spriteImg then
    local path = Sprites.path(data, activeSpecies, "front")
    if path then
      local ok, img = pcall(love.graphics.newImage, path)
      if ok and img then spriteImg = img end
    end
  end

  if spriteImg then
    local iw, ih = spriteImg:getDimensions()
    local scale = 2.5
    local px = cx - math.floor((iw * scale) / 2)
    local py = floorY - math.floor(ih * scale) - 6

    local silShader = getSilhouetteShader()

    if isSilhouette then
      -- Metamorphosis phase: Darked out solid silhouette with luminous accent aura rim
      if silShader then
        love.graphics.setShader(silShader)

        -- 1. Outer luminous rim / energy aura
        local rimAlpha = 0.40 + 0.35 * pulse
        love.graphics.setColor(accent[1], accent[2], accent[3], rimAlpha)
        love.graphics.draw(spriteImg, px + 2, py, 0, scale, scale)
        love.graphics.draw(spriteImg, px - 2, py, 0, scale, scale)
        love.graphics.draw(spriteImg, px, py + 2, 0, scale, scale)
        love.graphics.draw(spriteImg, px, py - 2, 0, scale, scale)

        -- 2. Core solid dark silhouette (crushed dark ink)
        love.graphics.setColor(16 / 255, 20 / 255, 26 / 255, 1.0)
        love.graphics.draw(spriteImg, px, py, 0, scale, scale)

        love.graphics.setShader()
      else
        -- Fallback if shaders unsupported
        love.graphics.setColor(16 / 255, 20 / 255, 26 / 255, 1.0)
        love.graphics.draw(spriteImg, px, py, 0, scale, scale)
      end
    else
      -- Settled real species palette
      local shader = PaletteFX.shader()
      local monPal = PaletteFX.monPal(data, activeSpecies)
      if shader and monPal then
        love.graphics.setShader(shader)
        PaletteFX.sendColors(shader, monPal)
      end

      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(spriteImg, px, py, 0, scale, scale)

      if shader then
        love.graphics.setShader()
      end

      -- If newly evolved, draw radiant celebratory sparkle burst around mon
      if isDone and not isCanceled then
        local sparkPulse = math.sin((t or 0) * 0.18) * 0.5 + 0.5
        love.graphics.setColor(1, 0.9, 0.3, 0.6 + 0.3 * sparkPulse)
        for s = 1, 8 do
          local angle = s * (math.pi / 4) + (t * 0.03)
          local sDist = 65 + 10 * sparkPulse
          local sx = cx + math.cos(angle) * sDist
          local sy = (py + ih * scale * 0.5) + math.sin(angle) * (sDist * 0.65)
          love.graphics.circle("fill", sx, sy, 2.2)
        end
      end
    end
  end

  -- 5. Bottom Dialogue & Presentation Card
  local dialH = 88
  local dialY = h - dialH - 42
  local dialW = stageW
  local dialX = stageX

  Layout.drawCard(dialX, dialY, dialW, dialH, {
    color = theme.surface,
    borderColor = theme.borderStrong,
    borderWidth = 2,
    radius = 8,
  })

  if isDone then
    if isCanceled then
      Layout.drawText("Huh?", dialX + 20, dialY + 14, { font = "title", color = theme.colors.hpYellow, bold = true })
      Layout.drawText(("%s stopped evolving!"):format(oldName), dialX + 20, dialY + 42, { font = "button", color = theme.heading })
    else
      Layout.drawText("Congratulations!", dialX + 20, dialY + 14, { font = "title", color = theme.colors.hpGreen, bold = true })
      Layout.drawText(("Your %s evolved into %s!"):format(oldName, newName), dialX + 20, dialY + 42, { font = "button", color = theme.heading })
      
      -- New Typings preview badge on the right
      local newTypes = (newDef and newDef.types) or { "NORMAL" }
      local tx = dialX + dialW - 20
      for i = #newTypes, 1, -1 do
        local tName = newTypes[i]
        local bw = 70
        tx = tx - bw
        Widgets.drawTypeBadge(tName, tx, dialY + 28, { width = bw, height = 24, font = "tiny" })
        tx = tx - 6
      end
    end
  else
    Layout.drawText("What?", dialX + 20, dialY + 14, { font = "title", color = theme.colors.accent, bold = true })
    Layout.drawText(("%s is evolving!"):format(oldName), dialX + 20, dialY + 42, { font = "button", color = theme.heading })
  end

  -- 6. Bottom Action & Cancel Bar
  local footY = h - 38
  local hints = {}
  if isCancelable then
    hints = {
      { key = "B", label = "Cancel Evolution", primary = true },
    }
  elseif isDone then
    hints = {
      { key = "A", label = "Continue", primary = true },
    }
  end
  if #hints > 0 then
    Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = 16, columns = { 0 } })
  end
end

return EvolutionRenderer
