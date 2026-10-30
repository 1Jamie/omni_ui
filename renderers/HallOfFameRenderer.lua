-- OmniUI Hall of Fame & Champion Ceremony Renderer
-- High-res victory pedestal sequence preserving progressive reveal pacing, orientation adaptability, and audio sync.

local Layout = require("mods.omni_ui.core.Layout")
local BaseAdapter = require("mods.omni_ui.adapters.BaseAdapter")
local Widgets = require("mods.omni_ui.core.Widgets")
local PaletteFX = require("src.render.PaletteFX")
local SpriteHelper = require("mods.omni_ui.core.SpriteHelper")
local StatResolver = require("mods.omni_ui.core.StatResolver")

local HallOfFameRenderer = {}

local function speciesLabel(species, nickname, data)
  if type(nickname) == "string" and nickname ~= "" and not tostring(nickname):match("^%d+$") then
    return nickname
  end
  local num = tonumber(species)
  if num and num > 0 then
    local ok, Pokemon = pcall(require, "src.core.game3.pokemon")
    if ok and Pokemon and Pokemon.name then
      local okN, n = pcall(Pokemon.name, num)
      if okN and type(n) == "string" and n ~= "" and n ~= "?????" then return n end
    end
  end
  local def = data and data.pokemon and (data.pokemon[species] or (num and data.pokemon[num]))
  if def and def.name then return def.name end
  if type(species) == "string" and species ~= "" and not species:match("^%d+$") then return species end
  return "POKÉMON"
end

function HallOfFameRenderer.draw(game, state, w, h, theme, subState, progress)
  theme = theme or require("mods.omni_ui.core.Theme").get()
  local save = game and game.save or {}
  local data = game and game.data or {}
  local party = state._mons or state.party or save.party or {}
  local player = save.player or {}

  local phase = state._phase or state.phase or "mons"
  local index = state._currentIndex or state.index or 1
  local curMon = party[index]

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait
  local footY = h - 38

  -- 1. Outer Container
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
  Layout.drawText(isNarrow and "HALL OF FAME" or "POKÉMON LEAGUE • HALL OF FAME INDUCTION", 18, 12, { font = "headline", color = theme.heading, bold = true })
  
  local isPlayerPhase = state.isFinale or state._playerInfo == true
    or (phase == "player" or phase == "player_stats" or phase == "player_dex" or phase == "player_rating"
      or phase == "playerpic" or phase == "playerwait" or phase == "exitwait" or phase == "exit")
    or (not curMon)
  local stepBadge = isPlayerPhase and "CHAMPION" or ("%d / %d"):format(index, math.max(1, #party))
  Layout.drawBadge(w - (isNarrow and 100 or 220), 10, stepBadge, { kind = isPlayerPhase and "gold" or "team", font = "caption", height = 24 })

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE STACKED HERO STAGE + VICTORY PLAQUE
    -- =========================================================================
    if not isPlayerPhase and curMon then
      local species = curMon.species or curMon.speciesId or "UNKNOWN"
      local def = data.pokemon and data.pokemon[species]
      local name = speciesLabel(species, curMon.nickname, data)
      local level = curMon.level or 1
      local types = (def and def.types) or { "NORMAL" }

      -- Top Stage
      local stageH = 120
      Layout.drawCard(0, 48, w, stageH, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        radius = 8,
      })

      SpriteHelper.drawFrontPic(data, species, 16, 48, w - 32, stageH, { kind = "summary" })

      -- Pedestal Ring
      love.graphics.setColor(theme.borderStrong[1], theme.borderStrong[2], theme.borderStrong[3], 0.3)
      Layout.drawEllipse("line", w / 2, 48 + stageH - 12, math.min(100, math.floor(w * 0.3)), 12)

      -- Bottom Plaque Card
      local plaqueY = 48 + stageH + 6
      local plaqueH = footY - plaqueY - 6
      Layout.drawCard(0, plaqueY, w, plaqueH, {
        color = theme.surface,
        borderColor = theme.border,
        radius = 8,
      })

      Layout.drawText("HALL OF FAME INDUCTEE", 16, plaqueY + 8, { font = "tiny", color = theme.colors.accent, bold = true })
      Layout.drawText(name:upper(), 16, plaqueY + 22, { font = "headline", color = theme.heading, bold = true, width = w - 100 })
      Layout.drawBadge(w - 70, plaqueY + 22, ("LV %d"):format(level), { kind = "team", font = "tiny" })

      local uniqueTypes = Widgets.getUniqueTypes(types)
      local tx = 16
      for _, t in ipairs(uniqueTypes) do
        local bw = Widgets.drawTypeBadge(t, tx, plaqueY + 46)
        tx = tx + bw + 4
      end

      Layout.drawBadge(w - 120, plaqueY + 46, "★ CHAMPION ★", { kind = "gold", font = "tiny" })

      -- Stats List
      local st = StatResolver.getStats(curMon, def, game)
      local statRows
      if st.isSplit then
        statRows = {
          { label = "MAX HP", val = st.maxHp },
          { label = "ATTACK", val = st.attack },
          { label = "DEFENSE", val = st.defense },
          { label = "SP. ATK", val = st.spAttack },
          { label = "SP. DEF", val = st.spDefense },
          { label = "SPEED", val = st.speed },
        }
      else
        statRows = {
          { label = "MAX HP", val = st.maxHp },
          { label = "ATTACK", val = st.attack },
          { label = "DEFENSE", val = st.defense },
          { label = "SPEED", val = st.speed },
          { label = "SPECIAL", val = st.special },
        }
      end

      local sy = plaqueY + 74
      local rowH = math.max(22, math.floor((plaqueH - 84) / #statRows))
      for _, sr in ipairs(statRows) do
        Layout.drawSlot(12, sy, w - 24, rowH - 3, { color = theme.surfaceHigh, borderColor = theme.border, radius = 4 })
        Layout.drawText(sr.label, 20, sy + 3, { font = "tiny", color = theme.textDim })
        Layout.drawText(tostring(sr.val), w - 24, sy + 3, { font = "tiny", color = theme.heading, align = "right", bold = true })
        sy = sy + rowH
      end
    else
      -- Player Champion View
      local stageH = 130
      Layout.drawCard(0, 48, w, stageH, {
        color = theme.surfaceHigh,
        borderColor = theme.borderStrong,
        radius = 8,
      })

      local titlePlayer = data.field and data.field.title and data.field.title.player
      if type(titlePlayer) == "table" then titlePlayer = titlePlayer.path end
      local pImg = nil
      if titlePlayer then
        local ok, img = pcall(love.graphics.newImage, titlePlayer)
        if ok and img then pImg = img end
      end

      if pImg then
        local iw, ih = pImg:getDimensions()
        local scale = (stageH - 16) / math.max(iw, ih)
        local px = math.floor((w - iw * scale) / 2)
        local py = 48 + math.floor((stageH - ih * scale) / 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(pImg, px, py, 0, scale, scale)
      end

      local plaqueY = 48 + stageH + 6
      local plaqueH = footY - plaqueY - 6
      Layout.drawCard(0, plaqueY, w, plaqueH, {
        color = theme.surface,
        borderColor = theme.borderStrong,
        borderWidth = 1.5,
        radius = 8,
      })

      Layout.drawText("NEW LEAGUE CHAMPION", 16, plaqueY + 8, { font = "tiny", color = theme.hpYellow, bold = true })
      Layout.drawText(player.name or "RED", 16, plaqueY + 22, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(w - 90, plaqueY + 22, ("ID: %05d"):format(player.id or save.playerID or 0), { kind = "gold", font = "tiny" })

      local rawPT = save.playTime or save.time or 0
      local pHours, pMins = 0, 0
      if type(rawPT) == "number" then
        local ptSec = math.floor(rawPT)
        pHours = math.floor(ptSec / 3600)
        pMins = math.floor((ptSec % 3600) / 60)
      elseif type(rawPT) == "table" then
        pHours = tonumber(rawPT.hours or rawPT.h or rawPT[1]) or 0
        pMins = tonumber(rawPT.minutes or rawPT.m or rawPT[2]) or 0
      end
      local moneyStr = ("¥%d"):format(tonumber(player.money or save.money) or 0)

      local pRows = {
        { label = "PLAY TIME", val = ("%02d:%02d"):format(pHours, pMins) },
        { label = "PRIZE MONEY", val = moneyStr },
        { label = "LEAGUE BADGES", val = "8 / 8  (KANTO)" },
        { label = "POKÉDEX SEEN", val = tostring(BaseAdapter.countFlags(save.pokedex and save.pokedex.seen)) },
        { label = "POKÉDEX OWNED", val = tostring(math.max(
          BaseAdapter.countFlags(save.pokedex and save.pokedex.owned),
          BaseAdapter.countFlags(save.pokedex and save.pokedex.caught))) },
      }

      local py = plaqueY + 48
      local rowH = math.max(22, math.floor((plaqueH - 58) / #pRows))
      for _, row in ipairs(pRows) do
        Layout.drawSlot(12, py, w - 24, rowH - 3, { color = theme.surfaceHigh, borderColor = theme.border, radius = 4 })
        Layout.drawText(row.label, 20, py + 3, { font = "tiny", color = theme.textDim })
        Layout.drawText(row.val, w - 24, py + 3, { font = "tiny", color = theme.heading, align = "right", bold = true })
        py = py + rowH
      end
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANE LAYOUT
    -- =========================================================================
    local bodyH = h - 90
    local leftW = math.floor(w * 0.52)
    local rightX = leftW + 16
    local rightW = w - rightX - 16

    if not isPlayerPhase and curMon then
      local species = curMon.species or curMon.speciesId or "UNKNOWN"
      local def = data.pokemon and data.pokemon[species]
      local name = speciesLabel(species, curMon.nickname, data)
      local level = curMon.level or 1
      local types = (def and def.types) or { "NORMAL" }

      -- Left: Victory Plaque Card
      Layout.drawCard(16, 52, leftW, bodyH, {
        color = theme.surface,
        borderColor = theme.border,
        radius = 8,
      })

      Layout.drawText("HALL OF FAME INDUCTEE", 32, 68, { font = "caption", color = theme.colors.accent, bold = true })
      Layout.drawText(name:upper(), 32, 90, { font = "title", color = theme.heading, bold = true })
      Layout.drawBadge(leftW - 80, 92, ("LV %d"):format(level), { kind = "team", font = "tiny" })

      local uniqueTypes = Widgets.getUniqueTypes(types)
      local tx = 32
      for _, t in ipairs(uniqueTypes) do
        local bw = Widgets.drawTypeBadge(t, tx, 124, { width = 76, height = 26, font = "tiny" })
        tx = tx + bw + 8
      end

      Layout.drawSlot(32, 162, leftW - 32, 44, {
        color = theme.surfaceHigh,
        borderColor = theme.hpYellow,
        borderWidth = 1.5,
        radius = 6,
      })
      Layout.drawText("★  KANTO CHAMPION RIBBON  ★", 48, 175, { font = "caption", color = theme.hpYellow, bold = true })

      local def = data.pokemon and data.pokemon[species]
      local st = StatResolver.getStats(curMon, def, game)
      local sy = 216
      Layout.drawText("BATTLE STATISTICS", 32, sy, { font = "caption", color = theme.textMuted, bold = true })
      sy = sy + 20

      local statRows
      if st.isSplit then
        statRows = {
          { label = "MAX HP", val = st.maxHp },
          { label = "ATTACK", val = st.attack },
          { label = "DEFENSE", val = st.defense },
          { label = "SP. ATK", val = st.spAttack },
          { label = "SP. DEF", val = st.spDefense },
          { label = "SPEED", val = st.speed },
        }
      else
        statRows = {
          { label = "MAX HP", val = st.maxHp },
          { label = "ATTACK", val = st.attack },
          { label = "DEFENSE", val = st.defense },
          { label = "SPEED", val = st.speed },
          { label = "SPECIAL", val = st.special },
        }
      end
      local rowSlotH = st.isSplit and 20 or 24
      local rowGap = st.isSplit and 23 or 28
      for _, sr in ipairs(statRows) do
        Layout.drawSlot(32, sy, leftW - 32, rowSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 4 })
        Layout.drawText(sr.label, 42, sy + 3, { font = "tiny", color = theme.textDim })
        Layout.drawText(tostring(sr.val), leftW - 24, sy + 3, { font = "tiny", color = theme.heading, align = "right", bold = true })
        sy = sy + rowGap
      end

      -- Right: Large Hero Stage & Portrait
      Layout.drawCard(rightX, 52, rightW, bodyH, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        radius = 8,
      })

      SpriteHelper.drawFrontPic(data, species, rightX + 16, 52, rightW - 32, bodyH - 60, { kind = "summary", scale = 3.2 })

      love.graphics.setColor(theme.borderStrong[1], theme.borderStrong[2], theme.borderStrong[3], 0.3)
      Layout.drawEllipse("line", rightX + rightW / 2, 52 + bodyH - 60, rightW / 2 - 20, 24)
    else
      Layout.drawCard(16, 52, leftW, bodyH, {
        color = theme.surface,
        borderColor = theme.borderStrong,
        borderWidth = 2,
        radius = 8,
      })

      Layout.drawText("NEW LEAGUE CHAMPION", 32, 68, { font = "caption", color = theme.hpYellow, bold = true })
      Layout.drawText(player.name or "RED", 32, 92, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(leftW - 110, 94, ("ID: %05d"):format(player.id or save.playerID or 0), { kind = "gold", font = "tiny" })

      local py = 140
      local rawPT = save.playTime or save.time or 0
      local pHours, pMins = 0, 0
      if type(rawPT) == "number" then
        local ptSec = math.floor(rawPT)
        pHours = math.floor(ptSec / 3600)
        pMins = math.floor((ptSec % 3600) / 60)
      elseif type(rawPT) == "table" then
        pHours = tonumber(rawPT.hours or rawPT.h or rawPT[1]) or 0
        pMins = tonumber(rawPT.minutes or rawPT.m or rawPT[2]) or 0
      end
      local moneyStr = ("¥%d"):format(tonumber(player.money or save.money) or 0)

      local pRows = {
        { label = "PLAY TIME", val = ("%02d:%02d"):format(pHours, pMins) },
        { label = "PRIZE MONEY", val = moneyStr },
        { label = "LEAGUE BADGES", val = "8 / 8  (KANTO)" },
        { label = "POKÉDEX SEEN", val = tostring(BaseAdapter.countFlags(save.pokedex and save.pokedex.seen)) },
        { label = "POKÉDEX OWNED", val = tostring(math.max(
          BaseAdapter.countFlags(save.pokedex and save.pokedex.owned),
          BaseAdapter.countFlags(save.pokedex and save.pokedex.caught))) },
      }

      for _, row in ipairs(pRows) do
        Layout.drawSlot(32, py, leftW - 32, 32, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText(row.label, 44, py + 8, { font = "caption", color = theme.textDim })
        Layout.drawText(row.val, leftW - 24, py + 8, { font = "button", color = theme.heading, align = "right", bold = true })
        py = py + 38
      end

      Layout.drawCard(rightX, 52, rightW, bodyH, {
        color = theme.surfaceHigh,
        borderColor = theme.borderStrong,
        radius = 8,
      })

      local titlePlayer = data.field and data.field.title and data.field.title.player
      if type(titlePlayer) == "table" then titlePlayer = titlePlayer.path end
      local pImg = nil
      if titlePlayer then
        local ok, img = pcall(love.graphics.newImage, titlePlayer)
        if ok and img then pImg = img end
      end

      if pImg then
        local iw, ih = pImg:getDimensions()
        local scale = 3.4
        local px = rightX + math.floor((rightW - iw * scale) / 2)
        local py = 52 + math.floor((bodyH - ih * scale) / 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(pImg, px, py, 0, scale, scale)
      end
    end
  end

  -- Action prompt bar
  local hints = {
    { key = "A", label = "Advance", primary = true },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return HallOfFameRenderer
