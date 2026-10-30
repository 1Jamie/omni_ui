-- OmniUI Modern Battle Interface Renderer
-- UI-Only cross-generation battle chrome overlay: floating battler HUDs, command deck, move matrix, and 2v2 targeting.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local MoveDatabase = require("mods.omni_ui.core.MoveDatabase")
local HookBoundary = require("mods.omni_ui.core.HookBoundary")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local BattleRenderer = {}

local function isMaleGender(gender)
  local g = tostring(gender or ""):upper()
  return g == "M" or g == "MALE"
end

local function wrappedLineCount(text, fontName, width)
  text = Layout.cleanText(tostring(text or ""))
  local font = Layout.getFont(fontName)
  if width > 0 and font and font.getWrap then
    local _, lines = font:getWrap(text, width)
    if type(lines) == "table" then return math.max(1, #lines) end
  end
  local tw = Layout.textWidth(text, fontName)
  return math.max(1, math.ceil(tw / math.max(1, width)))
end

local MOVE_CARD_GAP = 10
local MOVE_CARD_MAX_H = 104

local function moveGridFrame(deckY, deckH)
  local rawH = math.floor((deckH - MOVE_CARD_GAP) / 2)
  local cardH = math.min(math.max(rawH, 0), MOVE_CARD_MAX_H)
  local gridH = cardH * 2 + MOVE_CARD_GAP
  local gridY = deckY + math.max(0, math.floor((deckH - gridH) / 2))
  return gridY, gridH, cardH
end

-- External modder hook registries
BattleRenderer.customActions = {}
BattleRenderer.customBadges = {}
BattleRenderer.moveDetailProviders = {}

function BattleRenderer.registerAction(actionDef)
  if actionDef and actionDef.id then
    BattleRenderer.customActions[#BattleRenderer.customActions + 1] = actionDef
  end
end

function BattleRenderer.registerBadge(badgeDef)
  if badgeDef and badgeDef.render then
    BattleRenderer.customBadges[#BattleRenderer.customBadges + 1] = badgeDef
  end
end

function BattleRenderer.registerMoveDetailProvider(providerFn)
  if providerFn and type(providerFn) == "function" then
    BattleRenderer.moveDetailProviders[#BattleRenderer.moveDetailProviders + 1] = providerFn
  end
end

-- Gen 3 draws its own background, stage, and sprites. The HUD still overlays.
function BattleRenderer.usesThemedStage(game)
  local adapter = AdapterResolver.resolve(game)
  if adapter and adapter.generation == 3 then return false end
  return true
end

-- The GBA battle textbox is the bottom 48 rows of the 160-tall screen. The
-- terrain art under it is empty, so the console has to cover that rectangle
-- or the intro and the command menu leave a black bar. Gen 1/2 keep the
-- floating deck over the themed stage.
function BattleRenderer.consoleBand(game, viewport, vw, vh)
  if BattleRenderer.usesThemedStage(game) then return nil end
  vw = tonumber(vw) or 800
  vh = tonumber(vh) or 600
  local gx = (type(viewport) == "table" and tonumber(viewport.gameX)) or 0
  local gy = (type(viewport) == "table" and tonumber(viewport.gameY)) or 0
  local gw = (type(viewport) == "table" and tonumber(viewport.gameWidth)) or vw
  local gh = (type(viewport) == "table" and tonumber(viewport.gameHeight)) or vh
  local y = gy + math.floor(gh * 112 / 160)
  return {
    x = gx,
    y = y,
    w = gw,
    h = math.max(1, (gy + gh) - y),
  }
end

-- A battle-frame message belongs in the console, not the field dialogue box.
function BattleRenderer.battleMessageText()
  local ok, Message = pcall(require, "src.ui.game3.message")
  if not ok or type(Message) ~= "table" then return nil, false end
  if not (Message.isOpen and Message.isOpen()) then return nil, false end
  if not (Message.frameKind and Message.frameKind() == "battle") then return nil, false end
  local raw = (Message.currentPage and Message.currentPage()) or ""
  local waiting = Message.isWaiting and Message.isWaiting() or false
  raw = tostring(raw)
  local revealed = tonumber(Message._revealed)
  if not waiting and revealed and revealed >= 0 and revealed < #raw then
    raw = raw:sub(1, revealed)
  end
  return Layout.cleanText(raw), waiting
end

-- Composites Themed Arena Field & Battle Scene on render.compose
function BattleRenderer.composeBattleScene(renderer, ctx, theme, game)
  if not ctx or not ctx.uiCanvas then return false end
  local ww, wh = ctx.ww, ctx.wh
  local ox, oy = ctx.ox, ctx.oy
  local sx, sy = ctx.Sx, ctx.Sy
  local dpiX, dpiY = ctx.dpiX or 1, ctx.dpiY or 1

  local initDepth = love and love.graphics and love.graphics.getStackDepth and love.graphics.getStackDepth() or 0
  love.graphics.push("all")

  -- 1. Dark Themed Arena Surround Background
  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3], 1.0)
  love.graphics.rectangle("fill", 0, 0, ww, wh)

  -- Theme atmospheric background layer (holographic grids, scanlines, particle fields)
  if theme.drawBackground and type(theme.drawBackground) == "function" then
    pcall(theme.drawBackground, theme, ww, wh, "battle", 1.0)
  end

  -- 2. Modern 3D Battle Pedestals / Stages (only shown once Pokémon are active on the field, not during trainer intros)
  local adapter = AdapterResolver.resolve(game or (renderer and renderer.game))
  local battleInfo = adapter and adapter:updateBattleInfo()

  local drawFoePlatform = not battleInfo or (battleInfo.showEnemyTrainer ~= true and battleInfo.enemyMonOut ~= false)
  local drawPlayerPlatform = not battleInfo or (battleInfo.showPlayerBack ~= true and battleInfo.playerMonOut ~= false)

  local surfColor = theme.colors.surface or { 0.19, 0.20, 0.27 }
  local rimColor = theme.colors.raised or theme.colors.surfaceHigh or { 0.25, 0.27, 0.35 }
  local crustColor = theme.colors.crust or theme.colors.surfaceHigh or theme.bg or { 0.11, 0.11, 0.16 }
  local edgeColor = theme.colors.border or { 0.35, 0.40, 0.50 }

  -- Unified 3D isometric perspective viewing tilt ratio (shared across both stages)
  local platformTilt = 0.31

  -- Opponent Stage (Upper Right, under foe sprite)
  if drawFoePlatform and love.graphics.ellipse then
    local foePlatX = ox + math.floor(124 * sx)
    local foePlatY = oy + math.floor(58 * sy)
    local foeRx = math.floor(38 * sx)
    local foeRy = math.floor(foeRx * platformTilt)
    local foeDepth = math.max(3, math.floor(5 * sy))

    -- Ground shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", foePlatX, foePlatY + foeDepth + 3 * sy, foeRx + 3 * sx, foeRy + 2 * sy)

    -- Cylinder body (3D rim)
    love.graphics.setColor(crustColor[1], crustColor[2], crustColor[3], 0.95)
    love.graphics.ellipse("fill", foePlatX, foePlatY + foeDepth, foeRx, foeRy)
    love.graphics.rectangle("fill", foePlatX - foeRx, foePlatY, foeRx * 2, foeDepth)

    -- Top platform disk & inner highlight
    love.graphics.setColor(surfColor[1], surfColor[2], surfColor[3], 0.95)
    love.graphics.ellipse("fill", foePlatX, foePlatY, foeRx, foeRy)
    love.graphics.setColor(rimColor[1], rimColor[2], rimColor[3], 0.65)
    love.graphics.ellipse("fill", foePlatX, foePlatY, foeRx * 0.75, foeRy * 0.75)
    love.graphics.setColor(edgeColor[1], edgeColor[2], edgeColor[3], 0.60)
    love.graphics.setLineWidth(1.5)
    love.graphics.ellipse("line", foePlatX, foePlatY, foeRx, foeRy)
  end

  -- Player Stage (Foreground Lower Left, positioned under player Pokémon's feet/baseline)
  if drawPlayerPlatform and love.graphics.ellipse then
    local playerPlatX = ox + math.floor(40 * sx)
    local playerPlatY = oy + math.floor(110 * sy)
    local playerRx = math.floor(52 * sx)
    local playerRy = math.floor(playerRx * platformTilt)
    local playerDepth = math.max(3, math.floor(5 * sy))

    -- Ground shadow
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", playerPlatX, playerPlatY + playerDepth + 3 * sy, playerRx + 3 * sx, playerRy + 2 * sy)

    -- Cylinder body (3D rim)
    love.graphics.setColor(crustColor[1], crustColor[2], crustColor[3], 0.95)
    love.graphics.ellipse("fill", playerPlatX, playerPlatY + playerDepth, playerRx, playerRy)
    love.graphics.rectangle("fill", playerPlatX - playerRx, playerPlatY, playerRx * 2, playerDepth)

    -- Top platform disk & inner highlight
    love.graphics.setColor(surfColor[1], surfColor[2], surfColor[3], 0.95)
    love.graphics.ellipse("fill", playerPlatX, playerPlatY, playerRx, playerRy)
    love.graphics.setColor(rimColor[1], rimColor[2], rimColor[3], 0.65)
    love.graphics.ellipse("fill", playerPlatX, playerPlatY, playerRx * 0.75, playerRy * 0.75)
    love.graphics.setColor(edgeColor[1], edgeColor[2], edgeColor[3], 0.60)
    love.graphics.setLineWidth(1.5)
    love.graphics.ellipse("line", playerPlatX, playerPlatY, playerRx, playerRy)
  end

  -- 3. Blit Pokémon battle scene with solid authentic pixels (no transparent holes in sprite highlights)
  love.graphics.setColor(1, 1, 1, 1)
  if ctx.generation == 2 or ctx.sceneCanvas or not renderer.blitCanvas then
    love.graphics.draw(ctx.uiCanvas, 0, 0)
  elseif renderer.blitCanvas then
    renderer:blitCanvas(ctx.uiCanvas, sx, sy, ctx.zones, sx, sy, ox, oy,
                        ctx.viewX or 0, ctx.viewY or 0, ctx.viewWidth or ww, ctx.viewHeight or wh, dpiX, dpiY)
  else
    love.graphics.draw(ctx.uiCanvas, ox, oy, 0, sx, sy)
  end

  love.graphics.pop()
  if love and love.graphics and love.graphics.getStackDepth then
    while love.graphics.getStackDepth() > initDepth do
      love.graphics.pop()
    end
  end
  return true
end

-- Renders Opponent Battler HUD Card (Single or Double)
function BattleRenderer.drawOpponentHud(game, enemy, x, y, w, h, theme)
  if not enemy or not enemy.active then return end
  h = h or 62

  -- 1. Main Floating HUD Card
  Layout.drawCard(x, y, w, h, {
    color = theme.colors.surface,
    borderColor = theme.colors.border,
    borderWidth = 1,
    radius = theme.metrics and theme.metrics.radius.card or 12,
  })

  -- 2. Battler Header: Name + Level + Gender + Caught Icon + Status
  local nameStr = tostring(enemy.name or enemy.species or "FOE"):upper()
  local levelStr = ("Lv.%d"):format(enemy.level or 1)
  Layout.drawText(nameStr, x + 14, y + 8, { font = "headline", color = theme.colors.heading, bold = true })
  local nw = Layout.textWidth(nameStr, "headline")

  Layout.drawText(levelStr, x + 18 + nw, y + 10, { font = "tiny", color = theme.colors.textDim, bold = true })
  local lw = Layout.textWidth(levelStr, "tiny")

  if enemy.gender then
    local male = isMaleGender(enemy.gender)
    local gColor = male and (theme.colors.sapphire or theme.colors.expBlue) or (theme.colors.pink or theme.colors.hpRed)
    local gSym = male and "♂" or "♀"
    Layout.drawText(gSym, x + 22 + nw + lw, y + 9, { font = "tiny", color = gColor, bold = true })
  end

  -- Caught ball icon / status badge on top right
  local rightX = x + w - 14
  if enemy.status and enemy.status ~= "" then
    local statLabel = tostring(enemy.status):upper()
    local bw = Layout.textWidth(statLabel, "tiny") + 16
    Layout.drawBadge(rightX - bw, y + 7, statLabel, { kind = "danger", font = "tiny", height = 18, width = bw })
    rightX = rightX - bw - 6
  end

  if enemy.isCaught then
    local bw = Layout.textWidth("CAUGHT", "tiny") + 16
    Layout.drawBadge(rightX - bw, y + 7, "CAUGHT", { kind = "team", font = "tiny", height = 18, width = bw })
    rightX = rightX - bw - 6
  end

  -- 3. Health Bar Meter
  local barY = y + 30
  local barW = w - 28
  local curHp = enemy.shownHp or enemy.hp or 0
  local maxHp = math.max(1, enemy.maxHp or 1)
  Layout.drawHealthBar(x + 14, barY, barW, 7, curHp, maxHp, {
    radius = 3,
  })

  -- 4. HP Percentage
  local pctStr = ("%d%%"):format(math.floor(math.max(0, math.min(1, curHp / maxHp)) * 100))
  Layout.drawText(pctStr, x + 14, barY + 11, { font = "tiny", color = theme.colors.textDim, bold = true })

  -- 5. Sandboxed Modder Custom Badges
  for idx, badgeDef in ipairs(BattleRenderer.customBadges) do
    if badgeDef.side == "enemy" or badgeDef.side == "both" or not badgeDef.side then
      HookBoundary.safeRender("badge_enemy_" .. idx, badgeDef.render, enemy, x, y, theme)
    end
  end
end

-- Renders Player Battler HUD Card
function BattleRenderer.drawPlayerHud(game, player, x, y, w, h, theme)
  if not player or not player.active then return end
  h = h or 78

  -- 1. Main Floating HUD Card
  Layout.drawCard(x, y, w, h, {
    color = theme.colors.surface,
    borderColor = theme.colors.border,
    borderWidth = 1,
    radius = theme.metrics and theme.metrics.radius.card or 12,
  })

  -- 2. Battler Header: Name + Level + Gender + Held Item
  local nameStr = tostring(player.name or player.species or "POKÉMON"):upper()
  local levelStr = ("Lv.%d"):format(player.level or 1)
  Layout.drawText(nameStr, x + 14, y + 8, { font = "headline", color = theme.colors.heading, bold = true })
  local nw = Layout.textWidth(nameStr, "headline")

  Layout.drawText(levelStr, x + 18 + nw, y + 10, { font = "tiny", color = theme.colors.textDim, bold = true })
  local lw = Layout.textWidth(levelStr, "tiny")

  if player.gender then
    local male = isMaleGender(player.gender)
    local gColor = male and (theme.colors.sapphire or theme.colors.expBlue) or (theme.colors.pink or theme.colors.hpRed)
    local gSym = male and "♂" or "♀"
    Layout.drawText(gSym, x + 22 + nw + lw, y + 9, { font = "tiny", color = gColor, bold = true })
  end

  -- Status & Held item badges on top right (anchored from right edge inward)
  local rightX = x + w - 14
  if player.status and player.status ~= "" then
    local statLabel = tostring(player.status):upper()
    local bw = Layout.textWidth(statLabel, "tiny") + 16
    Layout.drawBadge(rightX - bw, y + 7, statLabel, { kind = "danger", font = "tiny", height = 18, width = bw })
    rightX = rightX - bw - 6
  end

  if player.heldItem then
    local itemLabel = tostring(player.heldItem):gsub("_", " "):upper()
    local bw = Layout.textWidth(itemLabel, "tiny") + 16
    local maxItemW = math.max(32, rightX - (x + 28 + nw + lw))
    if bw > maxItemW then
      bw = maxItemW
    end
    Layout.drawBadge(rightX - bw, y + 7, itemLabel, { kind = "bag", font = "tiny", height = 18, width = bw })
    rightX = rightX - bw - 6
  end

  -- 3. Health Bar Meter
  local barY = y + 28
  local barW = w - 28
  local curHp = player.shownHp or player.hp or 0
  local maxHp = math.max(1, player.maxHp or 1)
  Layout.drawHealthBar(x + 14, barY, barW, 7, curHp, maxHp, {
    radius = 3,
  })

  -- 4. HP Numbers ("HP 78 / 78")
  local hpStr = ("HP  %d / %d"):format(curHp, maxHp)
  Layout.drawText(hpStr, x + 14, barY + 11, { font = "tiny", color = theme.colors.heading, bold = true })

  -- EXP Progress Bar
  local expY = barY + 25
  local expRatio = player.expRatio or 0.5
  Layout.drawProgressBar(x + 14, expY, barW, 3, math.floor(expRatio * 100), 100, {
    color = theme.colors.sapphire or theme.colors.expBlue or theme.colors.accent,
    radius = 2,
  })

  -- 5. Party Ball indicators
  local ballY = y + h - 14
  local ballX = x + 14
  for i = 1, 6 do
    local bStat = player.partyBalls and player.partyBalls[i] or "empty"
    local bColor = theme.colors.surfaceHigh
    local bBorder = theme.colors.border
    if bStat == "ok" then
      bColor = theme.colors.hpGreen
      bBorder = theme.colors.hpGreen
    elseif bStat == "status" then
      bColor = theme.colors.hpYellow
      bBorder = theme.colors.hpYellow
    elseif bStat == "fainted" then
      bColor = theme.colors.hpRed
      bBorder = theme.colors.hpRed
    end

    love.graphics.setColor(bColor[1], bColor[2], bColor[3], 0.95)
    love.graphics.rectangle("fill", ballX + (i - 1) * 12, ballY, 6, 6, 2, 2)
    love.graphics.setColor(bBorder[1], bBorder[2], bBorder[3], 0.5)
    love.graphics.rectangle("line", ballX + (i - 1) * 12, ballY, 6, 6, 2, 2)
  end

  -- 6. Sandboxed Modder Custom Badges
  for idx, badgeDef in ipairs(BattleRenderer.customBadges) do
    if badgeDef.side == "player" or badgeDef.side == "both" or not badgeDef.side then
      HookBoundary.safeRender("badge_player_" .. idx, badgeDef.render, player, x, y, theme)
    end
  end
end

-- Renders Matrix 1: Action Command Deck (D-Pad Navigable 2x2 Menu)
function BattleRenderer.drawActionDeck(deckX, deckY, deckW, deckH, battleInfo, theme, opts)
  local actions = battleInfo.actions or {
    { id = "FIGHT", label = "FIGHT" },
    { id = "POKEMON", label = "POKÉMON" },
    { id = "BAG", label = "BAG" },
    { id = "RUN", label = "RUN" },
  }

  local selIdx = battleInfo.selectedAction or 1
  local btnW = math.floor((deckW - 10) / 2)
  local btnH = math.floor((deckH - 10) / 2)

  for i, act in ipairs(actions) do
    if i <= 4 then
      local col = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      local bx = deckX + col * (btnW + 10)
      local by = deckY + row * (btnH + 10)
      local isSel = (i == selIdx)

      local labelText = isSel and ("▶ " .. act.label) or ("  " .. act.label)
      local tile = opts and opts.tileColor

      if isSel then
        -- Focused Action Button: Mauve fill with Crust bold text
        Layout.drawButton(bx, by, btnW, btnH, labelText, {
          kind = "primary",
          selected = true,
          font = "button",
          align = "center",
        })
      else
        -- Unfocused Action Button: Clean Surface0 tile
        Layout.drawButton(bx, by, btnW, btnH, labelText, {
          kind = "ghost",
          selected = false,
          font = "button",
          align = "center",
          color = tile,
        })
      end
    end
  end
end

-- Renders Matrix 2: Move Selection Matrix (D-Pad Navigable 2x2 Move Grid with PP)
function BattleRenderer.drawMoveMatrix(deckX, deckY, deckW, deckH, battleInfo, theme)
  local moves = battleInfo.moves or {}
  local selIdx = battleInfo.selectedMove or 1
  local gap = MOVE_CARD_GAP
  local cardW = math.floor((deckW - gap) / 2)
  local gridY, _, cardH = moveGridFrame(deckY, deckH)
  local tall = cardH >= 78

  for i = 1, 4 do
    local mv = moves[i]
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local cx = deckX + col * (cardW + gap)
    local cy = gridY + row * (cardH + gap)
    local isSel = (i == selIdx)

    local cardColor = isSel and theme.colors.raised or theme.colors.surface
    local borderColor = isSel and (theme.colors.borderStrong or theme.colors.accent) or theme.colors.border

    Layout.drawCard(cx, cy, cardW, cardH, {
      color = cardColor,
      borderColor = borderColor,
      borderWidth = isSel and 2 or 1,
      radius = theme.metrics and theme.metrics.radius.card or 8,
    })

    if mv and mv.id and mv.id ~= "" then
      local tName = tostring(mv.type or "NORMAL"):upper()
      local nameColor = isSel and theme.colors.heading or theme.colors.text
      local prefix = isSel and "▶ " or ""
      local fullName = prefix .. tostring(mv.name or mv.id):upper()

      local maxNameW = cardW - 20
      local moveFont = tall and "headline" or "button"
      if Layout.textWidth(fullName, moveFont) > maxNameW then
        moveFont = "button"
        if Layout.textWidth(fullName, "button") > maxNameW then
          moveFont = "caption"
        end
      end
      local nameY = cy + 8
      Layout.drawText(fullName, cx + 10, nameY, {
        font = moveFont,
        color = nameColor,
        bold = true,
        width = maxNameW,
      })

      local ppStr = ("PP %d/%d"):format(mv.pp or 0, mv.maxPP or 0)
      local ppColor = (mv.pp and mv.pp <= 0) and theme.colors.hpRed or theme.colors.text
      local pwrStr = MoveDatabase.getPowerString(mv)
      local statFont = tall and "caption" or "tiny"
      local badgeFont = tall and "caption" or "tiny"
      local badgeH = tall and 18 or 16
      local badgeW = Layout.textWidth(tName, badgeFont) + 14
      local ppH = Layout.textHeight(statFont)
      local ppY = cy + cardH - ppH - 8
      local metaY = nameY + Layout.textHeight(moveFont) + 6

      if metaY + badgeH + 4 < ppY then
        Widgets.drawTypeBadge(tName, cx + 10, metaY, {
          width = badgeW,
          height = badgeH,
          font = badgeFont,
        })
        Layout.drawText("PWR " .. pwrStr, cx + 18 + badgeW, metaY + 1, {
          font = statFont,
          color = theme.colors.textDim,
          bold = true,
        })
      else
        Widgets.drawTypeBadge(tName, cx + cardW - badgeW - 8, ppY, {
          width = badgeW,
          height = badgeH,
          font = badgeFont,
        })
      end

      Layout.drawText(ppStr, cx + 10, ppY, { font = statFont, color = ppColor, bold = true })
    else
      Layout.drawText("--", cx + math.floor(cardW / 2) - 8, cy + math.floor(cardH / 2) - 8, {
        font = tall and "headline" or "body",
        color = theme.colors.textMuted,
      })
    end
  end
end

-- Renders Matrix 3: Double Battle Target Selection Matrix
function BattleRenderer.drawTargetMatrix(deckX, deckY, deckW, deckH, battleInfo, theme)
  local targets = battleInfo.validTargets or {
    { index = 1, label = "FOE 1", valid = true, isSpread = false },
    { index = 2, label = "FOE 2", valid = true, isSpread = false },
    { index = 3, label = "ALLY", valid = true, isSpread = false },
    { index = 4, label = "SELF", valid = false, isSpread = false },
  }

  local selIdx = battleInfo.selectedTarget or 1
  local cardW = math.floor((deckW - 10) / 2)
  local cardH = math.floor((deckH - 10) / 2)

  for i, tgt in ipairs(targets) do
    if i <= 4 then
      local col = (i - 1) % 2
      local row = math.floor((i - 1) / 2)
      local cx = deckX + col * (cardW + 10)
      local cy = deckY + row * (cardH + 10)
      local isSel = (i == selIdx)

      local labelText = isSel and ("▶ " .. tgt.label) or tgt.label
      local btnKind = tgt.valid and (isSel and "primary" or "ghost") or "danger"
      Layout.drawButton(cx, cy, cardW, cardH, labelText, {
        kind = btnKind,
        selected = isSel,
        font = "button",
      })

      if tgt.isSpread then
        Layout.drawBadge(cx + cardW - 54, cy + 4, "SPREAD", { kind = "warn", font = "tiny", height = 18 })
      end
    end
  end
end

-- Main Draw Orchestrator for Battle UI
function BattleRenderer.draw(game, state, vw, vh, theme, subState, viewport)
  local adapter = AdapterResolver.resolve(game)
  local battleInfo = adapter:updateBattleInfo()
  if not battleInfo or not battleInfo.isActive then return end

  local ctx = Layout.getContext(vw, vh, viewport)

  local gx = (viewport and viewport.gameX) or 0
  local gy = (viewport and viewport.gameY) or 0
  local gw = (viewport and viewport.gameWidth) or vw
  local gh = (viewport and viewport.gameHeight) or vh

  local hudW = math.min(260, math.max(160, math.floor(vw * 0.44)))
  local hudH = ctx.isUltraCompact and 52 or 62
  local playerHudH = ctx.isUltraCompact and 64 or 76
  local deckMargin = ctx.isCompact and 8 or 16

  local nativeBand = BattleRenderer.consoleBand(game, viewport, vw, vh)
  local deckX, deckY, totalDeckW, deckH
  if nativeBand then
    -- Sit in the textbox slot: flush with the field cut, full game width,
    -- down to the bottom of the battle view.
    deckX = nativeBand.x
    deckY = nativeBand.y
    totalDeckW = nativeBand.w
    deckH = nativeBand.h
  else
    -- Total Deck Width clamped to game bounds or comfortable modern width
    totalDeckW = math.min(vw - 2 * deckMargin, math.max(gw, ctx.isPortrait and (vw - 2 * deckMargin) or 680))
    deckX = math.floor((vw - totalDeckW) / 2)

    -- Dock command deck to the player's Pokémon back-sprite baseline (y=96 in 144px canvas space)
    local baselineY = gy + math.floor(gh * (96 / 144))
    deckY = math.min(baselineY - 4, vh - 110)
    deckH = math.max(104, math.min(130, vh - deckY - 14))
  end

  -- 1. Opponent Battler HUD (Top-Left, framed cleanly against the arena)
  local oppX = math.max(deckMargin, math.min(gx + 12, vw - hudW - deckMargin))
  local oppY = math.max(deckMargin, gy + 10)
  BattleRenderer.drawOpponentHud(game, battleInfo.enemy, oppX, oppY, hudW, hudH, theme)

  -- If double battle, draw 2nd opponent HUD beside it
  if battleInfo.isDouble and battleInfo.enemy2 and battleInfo.enemy2.active then
    BattleRenderer.drawOpponentHud(game, battleInfo.enemy2, oppX + hudW + 12, oppY, hudW, hudH, theme)
  end

  -- 2. Player Battler HUD (Bottom-Right, floating cleanly above the docked command deck)
  local playerHudX = math.max(deckMargin, math.min(gx + gw - hudW - 8, vw - hudW - deckMargin))
  local playerHudY = math.max(oppY + hudH + 8, deckY - playerHudH - 8)
  BattleRenderer.drawPlayerHud(game, battleInfo.player, playerHudX, playerHudY, hudW, playerHudH, theme)

  -- 3. Bottom Interactive Console Deck
  local liveText, liveWaiting = BattleRenderer.battleMessageText()
  local showDialog = liveText ~= nil or battleInfo.phase == "messages" or (not battleInfo.phase)
  local panelColor = theme.colors.surface
  local trayColor = theme.colors.bg or theme.bg or { 0.08, 0.09, 0.11 }
  local tileColor = theme.colors.raised or theme.colors.surfaceHigh
  local cardRadius = theme.metrics and theme.metrics.radius.card or 12
  if showDialog then
    local waiting = liveWaiting or battleInfo.waitingForA
    local liveLine = (liveText ~= nil) and liveText or nil
    local cachedLine = (type(battleInfo.message) == "string" and battleInfo.message ~= "") and battleInfo.message or nil
    if nativeBand then
      -- Stay blank until the battle line exists. The command prompt belongs
      -- on the action screen, not in the box before the intro starts.
      local msgText = liveLine or cachedLine or ""
      -- Darker tray, then one fixed lighter card with the same outline as the
      -- command prompt. The line typewrites into that card; its size stays put.
      local pad = 10
      Layout.drawCard(deckX, deckY, totalDeckW, deckH, {
        color = trayColor,
        borderColor = trayColor,
        radius = 0,
      })
      local cardX = deckX + pad
      local cardY = deckY + pad
      local cardW = totalDeckW - pad * 2
      local cardH = deckH - pad * 2
      Layout.drawCard(cardX, cardY, cardW, cardH, {
        color = panelColor,
        borderColor = theme.colors.border,
        borderWidth = 1,
        radius = cardRadius,
      })
      if msgText ~= "" then
        Layout.drawTextWrapped(msgText, cardX + 18, cardY + 16, math.max(80, cardW - 36), {
          font = "title",
          color = theme.colors.heading,
        })
      end
      if waiting then
        Layout.drawButtonHint(cardX + cardW - 124, cardY + cardH - 34, "A", "Close", { primary = true })
      end
    else
      -- Same rule as the Gen 3 console: a dialog with no line yet stays blank.
      -- "What will X do?" belongs on the action menu, not in this box.
      local msgText = liveLine or cachedLine or ""
      Layout.drawCard(deckX, deckY, totalDeckW, deckH, {
        color = panelColor,
        borderColor = theme.colors.border,
        borderWidth = 1,
        radius = cardRadius,
      })
      if msgText ~= "" then
        Layout.drawTextWrapped(msgText, deckX + 18, deckY + 16, totalDeckW - 50, {
          font = "headline",
          color = theme.colors.heading,
          lineHeight = 1.4,
        })
      end
      if waiting then
        Layout.drawButtonHint(deckX + totalDeckW - 120, deckY + deckH - 36, "A", "Close", { primary = true })
      end
    end
  else
    -- The tray is darker than the prompt and the buttons, so the gap and the
    -- outer edge read as a frame instead of more of the same fill.
    if nativeBand then
      Layout.drawCard(deckX, deckY, totalDeckW, deckH, {
        color = trayColor,
        borderColor = trayColor,
        radius = 0,
      })
    end
    local pad = nativeBand and 10 or 0
    local gap = nativeBand and 14 or 12
    local cx = deckX + pad
    local cy = deckY + pad
    local cw = totalDeckW - pad * 2
    local ch = deckH - pad * 2
    if ctx.isPortrait and totalDeckW < 520 then
      -- Portrait Reflowed Stacked Console Deck
      local isMoveSel = (battleInfo.phase == "move_select")
      local infoH = isMoveSel and (nativeBand and 64 or 38) or 32
      local matrixY = cy + infoH + gap
      local matrixH = ch - infoH - gap

      -- Top Prompt / Move Info Card
      Layout.drawCard(cx, cy, cw, infoH, {
        color = panelColor,
        borderColor = theme.colors.border,
        borderWidth = 1,
        radius = 8,
      })

      if isMoveSel then
        local curMove = battleInfo.moves and battleInfo.moves[battleInfo.selectedMove or 1]
        if curMove and curMove.id and curMove.id ~= "" then
          local curMdef = MoveDatabase.getMoveDef(curMove.id, curMove, game)
          local moveName = tostring(curMove.name or (curMdef and curMdef.name) or curMove.id):upper()
          Layout.drawText(moveName, cx + 12, cy + 8, {
            font = "button",
            color = theme.colors.heading,
            bold = true,
            width = math.floor(cw * 0.46),
          })
          local pwrStr = MoveDatabase.getPowerString(curMdef)
          local accStr = MoveDatabase.getAccuracyString(curMdef)
          local statText = "PWR " .. pwrStr .. "  ACC " .. accStr
          local statW = Layout.textWidth(statText, "caption")
          Layout.drawText(statText, cx + cw - statW - 12, cy + 10, {
            font = "caption",
            color = theme.colors.textDim,
            bold = true,
          })
          if infoH >= 56 then
            local descText = MoveDatabase.getDescription(curMove.id, curMdef, game)
            Layout.drawText(descText, cx + 12, cy + 34, {
              font = "caption",
              color = theme.colors.text,
              width = cw - 24,
            })
          end
        else
          Layout.drawText("SELECT A MOVE", cx + 12, cy + 9, { font = "caption", color = theme.colors.heading, bold = true })
        end
      else
        local msgText = battleInfo.message ~= "" and battleInfo.message or ("What will %s do?"):format(battleInfo.player.name or "POKÉMON")
        Layout.drawText(msgText, cx + 12, cy + 8, {
          font = "caption",
          color = theme.colors.heading,
          bold = true,
          width = cw - 24,
        })
      end

      -- Full-Width Matrix
      if isMoveSel then
        BattleRenderer.drawMoveMatrix(cx, matrixY, cw, matrixH, battleInfo, theme)
      elseif battleInfo.phase == "target_select" then
        BattleRenderer.drawTargetMatrix(cx, matrixY, cw, matrixH, battleInfo, theme)
      else
        BattleRenderer.drawActionDeck(cx, matrixY, cw, matrixH, battleInfo, theme, {
          tileColor = nativeBand and tileColor or nil,
        })
      end
    else
      -- Command Selection Mode: Left Box (Prompt/Move Details) + Right Box (2x2 Grid)
      local msgDeckW = math.floor(cw * 0.48)
      local consoleDeckW = cw - msgDeckW - gap
      local consoleDeckX = cx + msgDeckW + gap

      if battleInfo.phase == "move_select" then
        local curMove = battleInfo.moves and battleInfo.moves[battleInfo.selectedMove or 1]
        local infoY, infoH = cy, ch
        local moveName, curMdef, descText, showTag, pwrStr, accStr, moveType, category
        if curMove and curMove.id and curMove.id ~= "" then
          curMdef = MoveDatabase.getMoveDef(curMove.id, curMove, game)
          moveName = tostring(curMove.name or (curMdef and curMdef.name) or curMove.id):upper()
          moveType = (curMdef and curMdef.type) or curMove.type or "NORMAL"
          category = MoveDatabase.getCategory(curMove.id, curMdef, game)
          pwrStr = MoveDatabase.getPowerString(curMdef)
          accStr = MoveDatabase.getAccuracyString(curMdef)
          descText = MoveDatabase.getDescription(curMove.id, curMdef, game)
          local effTag = MoveDatabase.getEffectTag(curMove.id, curMdef, game)
          if effTag and effTag ~= "" and effTag ~= "None" and effTag ~= "Standard Damage" then
            showTag = effTag
          end
          local descFont = "body"
          local wrapW = msgDeckW - 36
          local lines = wrappedLineCount(descText, descFont, wrapW)
          local descBlock = lines * math.floor(Layout.textHeight(descFont) * 1.3)
          local header = 18 + Layout.textHeight("title") + 34 + (showTag and 28 or 0) + 28
          local need = header + descBlock + 16
          infoH = math.min(ch, math.max(need, 128))
          infoY = cy + math.floor((ch - infoH) / 2)
        else
          infoH = math.min(ch, 96)
          infoY = cy + math.floor((ch - infoH) / 2)
        end

        Layout.drawCard(cx, infoY, msgDeckW, infoH, {
          color = panelColor,
          borderColor = theme.colors.border,
          borderWidth = 1,
          radius = cardRadius,
        })

        if moveName then
          local y = infoY + 14
          Layout.drawText(moveName, cx + 16, y, {
            font = "title",
            color = theme.colors.heading,
            bold = true,
            width = msgDeckW - 32,
          })
          y = y + Layout.textHeight("title") + 8

          local bw = Widgets.drawTypeBadge(moveType, cx + 16, y, {
            height = 20,
            font = "caption",
          })
          local catKind = (category == "PHYSICAL" and "warn") or (category == "SPECIAL" and "accent") or "ghost"
          Layout.drawBadge(cx + 24 + bw, y, category, {
            kind = catKind,
            font = "caption",
            height = 20,
          })
          y = y + 28
          Layout.drawText("PWR " .. pwrStr .. "    ACC " .. accStr, cx + 16, y, {
            font = "caption",
            color = theme.colors.textDim,
            bold = true,
          })
          y = y + 24
          if showTag then
            Layout.drawBadge(cx + 16, y, showTag, {
              kind = "good",
              font = "caption",
              height = 20,
            })
            y = y + 28
          end
          if descText and descText ~= "" then
            Layout.drawTextWrapped(descText, cx + 16, y, msgDeckW - 32, {
              font = "body",
              color = theme.colors.text,
            })
          end
          for idx, providerFn in ipairs(BattleRenderer.moveDetailProviders) do
            HookBoundary.safeRender("move_detail_" .. idx, providerFn, curMove, curMdef, cx, infoY, msgDeckW, infoH, theme)
          end
        else
          Layout.drawText("SELECT A MOVE", cx + 16, infoY + 16, { font = "title", color = theme.colors.heading, bold = true })
        end
      else
        Layout.drawCard(cx, cy, msgDeckW, ch, {
          color = panelColor,
          borderColor = theme.colors.border,
          borderWidth = 1,
          radius = cardRadius,
        })
        local msgText = battleInfo.message ~= "" and battleInfo.message or ("What will %s do?"):format(battleInfo.player.name or "POKÉMON")
        local promptFont = nativeBand and "title" or "headline"
        local wrapW = msgDeckW - 36
        local lines = wrappedLineCount(msgText, promptFont, wrapW)
        local block = lines * math.floor(Layout.textHeight(promptFont) * 1.3)
        local textY = cy + math.max(16, math.floor((ch - block) / 2))
        Layout.drawTextWrapped(msgText, cx + 18, textY, wrapW, {
          font = promptFont,
          color = theme.colors.heading,
        })
      end

      -- Right Console Deck (Matrix 1: Actions, Matrix 2: Moves, Matrix 3: Targets)
      if battleInfo.phase == "move_select" then
        BattleRenderer.drawMoveMatrix(consoleDeckX, cy, consoleDeckW, ch, battleInfo, theme)
      elseif battleInfo.phase == "target_select" then
        BattleRenderer.drawTargetMatrix(consoleDeckX, cy, consoleDeckW, ch, battleInfo, theme)
      else
        BattleRenderer.drawActionDeck(consoleDeckX, cy, consoleDeckW, ch, battleInfo, theme, {
          tileColor = nativeBand and tileColor or nil,
        })
      end
    end
  end

  -- 4. Level-Up Stat Box Popup Overlay
  local isStatsBox = (battleInfo.phase == "stats_box" or battleInfo.phase == "stats-box")
    or (state and (state.phase == "stats-box" or state.phase == "stats_box") and state.statsBoxMon)
    or (subState and (subState.isStatBox or (subState.mon and subState.mon.stats and (subState.keepOpen ~= nil or subState.onDone))))
  if isStatsBox then
    local LevelUpStatRenderer = require("mods.omni_ui.renderers.LevelUpStatRenderer")
    local statMon = (state and (state.statsBoxMon or state.statsMon))
      or (subState and (subState.mon or subState.statsBoxMon))
      or battleInfo.statsBoxMon
      or (battleInfo.player and (battleInfo.player.mon or battleInfo.player))
    if statMon then
      LevelUpStatRenderer.draw(game, { mon = statMon }, vw, vh, theme, subState, viewport)
    end
  end
end

return BattleRenderer
