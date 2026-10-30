-- OmniUI Intro & Oak Speech Scene Compositor
-- Renders theme-driven laboratory backdrop, ambient illumination, tech pedestals, and blits character sprites.

local Layout = require("mods.omni_ui.core.Layout")

local IntroRenderer = {}

function IntroRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  -- Intro UI overlay rendering (dialogue, menus, and naming handle their own UI cards in ModernOverlay)
end

--- Composites the complete intro scene (background, ambient lights/pedestal, and character sprites)
--- @param renderer table Engine renderer instance
--- @param ctx table Frame composition context { uiCanvas, ww, wh, ox, oy, Sx, Sy, zones }
--- @param theme table Active OmniUI theme table
--- @param oakSpeechState table|nil Active OakSpeech state
--- @param game table|nil Active game instance
--- @return boolean True if handled
function IntroRenderer.composeIntroScene(renderer, ctx, theme, oakSpeechState, game)
  if not ctx or not ctx.uiCanvas then return false end
  if not (love and love.graphics) then return true end
  local ww, wh = ctx.ww, ctx.wh
  local ox, oy = ctx.ox, ctx.oy
  local sx, sy = ctx.Sx, ctx.Sy
  local dpiX, dpiY = ctx.dpiX or 1, ctx.dpiY or 1

  local initDepth = love.graphics.getStackDepth and love.graphics.getStackDepth() or 0
  love.graphics.push("all")

  local drawEllipse = function(mode, x, y, rx, ry)
    if love and love.graphics and love.graphics.ellipse then
      love.graphics.ellipse(mode, x, y, rx, ry)
    end
  end

  local drawRect = function(mode, x, y, w, h)
    if love and love.graphics and love.graphics.rectangle then
      love.graphics.rectangle(mode, x, y, w, h)
    end
  end

  -- 1. Theme Background Fill (or theme custom backdrop)
  local bg = theme.bg or { 0.08, 0.09, 0.13 }
  love.graphics.setColor(bg[1], bg[2], bg[3], 1.0)
  drawRect("fill", 0, 0, ww, wh)

  -- 2. Theme Atmospheric Layer
  if theme.drawBackground and type(theme.drawBackground) == "function" then
    pcall(theme.drawBackground, theme, ww, wh, "intro", 1.0)
  end

  local isPortrait = (ww < wh * 0.95)
  local portraitShiftY = 0
  if isPortrait then
    -- Shift pedestal and character sprite into upper active stage area so dialogue (at y = 0.44 * wh)
    -- sits cleanly below the pedestal without clipping the character sprite or pedestal base.
    local targetEffectiveOy = math.floor(wh * 0.44) - 10 - math.floor(91 * sy)
    local maxShift = math.max(0, oy - 20)
    portraitShiftY = math.min(maxShift, math.max(0, oy - targetEffectiveOy))
  end
  local effectiveOy = oy - portraitShiftY

  -- 3. Modern Tech Pedestal & Spotlight under character sprite
  local isLight = theme.isLight or (theme.bg and (theme.bg[1] + theme.bg[2] + theme.bg[3]) / 3 > 0.7)
  local slide = (oakSpeechState and oakSpeechState.picSlide) or 0
  local spriteCenterX = ox + math.floor((76 + slide) * sx)
  local spriteBaseY = effectiveOy + math.floor(88 * sy)
  local platRx = math.floor(34 * sx)
  local platRy = math.floor(platRx * 0.28)
  local platDepth = math.max(2, math.floor(3 * sy))

  local surfColor = theme.colors.surface or (isLight and { 0.88, 0.92, 0.84 } or { 0.16, 0.18, 0.24 })
  local rimColor = theme.colors.surfaceHigh or theme.colors.raised or (isLight and { 0.82, 0.88, 0.78 } or { 0.22, 0.24, 0.32 })
  local crustColor = theme.colors.crust or theme.bg or (isLight and { 0.75, 0.82, 0.70 } or { 0.09, 0.10, 0.14 })
  local accentColor = theme.accent or (isLight and { 0.30, 0.55, 0.35 } or { 0.20, 0.80, 0.95 })
  local edgeColor = theme.colors.borderStrong or theme.colors.border or (isLight and { 0.40, 0.50, 0.40 } or { 0.30, 0.35, 0.45 })

  if not isLight then
    -- 1. Outer Floor Ambient Spotlight Pool (sharing the exact same floor plane and 0.28 perspective tilt)
    local floorGlowRx = math.floor(platRx * 1.60)
    local floorGlowRy = math.floor(floorGlowRx * 0.28)
    love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], 0.10)
    drawEllipse("fill", spriteCenterX, spriteBaseY + platDepth, floorGlowRx, floorGlowRy)

    -- 2. Soft Ground Shadow
    love.graphics.setColor(0, 0, 0, 0.40)
    drawEllipse("fill", spriteCenterX, spriteBaseY + platDepth + 2 * sy, platRx + 4 * sx, platRy + 2 * sy)
  else
    -- Soft Ground Shadow for Light / Classic Theme
    love.graphics.setColor(0, 0, 0, 0.15)
    drawEllipse("fill", spriteCenterX, spriteBaseY + platDepth + 2 * sy, platRx + 4 * sx, platRy + 2 * sy)
  end

  -- 3. Cylinder 3D body
  love.graphics.setColor(crustColor[1], crustColor[2], crustColor[3], 0.95)
  drawEllipse("fill", spriteCenterX, spriteBaseY + platDepth, platRx, platRy)
  drawRect("fill", spriteCenterX - platRx, spriteBaseY, platRx * 2, platDepth)

  -- 4. Top platform disk
  love.graphics.setColor(surfColor[1], surfColor[2], surfColor[3], 0.95)
  drawEllipse("fill", spriteCenterX, spriteBaseY, platRx, platRy)

  -- 5. Inner decorative glow rings
  love.graphics.setColor(rimColor[1], rimColor[2], rimColor[3], 0.70)
  drawEllipse("fill", spriteCenterX, spriteBaseY, platRx * 0.78, platRy * 0.78)

  love.graphics.setColor(accentColor[1], accentColor[2], accentColor[3], isLight and 0.15 or 0.30)
  drawEllipse("fill", spriteCenterX, spriteBaseY, platRx * 0.48, platRy * 0.48)

  -- 6. Rim accent outline
  love.graphics.setColor(edgeColor[1], edgeColor[2], edgeColor[3], 0.75)
  if love.graphics.setLineWidth then love.graphics.setLineWidth(1.5) end
  drawEllipse("line", spriteCenterX, spriteBaseY, platRx, platRy)

  -- 4. Draw character sprite directly with transparency onto the pedestal
  if oakSpeechState and (oakSpeechState.drawPic or oakSpeechState.drawPlayerIcon) then
    love.graphics.push()
    love.graphics.translate(ox, effectiveOy)
    love.graphics.scale(sx, sy)
    if oakSpeechState.drawPic then
      pcall(function() oakSpeechState:drawPic() end)
    end
    if oakSpeechState.drawPlayerIcon then
      pcall(function() oakSpeechState:drawPlayerIcon() end)
    end
    love.graphics.pop()
  elseif oakSpeechState and (oakSpeechState.pic or (oakSpeechState.walkVisible and oakSpeechState.walkSheet)) then
    love.graphics.push()
    love.graphics.translate(ox, effectiveOy)
    love.graphics.scale(sx, sy)

    local PaletteFX = package.loaded["src.render.PaletteFX"]
    if not PaletteFX then pcall(function() PaletteFX = require("src.render.PaletteFX") end) end
    local shader = (not oakSpeechState.picTrueColor) and PaletteFX and PaletteFX.shader and PaletteFX.shader()
    local zones = nil
    if oakSpeechState and oakSpeechState.sgbPalettes and game then
      pcall(function() zones = oakSpeechState:sgbPalettes(game) end)
    end
    zones = zones or (ctx and ctx.zones)
    local pal = (zones and zones[1] and zones[1].colors)
      or (PaletteFX and PaletteFX.pal and PaletteFX.pal(game and game.data, "MEWMON"))
      or (PaletteFX and PaletteFX.pal and PaletteFX.pal(package.loaded["src.core.Data"], "MEWMON"))
    if shader and pal then
      love.graphics.setShader(shader)
      PaletteFX.sendColors(shader, pal)
    end

    if oakSpeechState.pic then
      local pic = oakSpeechState.pic
      local w, h = pic:getDimensions()
      local x = 48 + math.floor((8 - w / 8) / 2) * 8 + (oakSpeechState.picSlide or 0)
      local y = 32 + (7 - h / 8) * 8
      local reveal = oakSpeechState.picReveal
      local off = 0
      if reveal and reveal.kind == "wipe" then
        off = math.floor((160 - x) * (1 - math.min(1, reveal.t / reveal.dur)))
      end
      love.graphics.setColor(1, 1, 1, 1)
      if oakSpeechState.picFlip then
        love.graphics.draw(pic, x + off + w, y, 0, -1, 1)
      else
        love.graphics.draw(pic, x + off, y)
      end
    end
    if oakSpeechState.walkVisible and oakSpeechState.walkSheet and oakSpeechState.walkImage then
      local walkQuad = oakSpeechState.walkQuad or love.graphics.newQuad(0, 0, 16, 16, oakSpeechState.walkSheet:getDimensions())
      local img = oakSpeechState:walkImage()
      if img then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, walkQuad, 64, 60)
      end
    end

    if shader and pal then
      love.graphics.setShader()
    end
    love.graphics.pop()
  else
    -- Fallback blit if no state methods
    love.graphics.setColor(1, 1, 1, 1)
    if renderer.blitCanvas then
      renderer:blitCanvas(ctx.uiCanvas, sx, sy, ctx.zones, sx, sy, ox, effectiveOy,
                          ctx.viewX or 0, ctx.viewY or 0, ctx.viewWidth or ww, ctx.viewHeight or wh,
                          dpiX, dpiY)
    elseif love.graphics.draw then
      love.graphics.draw(ctx.uiCanvas, ox, effectiveOy, 0, sx, sy)
    end
  end

  love.graphics.pop()
  if love and love.graphics and love.graphics.getStackDepth then
    while love.graphics.getStackDepth() > initDepth do
      love.graphics.pop()
    end
  end

  return true
end

return IntroRenderer
