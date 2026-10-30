-- OmniUI League PC (Hall of Fame Archives) Renderer
-- Modern split-pane archive viewer with defensive schema validation, orientation adaptability, and fast-jump pagination.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local PaletteFX = require("src.render.PaletteFX")
local Sprites = require("src.pokemon.Sprites")
local SpriteHelper = require("mods.omni_ui.core.SpriteHelper")

local LeaguePcRenderer = {}

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

local function packedTeams(raw)
  local teams = {}
  for i, team in ipairs(raw or {}) do
    local packed = {}
    if type(team) == "table" then
      for _, mon in ipairs(team) do
        local species = mon and (mon.species or mon.speciesId)
        if species and species ~= 0 and species ~= "0" then packed[#packed + 1] = mon end
      end
    end
    teams[i] = packed
  end
  return teams
end

function LeaguePcRenderer.draw(game, state, w, h, theme, subState, progress)
  theme = theme or require("mods.omni_ui.core.Theme").get()
  local data = game and game.data or {}
  local teams = state._teams and packedTeams(state._teams) or (state.teams or {})
  local teamCount = #teams
  local curTeamIdx = math.max(1, math.min(teamCount > 0 and teamCount or 1, state._team or state.teamIndex or 1))
  local curMonIdx = math.max(1, math.min(6, state._mon or state.monIndex or 1))

  local curTeam = teams[curTeamIdx] or {}
  local curMon = curTeam[curMonIdx]

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait
  local footY = h - 38

  -- 1. Outer Frame
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
  local archiveTitle = state._teams and "HALL OF FAME" or (isNarrow and "HALL OF FAME" or "INDIGO PLATEAU • HALL OF FAME ARCHIVES")
  Layout.drawText(archiveTitle, 18, 12, { font = "headline", color = theme.heading, bold = true })
  local counterStr = ("RECORD %d / %d"):format(curTeamIdx, math.max(1, teamCount))
  Layout.drawBadge(w - (isNarrow and 110 or 180), 10, counterStr, { kind = "gold", font = "caption", height = 24 })

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE STACKED HERO INSPECTOR + 6-SLOT ROSTER
    -- =========================================================================
    local heroH = 96
    Layout.drawCard(0, 48, w, heroH, {
      color = theme.surface,
      borderColor = theme.border,
      radius = 8,
    })

    if curMon then
      local rawSpecies = curMon.species or curMon.speciesId
      local def = (rawSpecies and data.pokemon and data.pokemon[rawSpecies]) or nil
      local speciesName = speciesLabel(rawSpecies, curMon.nickname, data)
      local level = curMon.level or 1
      local types = (def and def.types) or { "NORMAL" }

      local boxSize = 76
      Layout.drawSlot(8, 58, boxSize, boxSize, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

      SpriteHelper.drawFrontPic(data, rawSpecies, 8, 58, boxSize, boxSize, { kind = "summary" })

      local hx = boxSize + 16
      local hw = w - hx - 10
      Layout.drawText(speciesName:upper(), hx, 56, { font = "headline", color = theme.heading, bold = true, width = hw - 60 })
      Layout.drawBadge(w - 64, 56, ("LV %d"):format(level), { kind = "gold", font = "tiny" })

      local uniqueTypes = Widgets.getUniqueTypes(types)
      local tyX = hx
      for _, t in ipairs(uniqueTypes) do
        local bw = Widgets.drawTypeBadge(t, tyX, 82)
        tyX = tyX + bw + 4
      end

      Layout.drawBadge(hx, 108, "★ CHAMPION ★", { kind = "gold", font = "tiny", height = 18 })
    else
      Layout.drawText("NO RECORD SELECTED", 16, 76, { font = "headline", color = theme.textMuted })
    end

    -- Bottom 6-Slot Roster Grid / List
    local rosterY = 48 + heroH + 6
    local rosterH = footY - rosterY - 6
    Layout.drawCard(0, rosterY, w, rosterH, {
      color = theme.surfaceHigh,
      borderColor = theme.border,
      radius = 8,
    })

    local slotH = math.max(34, math.floor((rosterH - 24) / 6))
    local slotGap = 3

    for i = 1, 6 do
      local sy = rosterY + 6 + (i - 1) * (slotH + slotGap)
      local mon = curTeam[i]
      local isSel = (i == curMonIdx)

      if isSel then
        Layout.drawCard(8, sy, w - 16, slotH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
      else
        Layout.drawSlot(8, sy, w - 16, slotH, {
          color = theme.surface,
          borderColor = theme.border,
          radius = 6,
        })
      end

      if mon then
        local rawSpecies = mon.species or mon.speciesId
        local def = (rawSpecies and data.pokemon and data.pokemon[rawSpecies]) or nil
        local speciesName = speciesLabel(rawSpecies, mon.nickname, data)
        local lvl = mon.level or 1
        local types = (def and def.types) or { "NORMAL" }

        -- Icon
        if rawSpecies then
          SpriteHelper.drawFrontPic(data, rawSpecies, 14, sy + 3, slotH - 6, slotH - 6, { kind = "summary" })
        end

        Layout.drawText(speciesName, 52, sy + 8, { font = "caption", color = theme.heading, bold = isSel, width = w - 180 })
        Layout.drawBadge(w - 60, sy + 6, ("Lv.%d"):format(lvl), { kind = isSel and "team" or "good", font = "tiny" })

        local uniqueTypes = Widgets.getUniqueTypes(types)
        if uniqueTypes[1] then
          Widgets.drawTypeBadge(uniqueTypes[1], w - 130, sy + 6)
        end
      else
        Layout.drawText("EMPTY SLOT", 52, sy + 8, { font = "tiny", color = theme.textMuted })
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

    -- Left Pane: 6-Slot Team Roster
    Layout.drawCard(16, 52, leftW, bodyH, {
      color = theme.surface,
      borderColor = theme.border,
      radius = 8,
    })
    Layout.drawText("CHAMPIONSHIP ROSTER", 32, 66, { font = "caption", color = theme.colors.accent, bold = true })

    local slotH = 46
    local slotGap = 6
    local startY = 90

    for i = 1, 6 do
      local sy = startY + (i - 1) * (slotH + slotGap)
      local mon = curTeam[i]
      local isSel = (i == curMonIdx)

      if mon then
        local rawSpecies = mon.species or mon.speciesId
        local def = (rawSpecies and data.pokemon and data.pokemon[rawSpecies]) or nil
        local speciesName = speciesLabel(rawSpecies, mon.nickname, data)
        local lvl = mon.level or 1
        local types = (def and def.types) or { "NORMAL" }

        if isSel then
          Layout.drawCard(32, sy, leftW - 32, slotH, {
            color = theme.accentDark,
            borderColor = theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(32, sy, leftW - 32, slotH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            radius = 6,
          })
        end

        if rawSpecies then
          SpriteHelper.drawFrontPic(data, rawSpecies, 36, sy + 4, slotH - 8, slotH - 8, { kind = "summary" })
        end

        Layout.drawText(speciesName, 88, sy + 6, { font = "button", color = theme.heading, bold = isSel })
        Layout.drawBadge(leftW - 74, sy + 6, ("LV %d"):format(lvl), { kind = isSel and "team" or "good", font = "tiny" })

        local uniqueTypes = Widgets.getUniqueTypes(types)
        local tx = 88
        for _, t in ipairs(uniqueTypes) do
          local bw = Widgets.drawTypeBadge(t, tx, sy + 24, { width = 56, height = 18, font = "tiny" })
          tx = tx + bw + 4
        end
      else
        Layout.drawSlot(32, sy, leftW - 32, slotH, {
          color = { 0.15, 0.15, 0.18, 0.25 },
          borderColor = theme.border,
          radius = 6,
        })
        Layout.drawText("EMPTY SLOT", 48, sy + 14, { font = "tiny", color = theme.textMuted })
      end
    end

    -- Right Pane: Selected Pokémon Hero Inspector
    Layout.drawCard(rightX, 52, rightW, bodyH, {
      color = theme.surfaceHigh,
      borderColor = theme.border,
      radius = 8,
    })

    if curMon then
      local rawSpecies = curMon.species or curMon.speciesId
      local def = (rawSpecies and data.pokemon and data.pokemon[rawSpecies]) or nil
      local speciesName = speciesLabel(rawSpecies, curMon.nickname, data)
      local level = curMon.level or 1

      local portH = 170
      Layout.drawSlot(rightX + 16, 68, rightW - 32, portH, {
        color = theme.surface,
        borderColor = theme.border,
        radius = 8,
      })

      SpriteHelper.drawFrontPic(data, rawSpecies, rightX + 16, 68, rightW - 32, portH, { kind = "summary", scale = 2.4 })

      local ty = 68 + portH + 12
      Layout.drawText(speciesName:upper(), rightX + 18, ty, { font = "title", color = theme.heading, bold = true })
      Layout.drawBadge(rightX + rightW - 80, ty + 2, ("LV %d"):format(level), { kind = "gold", font = "tiny" })

      local uniqueTypes = Widgets.getUniqueTypes((def and def.types) or { "NORMAL" })
      local bx = rightX + 18
      for _, t in ipairs(uniqueTypes) do
        local bw = Widgets.drawTypeBadge(t, bx, ty + 28, { width = 74, height = 24, font = "tiny" })
        bx = bx + bw + 6
      end

      Layout.drawSlot(rightX + 16, ty + 62, rightW - 32, 38, {
        color = theme.surface,
        borderColor = theme.hpYellow,
        borderWidth = 1,
        radius = 6,
      })
      Layout.drawText("★  INDUCTED CHAMPION  ★", rightX + 32, ty + 74, { font = "caption", color = theme.hpYellow, bold = true })
    else
      Layout.drawText("NO RECORD SELECTED", rightX + 24, 80, { font = "title", color = theme.textMuted })
    end
  end

  local function getGen()
    local ver = game and (game.gameVersion or (game.cart and game.cart.gameVersion) or (game.save and game.save.gameVersion))
    if ver then
      ver = tostring(ver):lower()
      if ver == "firered" or ver == "leafgreen" or ver == "emerald" or ver == "ruby" or ver == "sapphire" then return 3 end
      if ver == "gold" or ver == "silver" or ver == "crystal" then return 2 end
      if ver == "red" or ver == "blue" or ver == "yellow" then return 1 end
    end
    local saveGen = game and game.save and game.save.generation
    if saveGen then return saveGen end
    if package.loaded["src.battle.game3"] ~= nil or package.loaded["src.world.game3"] ~= nil then return 3 end
    if package.loaded["src.battle.gen2"] ~= nil or package.loaded["src.world.gen2"] ~= nil then return 2 end
    return 1
  end

  -- 4. Action Bar
  local hints = {
    { key = "▲ ▼", label = "Select Mon", primary = true },
    { key = "◄ ►", label = "Record" },
  }
  if getGen() >= 3 then
    table.insert(hints, { key = "L R", label = "±10" })
  end
  table.insert(hints, { key = "B", label = "Back" })
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return LeaguePcRenderer
