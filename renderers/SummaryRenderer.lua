-- OmniUI Summary Screen Renderer
-- Responsive multi-tab Pokémon stat, move, and detail inspector with vector typography,
-- orientation awareness (portrait & landscape), and adaptive multi-device scaling.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local Sprites = require("src.pokemon.Sprites")
local PaletteFX = require("src.render.PaletteFX")
local Growth = require("src.pokemon.Growth")
local SpriteHelper = require("mods.omni_ui.core.SpriteHelper")
local Shiny = pcall(require, "src.pokemon.Shiny") and require("src.pokemon.Shiny") or nil
local StatResolver = require("mods.omni_ui.core.StatResolver")
local MoveDatabase = require("mods.omni_ui.core.MoveDatabase")
local ContestDatabase = require("mods.omni_ui.core.ContestDatabase")

local SummaryRenderer = {}

local function textBlockHeight(text, fontName, width)
  text = Layout.cleanText(text)
  local lineH = Layout.textHeight(fontName)
  local lines = 1
  local font = Layout.getFont(fontName)
  if width > 0 and font and font.getWrap then
    local _, wrapped = font:getWrap(text, width)
    lines = math.max(1, type(wrapped) == "table" and #wrapped or 1)
  elseif width > 0 then
    lines = math.max(1, math.ceil(Layout.textWidth(text, fontName) / width))
  end
  return lines * lineH
end

--- Height and inner offsets for the OT / met slot. The slot grows with wrapped lines.
function SummaryRenderer.trainerBlock(otLine, originDesc, width, opts)
  opts = opts or {}
  width = math.max(40, tonumber(width) or 160)
  local labelH = opts.labeled and Layout.textHeight("tiny") or 0
  local nameH = textBlockHeight(otLine, "caption", width)
  local memoH = textBlockHeight(originDesc, "tiny", width)
  local nameY = 6 + (opts.labeled and (labelH + 2) or 0)
  local memoY = nameY + nameH + 4
  local height = memoY + memoH + 8
  if opts.labeled then height = math.max(54, height) end
  return {
    height = height,
    labelY = 6,
    nameY = nameY,
    memoY = memoY,
  }
end

local frontPics = {}
local function frontPic(path)
  if not path then return nil end
  if not frontPics[path] then
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
      img:setFilter("nearest", "nearest")
      frontPics[path] = img
    end
  end
  return frontPics[path]
end

local ABILITY_DESCRIPTIONS = {
  OVERGROW = "Powers up Grass-type moves when HP is low.",
  BLAZE = "Powers up Fire-type moves when HP is low.",
  TORRENT = "Powers up Water-type moves when HP is low.",
  SWARM = "Powers up Bug-type moves when HP is low.",
  STATIC = "Contact with the Pokémon may cause paralysis.",
  INTIMIDATE = "Lowers the opposing Pokémon's Attack stat on entry.",
  LEVITATE = "Gives full immunity to all Ground-type attacks.",
  PRESSURE = "Raises opposing Pokémon's PP usage for moves.",
  SYNCHRONIZE = "Passes poison, paralysis, or burn to the foe.",
  STURDY = "Cannot be knocked out with one hit at full HP.",
  KEEN_EYE = "Prevents other Pokémon from lowering accuracy.",
  SAND_VEIL = "Boosts evasion in a sandstorm.",
  SWIFT_SWIM = "Boosts the Pokémon's Speed stat in rain.",
  CHLOROPHYLL = "Boosts the Pokémon's Speed stat in harsh sunlight.",
  FLASH_FIRE = "Powers up Fire-type moves if hit by one; immune to Fire.",
  WATER_ABSORB = "Restores HP if hit by a Water-type move.",
  VOLT_ABSORB = "Restores HP if hit by an Electric-type move.",
  INSOMNIA = "Prevents the Pokémon from falling asleep.",
  IMMUNITY = "Prevents the Pokémon from getting poisoned.",
  LIMBER = "Prevents the Pokémon from becoming paralyzed.",
  NATURAL_CURE = "All status conditions heal when switching out.",
  EFFECT_SPORE = "Contact may inflict poison, sleep, or paralysis.",
  GUTS = "Boosts Attack when afflicted by a status condition.",
  MARVEL_SCALE = "Boosts Defense when afflicted by a status condition.",
  SERENE_GRACE = "Boosts the likelihood of additional move effects.",
  TRACE = "Copies a foe's ability upon entering battle.",
  RUN_AWAY = "Enables a sure getaway from wild Pokémon encounters.",
  INNER_FOCUS = "Protects the Pokémon from flinching.",
  OBLIVIOUS = "Prevents the Pokémon from becoming infatuated.",
  POISON_POINT = "Contact with the Pokémon may poison the attacker.",
  SHED_SKIN = "The Pokémon may heal its own status conditions each turn.",
  SHIELD_DUST = "Blocks the additional effects of attacks taken.",
  COMPOUND_EYES = "Boosts the Pokémon's accuracy.",
  CLEAR_BODY = "Prevents other Pokémon from lowering its stats.",
  SPEED_BOOST = "Its Speed stat is gradually boosted each turn.",
  DRIZZLE = "Summons rain when entering battle.",
  DROUGHT = "Turns the sunlight harsh when entering battle.",
  SAND_STREAM = "Summons a sandstorm when entering battle.",
  SNOW_WARNING = "Summons a hailstorm when entering battle.",
}

local function getAbilityDescription(ability, game)
  if not ability or ability == "" or ability == "None" or ability == "NONE" then
    return nil
  end
  local normKey = tostring(ability):upper():gsub("[%s%-]", "_")
  if ABILITY_DESCRIPTIONS[normKey] then
    return ABILITY_DESCRIPTIONS[normKey]
  end
  if game and game.data and game.data.abilities and game.data.abilities[normKey] then
    local aDef = game.data.abilities[normKey]
    if type(aDef) == "table" and (aDef.description or aDef.desc) then
      return aDef.description or aDef.desc
    end
  end
  return "Special combat trait and passive innate ability."
end

local function drawEggSummary(game, mon, w, h, theme, isNarrow)
  local footY = h - 38
  local cycles = tonumber(mon.eggCycles or mon.eggSteps or mon.happiness or 0) or 0
  local flavor = mon.eggFlavorText or "Wonder what's inside? It needs more time, though."
  local progress = math.max(0, math.min(1.0, 1.0 - (cycles / 41)))
  local eggName = "POKéMON EGG"
  local time = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock() or 0
  local bob = math.sin(time * 3.5) * 4

  if not isNarrow then
    -- Landscape
    Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText(eggName, 18, 12, { font = "headline", color = theme.heading, bold = true })
    local nameW = Layout.textWidth(eggName, "headline")
    Layout.drawBadge(18 + nameW + 12, 12, "INCUBATING", { kind = "accent" })

    local lw = math.max(190, math.min(240, math.floor(w * 0.34)))
    local bodyH = h - 96
    Layout.drawCard(0, 52, lw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    -- Egg Sprite / Graphic
    local portSlotH = math.max(120, math.min(160, bodyH - 120))
    Layout.drawSlot(14, 66, lw - 28, portSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })

    SpriteHelper.drawFrontPic(game.data, "EGG", 14, 66, lw - 28, portSlotH, {
      mon = mon,
      kind = "summary",
      scale = 2.0,
    })

    local badgeY = 66 + portSlotH + 16
    Layout.drawBadge(16, badgeY, "POKéMON EGG", { kind = "ghost" })

    -- Origin slot
    local otSlotY = bodyH + 52 - 62
    local otSlotH = 54
    Layout.drawSlot(14, otSlotY, lw - 28, otSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
    Layout.drawText("ORIGIN", 20, otSlotY + 5, { font = "tiny", color = theme.textDim, bold = true })
    Layout.drawText(mon.otName or "DAY-CARE", 20, otSlotY + 20, { font = "caption", color = theme.heading, bold = true })
    Layout.drawText("An odd POKéMON EGG.", 20, otSlotY + 36, { font = "tiny", color = theme.textDim })

    -- Right Column: Card Details
    local rx = lw + 12
    local rw = w - rx
    Layout.drawCard(rx, 52, rw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    Layout.drawText("EGG INCUBATION STATUS", rx + 24, 70, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(rx + rw - 130, 68, "INCUBATING", { kind = "accent" })

    -- Incubation Flavor Text Box
    local flavorBoxY = 104
    local flavorBoxH = 92
    Layout.drawSlot(rx + 14, flavorBoxY, rw - 28, flavorBoxH, { color = theme.surfaceHigh, borderColor = theme.borderStrong, borderWidth = 1, radius = 8 })
    Layout.drawText("INCUBATION STAGE", rx + 24, flavorBoxY + 8, { font = "tiny", color = theme.textDim, bold = true })
    Layout.drawTextWrapped(flavor, rx + 24, flavorBoxY + 26, rw - 48, { font = "body", color = theme.heading })

    -- Progress Bar Card
    local progBoxY = flavorBoxY + flavorBoxH + 12
    local progBoxH = 76
    Layout.drawSlot(rx + 14, progBoxY, rw - 28, progBoxH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
    Layout.drawText("HATCH PROGRESS", rx + 24, progBoxY + 8, { font = "caption", color = theme.textDim, bold = true })
    Layout.drawHealthBar(rx + 24, progBoxY + 32, rw - 48, 8, math.floor(progress * 100), 100, { color = theme.colors.accent or { 0.4, 0.7, 1.0 } })
    Layout.drawText(("Relative Hatch Progress: %d%%"):format(math.floor(progress * 100)), rx + 24, progBoxY + 48, { font = "caption", color = theme.textDim })

    -- Care Instructions Slot
    local infoBoxY = progBoxY + progBoxH + 12
    local infoBoxH = bodyH + 52 - infoBoxY - 14
    if infoBoxH >= 40 then
      Layout.drawSlot(rx + 14, infoBoxY, rw - 28, infoBoxH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
      Layout.drawText("CARE NOTES", rx + 24, infoBoxY + 8, { font = "tiny", color = theme.textDim, bold = true })
      Layout.drawTextWrapped("Keep the EGG in your active party while traveling to encourage hatching.", rx + 24, infoBoxY + 24, rw - 48, { font = "caption", color = theme.textDim })
    end
  else
    -- Portrait (isNarrow)
    Layout.drawCard(0, 0, w, 40, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText(eggName, 14, 10, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(w - 100, 8, "INCUBATING", { kind = "accent", font = "tiny" })

    local heroH = 92
    Layout.drawCard(0, 46, w, heroH, { color = theme.surface, borderColor = theme.border, radius = 8 })
    local boxW = 76
    local boxH = 76
    Layout.drawSlot(8, 54, boxW, boxH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

    SpriteHelper.drawFrontPic(game.data, "EGG", 8, 54, boxW, boxH, {
      mon = mon,
      kind = "summary",
      scale = 1.3,
    })

    local hx = boxW + 18
    local hw = w - hx - 10
    Layout.drawText("POKéMON EGG", hx, 52, { font = "headline", color = theme.heading, bold = true, width = hw })
    Layout.drawBadge(hx, 74, "INCUBATING", { kind = "accent", font = "tiny" })
    Layout.drawHealthBar(hx, 102, hw, 5, math.floor(progress * 100), 100, { color = theme.colors.accent or { 0.4, 0.7, 1.0 } })
    Layout.drawText(("Progress: %d%%"):format(math.floor(progress * 100)), hx, 112, { font = "tiny", color = theme.textDim })

    local bodyY = 46 + heroH + 6
    local bodyH = footY - bodyY - 6
    Layout.drawCard(0, bodyY, w, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    Layout.drawSlot(8, bodyY + 8, w - 16, 90, { color = theme.surfaceHigh, borderColor = theme.borderStrong, borderWidth = 1, radius = 6 })
    Layout.drawText("INCUBATION STAGE", 16, bodyY + 14, { font = "tiny", color = theme.textDim, bold = true })
    Layout.drawTextWrapped(flavor, 16, bodyY + 30, w - 32, { font = "body", color = theme.heading })

    local noteY = bodyY + 106
    local noteH = bodyY + bodyH - noteY - 8
    if noteH >= 40 then
      Layout.drawSlot(8, noteY, w - 16, noteH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("CARE NOTES", 16, noteY + 6, { font = "tiny", color = theme.textDim, bold = true })
      Layout.drawTextWrapped("Keep the EGG in your party to hatch.", 16, noteY + 22, w - 32, { font = "tiny", color = theme.textDim })
    end
  end

  local hints = {
    { key = "A / B", label = "Close", primary = true },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 6 or 16 })
end

function SummaryRenderer.draw(game, state, w, h, theme)
  local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
  local adapter = AdapterResolver.resolve(game)

  local mon = state.mon
    or (state._party and state._party[state._cursor or 1])
    or (state.party and state.party[state.cursor or state.index or 1])
  if not mon and adapter then
    mon = adapter:getMon(state.index or state.cursor or 1)
  end
  if not mon then return end

  if (not mon.normalized) and adapter then
    mon = adapter:normalizeMon(mon)
  end

  local isGen3 = false
  if adapter and adapter.generation then
    isGen3 = (adapter.generation == 3)
  elseif game then
    local v = game.gameVersion or (game.cart and game.cart.gameVersion) or game.version
    if v then
      v = tostring(v):lower()
      isGen3 = (v == "emerald" or v == "ruby" or v == "sapphire" or v == "firered" or v == "leafgreen")
    end
    if not isGen3 and game.save and (game.save.session or game.save.game3) then
      isGen3 = true
    end
  end
  if not isGen3 and state then
    if state == package.loaded["src.ui.game3.summary_menu"] or state == package.loaded["src.ui.game3.rse.summary_menu"] or (state._party ~= nil and state._page ~= nil) then
      isGen3 = true
    end
  end
  if not isGen3 then
    state.movesSubTab = "battle"
  end

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait

  -- 0. Egg Incubation Short-Circuit
  if mon.isEgg or mon.species == "EGG" or (mon.name == "EGG" and mon.level == nil) or (state._page == 4) then
    drawEggSummary(game, mon, w, h, theme, isNarrow)
    return
  end

  local def = (game.data and game.data.pokemon and game.data.pokemon[mon.species]) or {}

  -- Resolve Summary Tab page (Defaults to Tab 1: STATS across all games)
  local page = state.page
  if not page then
    if state._page ~= nil then
      if state._page == 1 then
        page = 1
      elseif state._page == 2 or state._page == 3 then
        page = 2
      elseif state._page == 0 then
        page = 3
      else
        page = 1
      end
    else
      page = 1
    end
    state.page = page
  end
  page = page or 1

  -- Synchronize native Gen 3 _page when appropriate
  if state._page ~= nil then
    if page == 3 and state._page ~= 0 then
      state._page = 0
    elseif page == 2 and (state._page ~= 2 and state._page ~= 3) then
      state._page = 2
    elseif page == 1 and state._page ~= 1 then
      state._page = 1
    end
  end

  -- Move cursor & swap mapping
  if state.moveIndex == nil and state._moveCursor ~= nil then
    state.moveIndex = state._moveCursor
  end
  if state.swapSlot == nil and state._swapSlot ~= nil then
    state.swapSlot = state._swapSlot
  end
  state.moveIndex = state.moveIndex or 1

  -- Ensure moveIndex is clamped to valid move count so cursor never disappears
  local validMoveCount = 0
  for _, mv in ipairs(mon.moves or {}) do
    local mid = (type(mv) == "table" and mv.id) or mv
    if mid then validMoveCount = validMoveCount + 1 end
  end
  validMoveCount = math.max(1, math.min(4, validMoveCount))
  if state.moveIndex > validMoveCount or state.moveIndex < 1 then
    state.moveIndex = 1
  end

  state.movesSubTab = state.movesSubTab or "battle"
  local inMovesSubmenu = (state.inMovesSubmenu == true) or (state._page == 3) or (state.moveDetail == true)

  local PublicApi = require("mods.omni_ui.api.PublicApi")
  local HookBoundary = require("mods.omni_ui.core.HookBoundary")

  -- Growth and Experience Calculations
  local growthRate = mon.growthRate or (def and (def.growthRate or def.growth)) or "MEDIUM_FAST"
  local curLevel = tonumber(mon.level or 1)
  local curExp = tonumber(mon.exp or Growth.expForLevel(growthRate, curLevel))
  local curLvlBaseExp = mon.curLevelExp or Growth.expForLevel(growthRate, curLevel)
  local nextLvlExp = mon.expNext or ((curLevel < 100) and Growth.expForLevel(growthRate, curLevel + 1) or curExp)
  local expToNext = mon.expNeeded or ((curLevel < 100) and math.max(0, nextLvlExp - curExp) or 0)
  local expDenominator = math.max(1, nextLvlExp - curLvlBaseExp)
  local expProgress = mon.expPercent or ((curLevel >= 100) and 1.0 or math.max(0, math.min(1.0, (curExp - curLvlBaseExp) / expDenominator)))

  -- Trainer and Met Origin Information
  local otName = mon.otName or mon.ot or (game.save and game.save.player and game.save.player.name) or (game.session and (game.session.playerName or game.session.name)) or "RED"
  local otId = mon.otId or mon.trainerId or (game.save and game.save.player and game.save.player.id) or 0
  local playerId = game.save and game.save.player and game.save.player.id

  local metLocation = mon.met or mon.caughtLocation or mon.metLocation or mon.origin or mon.location or mon.caughtAt
  local metLevel = mon.metLevel or mon.caughtLevel
  local originDesc = mon.originDesc
  if not originDesc or originDesc == "" then
    if metLocation then
      if metLevel then
        originDesc = ("Met at %s (Lv. %d)"):format(tostring(metLocation), tonumber(metLevel))
      else
        originDesc = ("Met at %s"):format(tostring(metLocation))
      end
    elseif playerId and otId ~= playerId then
      originDesc = ("Obtained in Link Trade with %s"):format(otName)
    else
      if metLevel then
        originDesc = ("Faithful partner met at Lv. %d"):format(tonumber(metLevel))
      else
        originDesc = "Faithful partner met in Kanto"
      end
    end
  end

  -- 1. Resolve Dynamic Tabs List
  local tabs = isNarrow and { "STATS", "MOVES", "INFO" } or { "1. STATS", "2. MOVES", "3. DETAILS" }
  local customTabsList = {}
  if PublicApi and PublicApi.summaryTabs then
    for _, tDef in pairs(PublicApi.summaryTabs) do
      customTabsList[#customTabsList + 1] = tDef
    end
    table.sort(customTabsList, function(a, b) return tostring(a.id) < tostring(b.id) end)
    for ci, tDef in ipairs(customTabsList) do
      local tLabel = (tDef.label or tDef.id):upper()
      tabs[#tabs + 1] = isNarrow and tLabel or ("%d. %s"):format(3 + ci, tLabel)
    end
  end
  state._expMaxPage = #tabs

  local footY = h - 38

  if not isNarrow then
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-COLUMN LAYOUT
    -- =========================================================================
    -- Top Header Card with Title and Tabs
    Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
    local name = (mon.displayName and mon.displayName ~= "" and mon.displayName) or (mon.name and mon.name ~= "" and mon.name) or (mon.nickname and mon.nickname ~= "" and mon.nickname) or def.name or tostring(mon.speciesName or mon.species or "POKÉMON")
    if mon.form and mon.form ~= "" and not name:find("%(") then
      name = name .. " (" .. mon.form .. ")"
    end
    local isMale = (mon.gender == "M" or mon.gender == "MALE")
    local isFemale = (mon.gender == "F" or mon.gender == "FEMALE")
    local genderSym = isMale and "♂" or (isFemale and "♀" or "")
    local genderColor = isMale and { 0.35, 0.65, 0.95 } or (isFemale and { 0.95, 0.45, 0.65 } or theme.heading)

    Layout.drawText(name, 18, 12, { font = "headline", color = theme.heading, bold = true })
    local nameW = Layout.textWidth(name, "headline")
    if genderSym ~= "" then
      Layout.drawText(genderSym, 18 + nameW + 6, 12, { font = "headline", color = genderColor, bold = true })
      nameW = nameW + Layout.textWidth(genderSym, "headline") + 6
    end
    Layout.drawBadge(18 + nameW + 10, 12, ("Lv. %d"):format(mon.level or 1), { kind = "good" })
    local badgeOffX = 18 + nameW + 10 + Layout.textWidth(("Lv. %d"):format(mon.level or 1), "badge") + 16
    if mon.pokerus == "infected" then
      Layout.drawBadge(badgeOffX, 12, "PKRS", { kind = "danger" })
    elseif mon.pokerus == "cured" then
      Layout.drawBadge(badgeOffX, 12, "●", { kind = "ghost" })
    end

    local tabCount = #tabs
    local tabW = math.max(64, math.min(108, math.floor((w - (18 + nameW + 120)) / tabCount)))
    for t = 1, tabCount do
      local isTab = (page == t)
      local tx = w - (tabCount + 1 - t) * (tabW + 6) - 10
      Layout.drawButton(tx, 7, tabW, 30, tabs[t], {
        kind = isTab and "accent" or "ghost",
        selected = isTab,
        font = "caption",
      })
    end

    local lw = math.max(190, math.min(240, math.floor(w * 0.34)))
    local bodyH = h - 96
    Layout.drawCard(0, 52, lw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local otTextW = lw - 48
    local otLine = otName .. (" (#%05d)"):format(otId)
    local trainerBox = SummaryRenderer.trainerBlock(otLine, originDesc, otTextW, { labeled = true })
    local cardBottom = 52 + bodyH
    local otSlotH = trainerBox.height
    local otSlotY = cardBottom - 8 - otSlotH
    local minStack = 66 + 72 + 96
    if otSlotY < minStack then
      otSlotY = minStack
      otSlotH = math.max(54, cardBottom - 8 - otSlotY)
    end

    -- Front Portrait Box with Multi-Generation PaletteFX / GBC Palette Colorization
    local portSlotH = math.max(72, math.min(136, otSlotY - 161, bodyH - 200))
    Layout.drawSlot(14, 66, lw - 28, portSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })

    local isShiny = mon.isShiny or (mon.dvs and Shiny and Shiny.isShiny and Shiny.isShiny(mon.dvs)) or false
    SpriteHelper.drawFrontPic(game.data, mon.species, 14, 66, lw - 28, portSlotH, {
      mon = mon,
      isShiny = isShiny,
      kind = "summary",
      scale = (portSlotH < 120) and 1.5 or 2.0,
    })

    -- Level Badge & Status
    local badgeY = 66 + portSlotH + 10
    Layout.drawBadge(16, badgeY, ("Lv. %d"):format(mon.level or 1), { kind = "ghost" })
    local curBadgeX = 82
    if (mon.hp or 0) <= 0 then
      Layout.drawBadge(curBadgeX, badgeY, "FNT", { kind = "danger" })
      curBadgeX = curBadgeX + 54
    elseif mon.status then
      Layout.drawBadge(curBadgeX, badgeY, tostring(mon.status):upper(), { kind = "warn" })
      curBadgeX = curBadgeX + 54
    end

    -- Dual Type Badges (Deduplicated for single-type Pokémon)
    local tyY = badgeY + 26
    local uniqueTypes = Widgets.getUniqueTypes((mon and mon.types) or def.types or { "NORMAL" })
    if #uniqueTypes > 0 then
      local tyX = 16
      for _, t in ipairs(uniqueTypes) do
        local bw = Widgets.drawTypeBadge(t, tyX, tyY)
        tyX = tyX + bw + 6
      end
    end

    -- HP Meter
    local hpY = tyY + 28
    local maxHp = (mon.stats and mon.stats.hp) or mon.maxHp or mon.hp or 1
    Layout.drawHealthBar(16, hpY, lw - 32, 6, mon.hp or 0, maxHp)
    Layout.drawText(("HP %d / %d"):format(mon.hp or 0, maxHp), 16, hpY + 12, { font = "tiny", color = theme.textDim })

    -- OT / ID & Origin Information Slot. Grows so the met line can wrap instead of clipping.
    Layout.drawSlot(14, otSlotY, lw - 28, otSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
    Layout.drawText("ORIGINAL TRAINER", 20, otSlotY + trainerBox.labelY, { font = "tiny", color = theme.textDim, bold = true })
    Layout.drawTextWrapped(otLine, 20, otSlotY + trainerBox.nameY, otTextW, { font = "caption", color = theme.heading })
    Layout.drawTextWrapped(otLine, 21, otSlotY + trainerBox.nameY, otTextW, { font = "caption", color = theme.heading })
    Layout.drawTextWrapped(originDesc, 20, otSlotY + trainerBox.memoY, otTextW, { font = "tiny", color = theme.textDim })

    -- Right Column: Tab Content Panel
    local rx = lw + 12
    local rw = w - rx
    Layout.drawCard(rx, 52, rw, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    if page == 1 then
      -- Page 1: Stats Overview & Growth Matrix (Supports Split Special Attack / Defense)
      local st = StatResolver.getStats(mon, def, game)
      local statRows
      if st.isSplit then
        statRows = {
          { "ATTACK",  st.attack,    { 0.95, 0.45, 0.25 }, "attack" },
          { "DEFENSE", st.defense,   { 0.35, 0.65, 0.95 }, "defense" },
          { "SP. ATK", st.spAttack,  { 0.85, 0.45, 0.95 }, "spAttack" },
          { "SP. DEF", st.spDefense, { 0.35, 0.85, 0.85 }, "spDefense" },
          { "SPEED",   st.speed,     { 0.35, 0.85, 0.45 }, "speed" },
        }
      else
        statRows = {
          { "ATTACK",  st.attack,  { 0.95, 0.45, 0.25 }, "attack" },
          { "DEFENSE", st.defense, { 0.35, 0.65, 0.95 }, "defense" },
          { "SPEED",   st.speed,   { 0.35, 0.85, 0.45 }, "speed" },
          { "SPECIAL", st.special, { 0.85, 0.45, 0.95 }, "special" },
        }
      end

      local statBenchmark = math.max(30, math.min(255, math.floor((mon.level or 5) * 2.5 + 20)))
      local statSlotH = 34
      local statGap = 4

      for si, s in ipairs(statRows) do
        local sy = 64 + (si - 1) * (statSlotH + statGap)
        Layout.drawSlot(rx + 14, sy, rw - 28, statSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        local sLabel = s[1]
        local sColor = theme.heading
        if mon.natureBoosted and s[4] == mon.natureBoosted then
          sLabel = sLabel .. " ▲"
          sColor = { 0.95, 0.45, 0.45 }
        elseif mon.natureLowered and s[4] == mon.natureLowered then
          sLabel = sLabel .. " ▼"
          sColor = { 0.45, 0.65, 0.95 }
        end
        Layout.drawText(sLabel, rx + 24, sy + 8, { font = "button", color = sColor, bold = true })
        Layout.drawText(tostring(s[2]), rx + rw - 60, sy + 8, { font = "button", color = sColor, bold = true })
        Layout.drawHealthBar(rx + 120, sy + 14, rw - 190, 6, s[2], statBenchmark, { color = s[3] })
      end

      -- Experience & Level Progress Card
      local expBoxY = 64 + #statRows * (statSlotH + statGap) + 6
      local expBoxH = 76
      Layout.drawSlot(rx + 14, expBoxY, rw - 28, expBoxH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
      Layout.drawText("EXPERIENCE & GROWTH", rx + 24, expBoxY + 8, { font = "caption", color = theme.textDim, bold = true })

      local expColW = math.floor((rw - 56) / 2)
      Layout.drawText(("TOTAL EXP: %d"):format(curExp), rx + 24, expBoxY + 28, { font = "headline", color = theme.heading, bold = true })
      local nextExpText = (curLevel >= 100) and "MAX LEVEL" or ("TO NEXT LV: %d"):format(expToNext)
      Layout.drawText(nextExpText, rx + 24 + expColW, expBoxY + 28, { font = "headline", color = (curLevel >= 100) and theme.hpGreen or theme.accent, bold = true })

      Layout.drawHealthBar(rx + 24, expBoxY + 52, rw - 48, 6, curExp - curLvlBaseExp, expDenominator, { color = theme.colors.accent or { 0.4, 0.6, 1.0 } })
      Layout.drawText(("Lv. %d Progress (%d%%)"):format(curLevel, math.floor(expProgress * 100)), rx + 24, expBoxY + 60, { font = "tiny", color = theme.textDim })

      -- Battle Attributes & Stat Performance Card
      local traitBoxY = expBoxY + expBoxH + 8
      local traitBoxH = bodyH + 52 - traitBoxY - 14
      if traitBoxH >= 40 then
        local curStatSum = st.total

        Layout.drawSlot(rx + 14, traitBoxY, rw - 28, traitBoxH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
        Layout.drawText("BATTLE ATTRIBUTES", rx + 24, traitBoxY + 8, { font = "caption", color = theme.textDim, bold = true })
        local colW = math.floor((rw - 56) / 2)
        Layout.drawText(("STAT TOTAL: %d"):format(curStatSum), rx + 24, traitBoxY + 26, { font = "headline", color = theme.heading, bold = true })
        local itemText = (mon.heldItem or mon.item or "None")
        Layout.drawText(("HELD: %s"):format(itemText), rx + 24 + colW, traitBoxY + 26, { font = "headline", color = theme.heading, bold = true, width = colW - 8 })
        if traitBoxH >= 64 then
          local natureText = mon.nature and ("Nature: " .. tostring(mon.nature)) or ("Growth Rate: " .. growthRate:gsub("_", " "))
          Layout.drawText(natureText, rx + 24, traitBoxY + 46, { font = "tiny", color = theme.textDim })
        end
      end
    elseif page == 2 then
      -- Page 2: Moves & Detailed Move Inspector (Battle & Beauty Contest Views)
      local moves = mon.moves or {}
      local moveCur = state.moveIndex or 1
      local isContest = isGen3 and (state.movesSubTab == "contest")

      local subtabY = 56
      local subtabH = 26
      local startY
      if isGen3 then
        local subtabW = math.floor((rw - 36) / 2)
        Layout.drawButton(rx + 14, subtabY, subtabW, subtabH, "BATTLE MOVES", {
          kind = not isContest and "accent" or "ghost",
          selected = not isContest,
          font = "caption",
        })
        Layout.drawButton(rx + 14 + subtabW + 8, subtabY, subtabW, subtabH, "CONTEST MOVES", {
          kind = isContest and "accent" or "ghost",
          selected = isContest,
          font = "caption",
        })
        startY = subtabY + subtabH + 6
      else
        startY = 60
      end
      local moveSlotH = 34
      local moveGap = 4
      for mi = 1, 4 do
        local my = startY + (mi - 1) * (moveSlotH + moveGap)
        local mv = moves[mi]
        local moveId = (type(mv) == "table" and mv.id) or mv
        local mdef = MoveDatabase.getMoveDef(moveId, mv, game)
        local isSel = inMovesSubmenu and (moveCur == mi) and (moveId ~= nil)
        local isSwapSource = inMovesSubmenu and (state.swapSlot == mi)
        local isSwapTarget = inMovesSubmenu and (state.swapSlot ~= nil and moveCur == mi and state.swapSlot ~= mi)

        if isSwapSource then
          Layout.drawCard(rx + 14, my, rw - 28, moveSlotH, {
            color = { 0.35, 0.28, 0.08, 0.9 },
            borderColor = { 0.95, 0.78, 0.25 },
            borderWidth = 2,
            radius = 6,
          })
        elseif isSwapTarget then
          Layout.drawCard(rx + 14, my, rw - 28, moveSlotH, {
            color = theme.accentDark,
            borderColor = theme.colors.accent or { 0.4, 0.7, 1.0 },
            borderWidth = 2,
            radius = 6,
          })
        elseif isSel then
          Layout.drawCard(rx + 14, my, rw - 28, moveSlotH, {
            color = theme.accentDark,
            borderColor = theme.colors.accent or theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(rx + 14, my, rw - 28, moveSlotH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
        end

        if moveId then
          local moveName = (mdef and mdef.name) or tostring(moveId):gsub("_", " ")

          if isContest then
            -- Beauty Contest Move View
            local cdef = ContestDatabase.getContestDef(moveId, mv, game)
            local catDef = cdef and cdef.categoryDef or ContestDatabase.getCategoryDef(cdef and cdef.category or "COOL")

            -- Category Badge with authentic vibrant color
            Layout.drawCard(rx + 20, my + 6, 68, 22, {
              color = catDef.bg,
              borderColor = catDef.border,
              borderWidth = 1,
              radius = 4,
            })
            Layout.drawText(catDef.name, rx + 26, my + 8, { font = "tiny", color = catDef.color, bold = true })

            -- Move Name
            Layout.drawText(moveName, rx + 98, my + 8, { font = "button", color = isSel and theme.heading or theme.text, bold = isSel })

            -- Appeal Vector Hearts
            Layout.drawText("APPEAL", rx + rw - 228, my + 11, { font = "tiny", color = theme.textDim, bold = true })
            Layout.drawHeartsMeter(rx + rw - 176, my + 11, cdef and cdef.appeal or 4, 6, {
              size = 11,
              gap = 3,
              color = catDef.color,
              emptyColor = theme.borderStrong,
            })

            -- Jam Vector Hearts
            Layout.drawText("JAM", rx + rw - 88, my + 11, { font = "tiny", color = theme.textDim, bold = true })
            if cdef and cdef.jam and cdef.jam > 0 then
              Layout.drawHeartsMeter(rx + rw - 60, my + 11, cdef.jam, cdef.jam, {
                size = 11,
                gap = 3,
                color = { 0.95, 0.40, 0.35 },
                emptyColor = theme.borderStrong,
              })
            else
              Layout.drawText("-", rx + rw - 56, my + 9, { font = "caption", color = theme.textMuted })
            end
          else
            -- Battle Move View
            local moveType = (mdef and mdef.type) or "NORMAL"
            Widgets.drawTypeBadge(moveType, rx + 20, my + 6)
            Layout.drawText(moveName, rx + 110, my + 8, { font = "button", color = isSel and theme.heading or theme.text, bold = isSel })

            local category = MoveDatabase.getCategory(moveId, mdef, game)
            local catKind = (category == "PHYSICAL" and "warn") or (category == "SPECIAL" and "accent") or "ghost"
            Layout.drawBadge(rx + rw - 195, my + 6, category, { kind = catKind, font = "tiny" })

            local curPP, maxPP
            if type(mv) == "table" and tonumber(mv.maxPP or mv.maxPp) and tonumber(mv.maxPP or mv.maxPp) > 0 then
              maxPP = tonumber(mv.maxPP or mv.maxPp)
              curPP = tonumber(mv.pp) or maxPP
            else
              local basePP = (mdef and mdef.pp) or (type(mv) == "table" and mv.pp) or 15
              curPP = (type(mv) == "table" and mv.pp) or basePP
              local ppUps = (type(mv) == "table" and mv.ppUps) or 0
              maxPP = basePP + ppUps * math.max(1, math.floor(basePP / 5))
            end
            Layout.drawText(("PP %d/%d"):format(curPP, maxPP), rx + rw - 110, my + 8, { font = "caption", color = isSel and theme.heading or theme.textDim, bold = isSel })
          end

          -- Swap Mode Indicators
          if isSwapSource then
            Layout.drawBadge(rx + rw - 180, my + 6, "REORDER", { kind = "warn", font = "tiny" })
          elseif isSwapTarget then
            Layout.drawBadge(rx + rw - 180, my + 6, "SWAP HERE", { kind = "good", font = "tiny" })
          end
        else
          Layout.drawText("- - - - -", rx + 24, my + 8, { font = "caption", color = theme.textMuted })
        end
      end

      -- Selected Move Specification & Description Card
      local curMv = moves[moveCur] or moves[1]
      local curMoveId = (type(curMv) == "table" and curMv.id) or curMv
      local curMdef = MoveDatabase.getMoveDef(curMoveId, curMv, game)
      local inspY = startY + 4 * (moveSlotH + moveGap) + 4
      local inspH = bodyH + 52 - inspY - 14

      Layout.drawCard(rx + 14, inspY, rw - 28, inspH, {
        color = theme.surfaceHigh,
        borderColor = theme.borderStrong,
        borderWidth = 1,
        radius = 8,
      })

      if curMoveId then
        local statColW = math.floor((rw - 60) / 4)

        if isContest then
          -- Contest Inspector
          local cdef = ContestDatabase.getContestDef(curMoveId, curMdef, game)
          local catDef = cdef and cdef.categoryDef or ContestDatabase.getCategoryDef(cdef and cdef.category or "COOL")
          local appealStr = ContestDatabase.formatAppealHearts(cdef and cdef.appeal or 4, 8)
          local jamStr = ContestDatabase.formatJamHearts(cdef and cdef.jam or 0)
          local effTag = cdef and cdef.effectTag or "CONTEST MOVE"
          local descText = cdef and cdef.desc or "A stylish contest performance."

          Layout.drawText("CATEGORY", rx + 24, inspY + 7, { font = "tiny", color = theme.textDim, bold = true })
          Layout.drawCard(rx + 24, inspY + 20, 72, 20, {
            color = catDef.bg,
            borderColor = catDef.border,
            borderWidth = 1,
            radius = 4,
          })
          Layout.drawText(catDef.name, rx + 28, inspY + 22, { font = "tiny", color = catDef.color, bold = true })

          Layout.drawText("APPEAL", rx + 24 + statColW, inspY + 7, { font = "tiny", color = theme.textDim, bold = true })
          Layout.drawHeartsMeter(rx + 24 + statColW, inspY + 23, cdef and cdef.appeal or 4, 8, {
            size = 13,
            gap = 4,
            color = catDef.color,
            emptyColor = theme.borderStrong,
          })

          Layout.drawText("JAM", rx + 24 + statColW * 2, inspY + 7, { font = "tiny", color = theme.textDim, bold = true })
          if cdef and cdef.jam and cdef.jam > 0 then
            Layout.drawHeartsMeter(rx + 24 + statColW * 2, inspY + 23, cdef.jam, cdef.jam, {
              size = 13,
              gap = 4,
              color = { 0.95, 0.40, 0.35 },
              emptyColor = theme.borderStrong,
            })
          else
            Layout.drawText("-", rx + 24 + statColW * 2, inspY + 20, { font = "headline", color = theme.textMuted, bold = true })
          end

          Layout.drawText("TACTIC", rx + 24 + statColW * 3, inspY + 7, { font = "tiny", color = theme.textDim, bold = true })
          Layout.drawBadge(rx + 24 + statColW * 3, inspY + 20, effTag, { kind = "accent", font = "tiny" })

          Layout.drawSlot(rx + 22, inspY + 44, rw - 44, 1, { color = theme.border })
          Layout.drawTextWrapped(descText, rx + 24, inspY + 50, rw - 48, { font = "body", color = theme.text })

          if inspH >= 115 then
            local comboText = "CONTEST COMBO: Combines with other " .. catDef.name .. " moves to earn bonus appeal applause."
            Layout.drawText(comboText, rx + 24, inspY + inspH - 20, { font = "tiny", color = theme.textDim })
          end
        else
          -- Battle Inspector
          local category = MoveDatabase.getCategory(curMoveId, curMdef, game)
          local catKind = (category == "PHYSICAL" and "warn") or (category == "SPECIAL" and "accent") or "ghost"
          local pwrStr = MoveDatabase.getPowerString(curMdef)
          local accStr = MoveDatabase.getAccuracyString(curMdef)
          local effTag = MoveDatabase.getEffectTag(curMoveId, curMdef, game)
          local descText = MoveDatabase.getDescription(curMoveId, curMdef, game)

          Layout.drawText("POWER", rx + 24, inspY + 7, { font = "tiny", color = theme.textDim, bold = true })
          Layout.drawText(pwrStr, rx + 24, inspY + 20, { font = "headline", color = theme.heading, bold = true })

          Layout.drawText("ACCURACY", rx + 24 + statColW, inspY + 7, { font = "tiny", color = theme.textDim, bold = true })
          Layout.drawText(accStr, rx + 24 + statColW, inspY + 20, { font = "headline", color = theme.heading, bold = true })

          Layout.drawText("CLASS", rx + 24 + statColW * 2, inspY + 7, { font = "tiny", color = theme.textDim, bold = true })
          Layout.drawBadge(rx + 24 + statColW * 2, inspY + 20, category, { kind = catKind, font = "tiny" })

          Layout.drawText("EFFECT", rx + 24 + statColW * 3, inspY + 7, { font = "tiny", color = theme.textDim, bold = true })
          Layout.drawBadge(rx + 24 + statColW * 3, inspY + 20, effTag, { kind = "good", font = "tiny" })

          Layout.drawSlot(rx + 22, inspY + 44, rw - 44, 1, { color = theme.border })
          Layout.drawTextWrapped(descText, rx + 24, inspY + 50, rw - 48, { font = "body", color = theme.text })
        end
      else
        Layout.drawText("NO MOVE SELECTED", rx + 24, inspY + 18, { font = "caption", color = theme.textMuted, bold = true })
        Layout.drawText("Select a known move to inspect its combat power, accuracy, and tactical effect.", rx + 24, inspY + 40, { font = "body", color = theme.textDim, width = rw - 48 })
      end
    elseif page == 3 then
      -- Page 3: Ability, Nature, Held Item, Growth
      local py = 64
      local rawAbility = mon.ability or (def and def.ability)
      local abilityName = (rawAbility and rawAbility ~= "" and rawAbility ~= "None" and rawAbility ~= "NONE") and tostring(rawAbility):gsub("_", " ") or nil
      local abilityDesc = mon.abilityDesc or (abilityName and getAbilityDescription(rawAbility, game)) or nil

      if abilityName then
        local abSlotH = 68
        Layout.drawSlot(rx + 14, py, rw - 28, abSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("ABILITY", rx + 24, py + 8, { font = "tiny", color = theme.textDim, bold = true })
        Layout.drawText(abilityName:upper(), rx + 24, py + 22, { font = "headline", color = theme.heading, bold = true })
        Layout.drawTextWrapped(abilityDesc or "Special combat trait and passive innate ability.", rx + 24, py + 42, rw - 48, { font = "caption", color = theme.textDim })
        py = py + abSlotH + 8
      else
        local abSlotH = 48
        Layout.drawSlot(rx + 14, py, rw - 28, abSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("ABILITY", rx + 24, py + 8, { font = "tiny", color = theme.textDim, bold = true })
        Layout.drawText("None (Standard Classical Combat)", rx + 24, py + 24, { font = "caption", color = theme.textMuted })
        py = py + abSlotH + 8
      end

      local details = {
        { "NATURE", mon.nature or "Hardy" },
        { "HELD ITEM", mon.heldItem or mon.item or "None" },
        { "EXP GROWTH", growthRate:gsub("_", " ") },
        { "BASE EXP", tostring(mon.baseExp or def.baseExp or "---") },
      }
      if mon.ribbons and type(mon.ribbons) == "number" and mon.ribbons > 0 then
        details[#details + 1] = { "RIBBONS", tostring(mon.ribbons) }
      end
      for _, d in ipairs(details) do
        Layout.drawSlot(rx + 14, py, rw - 28, 42, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText(d[1], rx + 24, py + 12, { font = "caption", color = theme.textDim })
        Layout.drawText(d[2], rx + 140, py + 12, { font = "headline", color = theme.heading, bold = true, width = rw - 160 })
        py = py + 48
      end
    else
      -- Page 4+: Custom Mod-Registered Tab
      local cIndex = page - 3
      local cTab = customTabsList[cIndex]
      if cTab and cTab.draw and type(cTab.draw) == "function" then
        HookBoundary.safeRender(cTab.id or ("summary_tab_" .. page), cTab.draw, game, mon, rx, 52, rw, bodyH, theme)
      else
        Layout.drawText("CUSTOM TAB", rx + 24, 70, { font = "headline", color = theme.heading, bold = true })
        Layout.drawSlot(rx + 14, 104, rw - 28, 120, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("No renderer attached for this summary tab.", rx + 24, 126, { font = "caption", color = theme.textDim })
      end
    end
  else
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE ADAPTIVE LAYOUT
    -- =========================================================================
    -- Top Tab Bar: dedicated clean full-width buttons
    Layout.drawCard(0, 0, w, 40, { color = theme.surface, borderColor = theme.border, radius = 8 })
    local tabCount = #tabs
    local tabW = math.floor((w - 12) / tabCount)
    for t = 1, tabCount do
      local isTab = (page == t)
      local tx = 6 + (t - 1) * tabW
      Layout.drawButton(tx, 5, tabW - 4, 30, tabs[t], {
        kind = isTab and "accent" or "ghost",
        selected = isTab,
        font = "caption",
      })
    end

    -- Mini Hero Card: Sprite on left, Mon Name + Lv + Types + HP on right
    local heroH = 92
    Layout.drawCard(0, 46, w, heroH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local boxW = 76
    local boxH = 76
    Layout.drawSlot(8, 54, boxW, boxH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

    local isShiny = mon.isShiny or (mon.dvs and Shiny and Shiny.isShiny and Shiny.isShiny(mon.dvs)) or false
    SpriteHelper.drawFrontPic(game.data, mon.species, 8, 54, boxW, boxH, {
      mon = mon,
      isShiny = isShiny,
      kind = "summary",
      scale = 1.2,
    })

    local hx = boxW + 18
    local hw = w - hx - 10
    local name = (mon.displayName and mon.displayName ~= "" and mon.displayName) or (mon.name and mon.name ~= "" and mon.name) or (mon.nickname and mon.nickname ~= "" and mon.nickname) or def.name or tostring(mon.speciesName or mon.species or "POKÉMON")
    if mon.form and mon.form ~= "" and not name:find("%(") then
      name = name .. " (" .. mon.form .. ")"
    end
    local isMale = (mon.gender == "M" or mon.gender == "MALE")
    local isFemale = (mon.gender == "F" or mon.gender == "FEMALE")
    local genderSym = isMale and "♂" or (isFemale and "♀" or "")
    local genderColor = isMale and { 0.35, 0.65, 0.95 } or (isFemale and { 0.95, 0.45, 0.65 } or theme.heading)

    Layout.drawText(name, hx, 52, { font = "headline", color = theme.heading, bold = true, width = hw - 70 })
    local nameW = Layout.textWidth(name, "headline")
    if genderSym ~= "" and hx + nameW + 6 < w - 80 then
      Layout.drawText(genderSym, hx + nameW + 6, 52, { font = "headline", color = genderColor, bold = true })
    end
    Layout.drawBadge(w - 56, 52, ("Lv. %d"):format(mon.level or 1), { kind = "good", font = "tiny" })
    if mon.pokerus == "infected" then
      Layout.drawBadge(w - 100, 52, "PKRS", { kind = "danger", font = "tiny" })
    elseif mon.pokerus == "cured" then
      Layout.drawBadge(w - 78, 52, "●", { kind = "ghost", font = "tiny" })
    end

    -- Dual Types (Deduplicated for single-type Pokémon)
    local uniqueTypes = Widgets.getUniqueTypes((mon and mon.types) or def.types or { "NORMAL" })
    if #uniqueTypes > 0 then
      local tyX = hx
      for _, t in ipairs(uniqueTypes) do
        local bw = Widgets.drawTypeBadge(t, tyX, 74)
        tyX = tyX + bw + 4
      end
    end

    -- HP Bar & Numbers
    local maxHp = (mon.stats and mon.stats.hp) or mon.maxHp or mon.hp or 1
    Layout.drawHealthBar(hx, 102, hw, 5, mon.hp or 0, maxHp)
    Layout.drawText(("HP %d/%d"):format(mon.hp or 0, maxHp), hx, 112, { font = "tiny", color = theme.textDim })
    if (mon.hp or 0) <= 0 then
      Layout.drawBadge(w - 50, 110, "FNT", { kind = "danger", font = "tiny", height = 16 })
    elseif mon.status then
      Layout.drawBadge(w - 50, 110, tostring(mon.status):upper(), { kind = "warn", font = "tiny", height = 16 })
    end

    -- Full-Width Tab Content Panel
    local bodyY = 46 + heroH + 6
    local bodyH = footY - bodyY - 6
    Layout.drawCard(0, bodyY, w, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    if page == 1 then
      -- Page 1: Stats & EXP & Origin
      local st = StatResolver.getStats(mon, def, game)
      local statRows
      if st.isSplit then
        statRows = {
          { "ATTACK",  st.attack,    { 0.95, 0.45, 0.25 }, "attack" },
          { "DEFENSE", st.defense,   { 0.35, 0.65, 0.95 }, "defense" },
          { "SP. ATK", st.spAttack,  { 0.85, 0.45, 0.95 }, "spAttack" },
          { "SP. DEF", st.spDefense, { 0.35, 0.85, 0.85 }, "spDefense" },
          { "SPEED",   st.speed,     { 0.35, 0.85, 0.45 }, "speed" },
        }
      else
        statRows = {
          { "ATTACK",  st.attack,  { 0.95, 0.45, 0.25 }, "attack" },
          { "DEFENSE", st.defense, { 0.35, 0.65, 0.95 }, "defense" },
          { "SPEED",   st.speed,   { 0.35, 0.85, 0.45 }, "speed" },
          { "SPECIAL", st.special, { 0.85, 0.45, 0.95 }, "special" },
        }
      end

      local statBenchmark = math.max(30, math.min(255, math.floor((mon.level or 5) * 2.5 + 20)))
      local statRowH = 26
      local statGap = 2

      for si, s in ipairs(statRows) do
        local sy = bodyY + 6 + (si - 1) * (statRowH + statGap)
        Layout.drawSlot(8, sy, w - 16, statRowH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 5 })
        local sLabel = s[1]
        local sColor = theme.heading
        if mon.natureBoosted and s[4] == mon.natureBoosted then
          sLabel = sLabel .. " ▲"
          sColor = { 0.95, 0.45, 0.45 }
        elseif mon.natureLowered and s[4] == mon.natureLowered then
          sLabel = sLabel .. " ▼"
          sColor = { 0.45, 0.65, 0.95 }
        end
        Layout.drawText(sLabel, 16, sy + 6, { font = "tiny", color = sColor, bold = true })
        Layout.drawText(tostring(s[2]), w - 44, sy + 6, { font = "tiny", color = sColor, bold = true })
        Layout.drawHealthBar(82, sy + 10, w - 132, 5, s[2], statBenchmark, { color = s[3] })
      end

      -- Experience & Level Progress Card
      local expY = bodyY + 6 + #statRows * (statRowH + statGap) + 4
      local expH = 64
      Layout.drawSlot(8, expY, w - 16, expH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("EXPERIENCE POINTS", 16, expY + 6, { font = "tiny", color = theme.textDim, bold = true })
      Layout.drawText(("TOTAL: %d"):format(curExp), 16, expY + 22, { font = "tiny", color = theme.heading, bold = true })
      local nextExpText = (curLevel >= 100) and "MAX LEVEL" or ("NEXT LV: %d"):format(expToNext)
      Layout.drawText(nextExpText, w - 110, expY + 22, { font = "tiny", color = (curLevel >= 100) and theme.hpGreen or theme.accent, bold = true })
      Layout.drawHealthBar(16, expY + 38, w - 32, 5, curExp - curLvlBaseExp, expDenominator, { color = theme.colors.accent or { 0.4, 0.6, 1.0 } })
      Layout.drawText(("Lv. %d Progress (%d%%)"):format(curLevel, math.floor(expProgress * 100)), 16, expY + 47, { font = "tiny", color = theme.textDim })

      -- Original Trainer & Met Origin Card
      local otY = expY + expH + 4
      local otTextW = w - 40
      local otLine = ("OT: %s  (#%05d)"):format(otName, otId)
      local trainerBox = SummaryRenderer.trainerBlock(otLine, originDesc, otTextW)
      local room = bodyY + bodyH - otY - 6
      local otH = math.min(trainerBox.height, math.max(44, room))
      if otY + 36 <= bodyY + bodyH then
        Layout.drawSlot(8, otY, w - 16, otH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawTextWrapped(otLine, 16, otY + trainerBox.nameY, otTextW, { font = "caption", color = theme.heading })
        Layout.drawTextWrapped(otLine, 17, otY + trainerBox.nameY, otTextW, { font = "caption", color = theme.heading })
        Layout.drawTextWrapped(originDesc, 16, otY + trainerBox.memoY, otTextW, { font = "tiny", color = theme.textDim })
      end
    elseif page == 2 then
      -- Page 2: Moves & Detailed Inspector (Battle & Beauty Contest Views in Portrait)
      local moves = mon.moves or {}
      local moveCur = state.moveIndex or 1
      local isContest = isGen3 and (state.movesSubTab == "contest")

      local subtabY = bodyY + 6
      local subtabH = 22
      local startSlotY
      if isGen3 then
        local subtabW = math.floor((w - 24) / 2)
        Layout.drawButton(8, subtabY, subtabW, subtabH, "BATTLE", {
          kind = not isContest and "accent" or "ghost",
          selected = not isContest,
          font = "tiny",
        })
        Layout.drawButton(8 + subtabW + 8, subtabY, subtabW, subtabH, "CONTEST", {
          kind = isContest and "accent" or "ghost",
          selected = isContest,
          font = "tiny",
        })
        startSlotY = subtabY + subtabH + 4
      else
        startSlotY = bodyY + 6
      end
      local slotH = 28
      for mi = 1, 4 do
        local my = startSlotY + (mi - 1) * (slotH + 3)
        local mv = moves[mi]
        local moveId = (type(mv) == "table" and mv.id) or mv
        local mdef = MoveDatabase.getMoveDef(moveId, mv, game)
        local isSel = inMovesSubmenu and (moveCur == mi) and (moveId ~= nil)
        local isSwapSource = inMovesSubmenu and (state.swapSlot == mi)
        local isSwapTarget = inMovesSubmenu and (state.swapSlot ~= nil and moveCur == mi and state.swapSlot ~= mi)

        if isSwapSource then
          Layout.drawCard(8, my, w - 16, slotH, {
            color = { 0.35, 0.28, 0.08, 0.9 },
            borderColor = { 0.95, 0.78, 0.25 },
            borderWidth = 2,
            radius = 6,
          })
        elseif isSwapTarget then
          Layout.drawCard(8, my, w - 16, slotH, {
            color = theme.accentDark,
            borderColor = theme.colors.accent or { 0.4, 0.7, 1.0 },
            borderWidth = 2,
            radius = 6,
          })
        elseif isSel then
          Layout.drawCard(8, my, w - 16, slotH, {
            color = theme.accentDark,
            borderColor = theme.colors.accent or theme.borderStrong,
            borderWidth = 2,
            radius = 6,
          })
        else
          Layout.drawSlot(8, my, w - 16, slotH, {
            color = theme.surfaceHigh,
            borderColor = theme.border,
            borderWidth = 1,
            radius = 6,
          })
        end

        if moveId then
          local moveName = (mdef and mdef.name) or tostring(moveId):gsub("_", " ")

          if isContest then
            local cdef = ContestDatabase.getContestDef(moveId, mv, game)
            local catDef = cdef and cdef.categoryDef or ContestDatabase.getCategoryDef(cdef and cdef.category or "COOL")
            Layout.drawCard(12, my + 4, 52, 20, {
              color = catDef.bg,
              borderColor = catDef.border,
              borderWidth = 1,
              radius = 4,
            })
            Layout.drawText(catDef.name, 16, my + 6, { font = "tiny", color = catDef.color, bold = true })
            Layout.drawText(moveName, 70, my + 5, { font = "caption", color = isSel and theme.heading or theme.text, bold = isSel, width = w - 160 })
            Layout.drawHeartsMeter(w - 76, my + 8, cdef and cdef.appeal or 4, 5, {
              size = 9,
              gap = 2,
              color = catDef.color,
              emptyColor = theme.borderStrong,
            })
          else
            local moveType = (mdef and mdef.type) or "NORMAL"
            Widgets.drawTypeBadge(moveType, 12, my + 4)
            Layout.drawText(moveName, 90, my + 5, { font = "caption", color = isSel and theme.heading or theme.text, bold = isSel, width = w - 176 })

            local curPP, maxPP
            if type(mv) == "table" and tonumber(mv.maxPP or mv.maxPp) and tonumber(mv.maxPP or mv.maxPp) > 0 then
              maxPP = tonumber(mv.maxPP or mv.maxPp)
              curPP = tonumber(mv.pp) or maxPP
            else
              local basePP = (mdef and mdef.pp) or (type(mv) == "table" and mv.pp) or 15
              curPP = (type(mv) == "table" and mv.pp) or basePP
              maxPP = basePP + ((type(mv) == "table" and mv.ppUps) or 0) * math.max(1, math.floor(basePP / 5))
            end
            Layout.drawText(("PP %d/%d"):format(curPP, maxPP), w - 80, my + 6, { font = "tiny", color = isSel and theme.heading or theme.textDim, bold = isSel })
          end

          if isSwapSource then
            Layout.drawBadge(w - 75, my + 4, "REORDER", { kind = "warn", font = "tiny", height = 18 })
          elseif isSwapTarget then
            Layout.drawBadge(w - 82, my + 4, "SWAP HERE", { kind = "good", font = "tiny", height = 18 })
          end
        else
          Layout.drawText("- - - - -", 16, my + 6, { font = "caption", color = theme.textMuted })
        end
      end

      -- Selected Move Inspector in Portrait
      local curMv = moves[moveCur] or moves[1]
      local curMoveId = (type(curMv) == "table" and curMv.id) or curMv
      local curMdef = MoveDatabase.getMoveDef(curMoveId, curMv, game)

      local inspY = startSlotY + 4 * (slotH + 3) + 3
      local inspH = bodyY + bodyH - inspY - 6

      Layout.drawCard(8, inspY, w - 16, inspH, {
        color = theme.surfaceHigh,
        borderColor = theme.borderStrong,
        borderWidth = 1,
        radius = 8,
      })

      if curMoveId then
        local halfW = math.floor((w - 36) / 2)

        if isContest then
          local cdef = ContestDatabase.getContestDef(curMoveId, curMdef, game)
          local catDef = cdef and cdef.categoryDef or ContestDatabase.getCategoryDef(cdef and cdef.category or "COOL")
          local appealStr = ContestDatabase.formatAppealHearts(cdef and cdef.appeal or 4, 6)
          local jamStr = ContestDatabase.formatJamHearts(cdef and cdef.jam or 0)
          local effTag = cdef and cdef.effectTag or "CONTEST MOVE"
          local descText = cdef and cdef.desc or "A stylish contest performance."

          Layout.drawCard(16, inspY + 6, 68, 18, {
            color = catDef.bg,
            borderColor = catDef.border,
            borderWidth = 1,
            radius = 4,
          })
          Layout.drawText(catDef.name, 20, inspY + 8, { font = "tiny", color = catDef.color, bold = true })
          Layout.drawBadge(16 + halfW, inspY + 6, effTag, { kind = "accent", font = "tiny", height = 18 })

          Layout.drawText("APPEAL:", 16, inspY + 28, { font = "tiny", color = theme.textDim, bold = true })
          Layout.drawHeartsMeter(68, inspY + 29, cdef and cdef.appeal or 4, 8, {
            size = 10,
            gap = 3,
            color = catDef.color,
            emptyColor = theme.borderStrong,
          })
          Layout.drawText("JAM:", 16 + halfW, inspY + 28, { font = "tiny", color = theme.textDim, bold = true })
          if cdef and cdef.jam and cdef.jam > 0 then
            Layout.drawHeartsMeter(16 + halfW + 32, inspY + 29, cdef.jam, cdef.jam, {
              size = 10,
              gap = 3,
              color = { 0.95, 0.40, 0.35 },
              emptyColor = theme.borderStrong,
            })
          else
            Layout.drawText("-", 16 + halfW + 32, inspY + 28, { font = "tiny", color = theme.textMuted, bold = true })
          end

          Layout.drawSlot(14, inspY + 46, w - 28, 1, { color = theme.border })
          Layout.drawTextWrapped(descText, 16, inspY + 52, w - 32, { font = "caption", color = theme.text })
        else
          local category = MoveDatabase.getCategory(curMoveId, curMdef, game)
          local catKind = (category == "PHYSICAL" and "warn") or (category == "SPECIAL" and "accent") or "ghost"
          local pwrStr = MoveDatabase.getPowerString(curMdef)
          local accStr = MoveDatabase.getAccuracyString(curMdef)
          local effTag = MoveDatabase.getEffectTag(curMoveId, curMdef, game)
          local descText = MoveDatabase.getDescription(curMoveId, curMdef, game)

          -- Row 1: Power & Accuracy
          Layout.drawText("PWR: " .. pwrStr, 16, inspY + 6, { font = "tiny", color = theme.heading, bold = true })
          Layout.drawText("ACC: " .. accStr, 16 + halfW, inspY + 6, { font = "tiny", color = theme.heading, bold = true })

          -- Row 2: Category Badge & Effect Badge
          Layout.drawBadge(16, inspY + 24, category, { kind = catKind, font = "tiny", height = 18 })
          Layout.drawBadge(16 + halfW, inspY + 24, effTag, { kind = "good", font = "tiny", height = 18 })

          Layout.drawSlot(14, inspY + 46, w - 28, 1, { color = theme.border })
          Layout.drawTextWrapped(descText, 16, inspY + 52, w - 32, { font = "caption", color = theme.text })
        end
      else
        Layout.drawText("No move selected", 16, inspY + 12, { font = "caption", color = theme.textDim })
      end
    elseif page == 3 then
      -- Page 3: Ability, Nature, Held Item, Growth
      local py = bodyY + 6
      local rawAbility = mon.ability or (def and def.ability)
      local abilityName = (rawAbility and rawAbility ~= "" and rawAbility ~= "None" and rawAbility ~= "NONE") and tostring(rawAbility):gsub("_", " ") or nil
      local abilityDesc = mon.abilityDesc or (abilityName and getAbilityDescription(rawAbility, game)) or nil

      if abilityName then
        local abSlotH = 62
        Layout.drawSlot(8, py, w - 16, abSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("ABILITY: " .. abilityName:upper(), 16, py + 6, { font = "caption", color = theme.heading, bold = true })
        Layout.drawTextWrapped(abilityDesc or "Special combat trait and passive innate ability.", 16, py + 24, w - 32, { font = "tiny", color = theme.textDim })
        py = py + abSlotH + 4
      else
        local abSlotH = 38
        Layout.drawSlot(8, py, w - 16, abSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("ABILITY: None (Classical Combat)", 16, py + 10, { font = "caption", color = theme.textMuted })
        py = py + abSlotH + 4
      end

      local details = {
        { "NATURE", mon.nature or "Hardy" },
        { "HELD ITEM", mon.heldItem or mon.item or "None" },
        { "EXP GROWTH", growthRate:gsub("_", " ") },
        { "BASE EXP", tostring(mon.baseExp or def.baseExp or "---") },
      }
      if mon.ribbons and type(mon.ribbons) == "number" and mon.ribbons > 0 then
        details[#details + 1] = { "RIBBONS", tostring(mon.ribbons) }
      end
      local slotH = 32
      local slotGap = 3
      for _, d in ipairs(details) do
        if py + slotH <= bodyY + bodyH - 4 then
          Layout.drawSlot(8, py, w - 16, slotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 5 })
          Layout.drawText(d[1], 16, py + 8, { font = "tiny", color = theme.textDim })
          Layout.drawText(d[2], 118, py + 8, { font = "caption", color = theme.heading, bold = true, width = w - 130 })
          py = py + slotH + slotGap
        end
      end
    else
      -- Page 4+: Custom Tab
      local cIndex = page - 3
      local cTab = customTabsList[cIndex]
      if cTab and cTab.draw and type(cTab.draw) == "function" then
        HookBoundary.safeRender(cTab.id or ("summary_tab_" .. page), cTab.draw, game, mon, 0, bodyY, w, bodyH, theme)
      else
        Layout.drawText("CUSTOM TAB", 16, bodyY + 12, { font = "headline", color = theme.heading, bold = true })
      end
    end
  end

  -- Bottom Button Hints Footer Bar
  local hints = {}
  if page == 2 then
    if state.swapSlot ~= nil then
      hints = {
        { key = "A", label = "Place / Swap Move", primary = true },
        { key = "B", label = "Cancel Swap" },
        { key = "▲ ▼", label = "Select Slot" },
      }
    elseif inMovesSubmenu then
      hints = {
        { key = "A", label = "Reorder Move", primary = true },
        { key = "▲ ▼", label = "Select Move" },
      }
      if isGen3 then
        table.insert(hints, { key = "◄ ►", label = (state.movesSubTab == "contest" and "Battle Moves" or "Contest Moves") })
      end
      table.insert(hints, { key = "B", label = "Back to Tabs" })
    else
      hints = {
        { key = "◄ ►", label = "Switch Tab", primary = true },
        { key = "A", label = "Manage Moves" },
        { key = "▲ ▼", label = "Switch Pokémon" },
        { key = "B", label = "Back" },
      }
    end
  else
    hints = {
      { key = "◄ ►", label = "Switch Tab", primary = true },
      { key = "▲ ▼", label = "Switch Pokémon" },
      { key = "B", label = "Back" },
    }
  end
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 6 or 16, gap = isNarrow and 10 or 20 })
end

return SummaryRenderer
