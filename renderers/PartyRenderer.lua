-- OmniUI Party Screen Renderer
-- Responsive 6-slot party overview with HP meters, type badges, vector typography,
-- orientation awareness, and adaptive multi-device scaling.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local SpriteHelper = require("mods.omni_ui.core.SpriteHelper")

local PartyRenderer = {}

local okGrowth, Growth = pcall(require, "src.pokemon.Growth")

local function getExpRatio(mon, def)
  if not mon then return 0 end
  local curLevel = tonumber(mon.level or 1) or 1
  if curLevel >= 100 then return 1.0 end

  if mon.expProgress and type(mon.expProgress) == "number" then
    return math.max(0, math.min(1.0, mon.expProgress))
  end
  if mon.expPercent and type(mon.expPercent) == "number" then
    local p = mon.expPercent
    if p > 1.0 then p = p / 100 end
    return math.max(0, math.min(1.0, p))
  end

  local curExp = tonumber(mon.exp)
  if mon.curLevelExp and mon.expNext and curExp then
    local baseExp = tonumber(mon.curLevelExp) or 0
    local nextExp = tonumber(mon.expNext) or (baseExp + 100)
    local denom = math.max(1, nextExp - baseExp)
    return math.max(0, math.min(1.0, (curExp - baseExp) / denom))
  end

  if okGrowth and Growth and Growth.expForLevel then
    local growthRate = mon.growthRate or (def and (def.growthRate or def.growth)) or "MEDIUM_FAST"
    local baseExp = tonumber(Growth.expForLevel(growthRate, curLevel) or 0)
    local nextExp = tonumber(Growth.expForLevel(growthRate, curLevel + 1) or (baseExp + 100))
    local denom = math.max(1, nextExp - baseExp)
    if curExp then
      return math.max(0, math.min(1.0, (curExp - baseExp) / denom))
    end
  end

  return 0.0
end

function PartyRenderer.draw(game, state, w, h, theme, subState, animProgress)
  local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")
  local adapter = AdapterResolver.resolve(game)
  local party = nil
  if adapter and adapter.getParty then
    local okParty, pList = pcall(adapter.getParty, adapter)
    if okParty and type(pList) == "table" and #pList > 0 then
      party = pList
    end
  end
  if not party or #party == 0 then
    local rawList = state.party or state._party or (game and game.save and game.save.party) or {}
    party = {}
    for i, m in ipairs(rawList) do
      party[i] = (adapter and adapter:normalizeMon(m, i)) or m
    end
  end
  local curIdx = state.index or state.cursor or 1
  local swapFrom = state.swapFrom or state.switchFrom
  -- Gen 3 keeps Cancel as a real cursor slot (7, or 8 beside Confirm when
  -- choosing several Pokémon) so L-as-A can leave the menu without B.
  local isGen3Party = adapter and adapter.generation == 3 and state and state.cursor ~= nil
    and (state._party ~= nil or state.ACTIONS ~= nil)
  local multiChoose = isGen3Party and state.mode == "choose_multi"
  local isTM = (state.tmhm ~= nil)
  local isEvoStone = (state.evoStone ~= nil)
  local isItemUse = (state.itemUse == true or state.pickOnly == true)

  local ctx = Layout.getContext(w, h)
  local isCompact = (w < 560) or ctx.isCompact

  -- Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  if isTM then
    local mdef = state.tmhm.move and game.data and game.data.moves and game.data.moves[state.tmhm.move]
    local moveName = mdef and (mdef.name or state.tmhm.move) or tostring(state.tmhm.move or "MOVE")
    Layout.drawText("TEACH TM / HM", 16, 12, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(Layout.textWidth("TEACH TM / HM", "headline") + 24, 10, ("MOVE: %s"):format(moveName), { kind = "accent", height = 24 })
    if not isCompact then
      Layout.drawText("Select Pokémon to teach", w - 190, 14, { font = "caption", color = theme.textDim })
    end
  elseif isEvoStone then
    local itemDef = game.data and game.data.items and game.data.items[state.evoStone]
    local stoneName = itemDef and (itemDef.name or state.evoStone) or tostring(state.evoStone or "STONE")
    Layout.drawText("USE EVOLUTION STONE", 16, 12, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(Layout.textWidth("USE EVOLUTION STONE", "headline") + 24, 10, stoneName, { kind = "accent", height = 24 })
    if not isCompact then
      Layout.drawText("Select Pokémon to evolve", w - 190, 14, { font = "caption", color = theme.textDim })
    end
  elseif isItemUse then
    Layout.drawText("USE ITEM", 16, 12, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(Layout.textWidth("USE ITEM", "headline") + 24, 10, "TARGET SELECT", { kind = "accent", height = 24 })
  else
    Layout.drawText("POKÉMON PARTY", 16, 12, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(Layout.textWidth("POKÉMON PARTY", "headline") + 24, 12, ("%d / 6 ACTIVE"):format(#party), { kind = "good" })
    if not isCompact then
      local headerHint = swapFrom and "Select slot to switch" or "Manage active team"
      if multiChoose and curIdx == 7 then
        headerHint = "Confirm the selection"
      elseif isGen3Party and curIdx == (multiChoose and 8 or 7) then
        headerHint = "Close the party"
      end
      Layout.drawText(headerHint, w - 180, 14, { font = "caption", color = theme.textDim })
    end
  end

  local footY = h - 38
  local bodyH = footY - 54
  local cancelBarH = isGen3Party and 40 or 0
  local cardH = isGen3Party
    and math.max(32, math.floor((bodyH - 12 - cancelBarH) / 6))
    or math.max(36, math.floor((bodyH - 20) / 6))

  for i = 1, 6 do
    local mon = party[i]
    local isSel = (curIdx == i)
    local isSwap = (swapFrom == i)
    local cy = 50 + (i - 1) * (cardH + 4)

    local offsetX = Layout.getCascadeOffset(i, animProgress, 0.028, 20)

    love.graphics.push()
    if offsetX ~= 0 then
      love.graphics.translate(offsetX, 0)
    end

    local cardColor = isSel and theme.accentDark or theme.surfaceHigh
    if isSwap then cardColor = theme.raised end
    local borderColor = isSel and theme.borderStrong or theme.border
    local borderWidth = isSel and 2 or 1

    if isSel then
      Layout.drawCard(0, cy, w, cardH, {
        color = cardColor,
        borderColor = borderColor,
        borderWidth = borderWidth,
        radius = 8,
      })
    else
      Layout.drawSlot(0, cy, w, cardH, {
        color = cardColor,
        borderColor = borderColor,
        borderWidth = borderWidth,
        radius = 8,
      })
    end

    if mon then
      local isEgg = (mon.isEgg == true) or (mon.species == "EGG" or mon.species == 253 or mon.species == 412 or mon.name == "POKéMON EGG")
      local def = (game.data and game.data.pokemon and game.data.pokemon[mon.species]) or {}
      local curHp = tonumber(mon.currentHp or mon.hp or 0) or 0
      local maxHp = tonumber(mon.maxHp or (mon.stats and mon.stats.hp) or mon.hp or 1) or 1
      local isFainted = not isEgg and (curHp <= 0)

      -- 1. Front Sprite Box
      local boxW = math.min(52, cardH - 8)
      local boxH = cardH - 8
      local boxX = 6
      local boxY = cy + 4
      Layout.drawSlot(boxX, boxY, boxW, boxH, {
        color = theme.surface,
        borderColor = isSel and theme.borderStrong or theme.border,
        radius = 6,
      })

      local spriteSpecies = isEgg and "EGG" or mon.species
      SpriteHelper.drawFrontPic(game.data, spriteSpecies, boxX, boxY, boxW, boxH, {
        mon = mon,
        isShiny = mon.isShiny,
        kind = "party",
      })

      local contentX = boxX + boxW + 8
      local name = isEgg and "POKéMON EGG" or (mon.displayName or mon.name or (mon.nickname and mon.nickname ~= "" and mon.nickname) or def.name or tostring(mon.species or "POKÉMON"))
      local nameColor = isFainted and theme.textDim or (isSel and theme.heading or theme.text)

      if isCompact then
        -- =====================================================================
        -- REFLOWED 2-ROW PORTRAIT MOBILE CARD
        -- =====================================================================
        local row1Y = cy + 5
        local row2Y = cy + cardH - 22

        -- Top Row Left: Name + Gender
        Layout.drawText(name, contentX, row1Y, { font = "headline", color = nameColor, bold = true })
        local isMale = (mon.gender == "M" or mon.gender == "MALE")
        local isFemale = (mon.gender == "F" or mon.gender == "FEMALE")
        if not isEgg and (isMale or isFemale) then
          local gColor = isMale and { 0.3, 0.6, 1.0, 1 } or { 1.0, 0.4, 0.6, 1 }
          Layout.drawText(isMale and "♂" or "♀", contentX + nameW + 4, row1Y, { font = "headline", color = gColor, bold = true })
        end

        -- Top Row Right: Badges (Level + Status/Able)
        local curBadgeX = w - 10
        if isEgg then
          local bWidth = 72
          curBadgeX = curBadgeX - bWidth
          Layout.drawBadge(curBadgeX, row1Y, "EGG", { kind = "accent", font = "tiny", width = bWidth })
        elseif isTM then
          local canLearn = false
          for _, m in ipairs(def.tmhm or {}) do
            if m == state.tmhm.move then canLearn = true break end
          end
          local bWidth = 60
          curBadgeX = curBadgeX - bWidth
          Layout.drawBadge(curBadgeX, row1Y, canLearn and "ABLE" or "NO", { kind = canLearn and "good" or "ghost", font = "tiny", width = bWidth })
        elseif isEvoStone then
          local canEvolve = false
          for _, evo in ipairs(def.evolutions or {}) do
            if evo.item == state.evoStone then canEvolve = true break end
          end
          local bWidth = 60
          curBadgeX = curBadgeX - bWidth
          Layout.drawBadge(curBadgeX, row1Y, canEvolve and "ABLE" or "NO", { kind = canEvolve and "good" or "ghost", font = "tiny", width = bWidth })
        else
          if isFainted then
            local bWidth = 38
            curBadgeX = curBadgeX - bWidth
            Layout.drawBadge(curBadgeX, row1Y, "FNT", { kind = "danger", font = "tiny", width = bWidth })
          elseif mon.status then
            local bWidth = 42
            curBadgeX = curBadgeX - bWidth
            Layout.drawBadge(curBadgeX, row1Y, tostring(mon.status):upper(), { kind = "warn", font = "tiny", width = bWidth })
          elseif mon.pokerus == "infected" then
            local bWidth = 42
            curBadgeX = curBadgeX - bWidth
            Layout.drawBadge(curBadgeX, row1Y, "PKRS", { kind = "danger", font = "tiny", width = bWidth })
          end

          local lvlWidth = 48
          curBadgeX = curBadgeX - lvlWidth - 4
          Layout.drawBadge(curBadgeX, row1Y, ("Lv.%d"):format(mon.level or 1), { kind = "ghost", font = "tiny", width = lvlWidth })
        end

        -- Bottom Row Left: Types / Egg Note
        if isEgg then
          Layout.drawText("INCUBATING", contentX, row2Y + 2, { font = "tiny", color = theme.accent, bold = true })
        else
          local uniqueTypes = Widgets.getUniqueTypes(mon.types or def.types)
          local tx = contentX
          for _, t in ipairs(uniqueTypes) do
            local bw = Widgets.drawTypeBadge(t, tx, row2Y)
            tx = tx + bw + 4
          end
          local held = mon.heldItem or mon.item
          if held and held ~= 0 and held ~= "" then
            Layout.drawBadge(tx + 4, row2Y, "ITEM", { kind = "ghost", font = "tiny", height = 18 })
          end
        end

        -- Bottom Row Right: HP Meter & Adaptive EXP Bar
        if not isEgg then
          local barW = math.min(120, math.floor(w * 0.36))
          local barX = w - barW - 10
          if cardH >= 48 then
            Layout.drawText(("HP %d/%d"):format(curHp, maxHp), barX, row2Y - 3, { font = "tiny", color = theme.textDim })
            Layout.drawHealthBar(barX, row2Y + 9, barW, 4, curHp, maxHp)
            local expRatio = getExpRatio(mon, def)
            local expColor = theme.colors.accent or { 0.25, 0.65, 0.95 }
            Layout.drawHealthBar(barX, row2Y + 16, barW, 2, math.floor(expRatio * 1000), 1000, {
              color = expColor,
              trackColor = theme.colors.surface or theme.colors.surfaceHigh,
            })
          else
            -- Cull EXP bar when vertical space is constrained on mobile portrait
            Layout.drawHealthBar(barX, row2Y + 12, barW, 4, curHp, maxHp)
            Layout.drawText(("HP %d/%d"):format(curHp, maxHp), barX, row2Y - 2, { font = "tiny", color = theme.textDim })
          end
        end
      else
        -- =====================================================================
        -- STANDARD LANDSCAPE / DESKTOP WIDE CARD
        -- =====================================================================
        local row1Y = cy + 6
        local row2Y = cy + cardH - 20

        Layout.drawText(name, contentX, row1Y, { font = "headline", color = nameColor, bold = true })
        local nameW = Layout.textWidth(name, "headline")
        local isMale = (mon.gender == "M" or mon.gender == "MALE")
        local isFemale = (mon.gender == "F" or mon.gender == "FEMALE")
        if not isEgg and (isMale or isFemale) then
          local gColor = isMale and { 0.3, 0.6, 1.0, 1 } or { 1.0, 0.4, 0.6, 1 }
          Layout.drawText(isMale and "♂" or "♀", contentX + nameW + 4, row1Y, { font = "headline", color = gColor, bold = true })
        end

        if not isEgg then
          local hasGender = isMale or isFemale
          local lvlX = contentX + nameW + (hasGender and 22 or 10)
          Layout.drawBadge(lvlX, row1Y + 1, ("Lv. %d"):format(mon.level or 1), { kind = "ghost", font = "tiny" })
          if mon.pokerus == "infected" then
            Layout.drawBadge(lvlX + 54, row1Y + 1, "PKRS", { kind = "danger", font = "tiny" })
          elseif mon.pokerus == "cured" then
            Layout.drawBadge(lvlX + 54, row1Y + 1, "●", { kind = "ghost", font = "tiny" })
          end
        else
          local eggTagX = contentX + nameW + 12
          Layout.drawBadge(eggTagX, row1Y + 1, "INCUBATING", { kind = "accent", font = "tiny" })
        end

        if isEgg then
          Layout.drawText("An odd POKéMON EGG found at Day-Care.", contentX, row2Y + 2, { font = "caption", color = theme.textDim })
        else
          local uniqueTypes = Widgets.getUniqueTypes(mon.types or def.types)
          local tx = contentX
          for _, t in ipairs(uniqueTypes) do
            local bw = Widgets.drawTypeBadge(t, tx, row2Y)
            tx = tx + bw + 4
          end
          local held = mon.heldItem or mon.item
          if held and held ~= 0 and held ~= "" then
            local heldName = tostring(held):gsub("_", " ")
            Layout.drawBadge(tx + 6, row2Y, heldName, { kind = "ghost", font = "tiny", height = 18 })
          end
        end

        local rightW = math.min(180, math.floor(w * 0.35))
        local rightX = w - rightW - 12

        if isEgg then
          Layout.drawBadge(rightX + rightW - 84, row1Y + 1, "EGG", { kind = "accent", font = "caption", width = 84 })
        elseif isTM then
          local canLearn = false
          for _, m in ipairs(def.tmhm or {}) do
            if m == state.tmhm.move then canLearn = true break end
          end
          local ableBadgeW = math.min(76, rightW - 10)
          Layout.drawBadge(rightX + rightW - ableBadgeW, row1Y + 1, canLearn and "ABLE" or "NOT ABLE", { kind = canLearn and "good" or "ghost", font = "caption", width = ableBadgeW })
        elseif isEvoStone then
          local canEvolve = false
          for _, evo in ipairs(def.evolutions or {}) do
            if evo.item == state.evoStone then canEvolve = true break end
          end
          local evoBadgeW = math.min(76, rightW - 10)
          Layout.drawBadge(rightX + rightW - evoBadgeW, row1Y + 1, canEvolve and "ABLE" or "NOT ABLE", { kind = canEvolve and "good" or "ghost", font = "caption", width = evoBadgeW })
        else
          if isFainted then
            Layout.drawBadge(rightX + rightW - 44, row1Y + 1, "FNT", { kind = "danger", font = "tiny" })
          elseif mon.status then
            Layout.drawBadge(rightX + rightW - 48, row1Y + 1, tostring(mon.status):upper(), { kind = "warn", font = "tiny" })
          end
        end

        if not isEgg then
          if cardH >= 46 then
            local hpBarY = row2Y - 2
            local expBarY = row2Y + 6
            local expRatio = getExpRatio(mon, def)
            local expColor = theme.colors.accent or { 0.25, 0.65, 0.95 }

            Layout.drawText(("HP %d/%d"):format(curHp, maxHp), rightX, hpBarY - 11, { font = "tiny", color = theme.textDim })
            Layout.drawHealthBar(rightX, hpBarY, rightW, 5, curHp, maxHp)
            Layout.drawHealthBar(rightX, expBarY, rightW, 3, math.floor(expRatio * 1000), 1000, {
              color = expColor,
              trackColor = theme.colors.surface or theme.colors.surfaceHigh,
            })
          else
            -- Cull EXP bar when vertical space is constrained
            Layout.drawHealthBar(rightX, row2Y, rightW, 5, curHp, maxHp)
            Layout.drawText(("HP %d/%d"):format(curHp, maxHp), rightX, row2Y - 12, { font = "tiny", color = theme.textDim })
          end
        end
      end
    else
      Layout.drawText("- - - EMPTY SLOT - - -", 20, cy + math.floor(cardH / 2) - 6, { font = "caption", color = theme.textMuted })
    end

    love.graphics.pop()
  end

  if isGen3Party then
    local barY = 50 + 6 * (cardH + 4)
    local barH = math.max(32, math.min(40, footY - barY - 4))
    if multiChoose then
      local gap = 8
      local bw = math.floor((w - gap) / 2)
      Layout.drawButton(0, barY, bw, barH, "CONFIRM", {
        kind = curIdx == 7 and "primary" or "ghost",
        selected = curIdx == 7,
      })
      Layout.drawButton(bw + gap, barY, w - bw - gap, barH, "CANCEL", {
        kind = curIdx == 8 and "primary" or "ghost",
        selected = curIdx == 8,
      })
    else
      Layout.drawButton(0, barY, w, barH, "CANCEL", {
        kind = curIdx == 7 and "primary" or "ghost",
        selected = curIdx == 7,
      })
    end
  end

  -- Bottom Hints Bar
  -- Bottom Hints Bar
  local isSubmenu = (state.submenu ~= nil and state.submenu ~= false)
      or (state.mode == "action" or state.mode == "item_action")
      or (subState ~= nil and subState ~= state and (subState.isSubmenu or (subState.items ~= nil and subState.items ~= state.items and subState.items ~= state.party)))

  -- 3. Interaction Submenu Floating Modal
  if isSubmenu then
    local subItems = (type(state.submenu) == "table" and state.submenu.items)
        or state.subItems
        or (state.mode == "item_action" and state.ITEM_ACTIONS)
        or (state.mode == "action" and state.ACTIONS)
        or (subState and subState ~= state and (subState.items or (type(subState.submenu) == "table" and subState.submenu.items)))

    -- Normalize string lists e.g. {"SUMMARY", "SWITCH", "ITEM", "CANCEL"}
    if type(subItems) == "table" and #subItems > 0 and type(subItems[1]) == "string" then
      local mapped = {}
      for _, s in ipairs(subItems) do
        mapped[#mapped + 1] = { label = s, action = s:lower() }
      end
      subItems = mapped
    end

    if not subItems or #subItems == 0 then
      local mon = party[curIdx]
      subItems = {}
      local isEgg = mon and (mon.isEgg == true or mon.species == "EGG" or mon.species == 253)
      if mon and not isEgg and mon.moves and not state.battle and game.overworld then
        local GEN2_FIELD_SET = {
          FLY = true, FLASH = true, CUT = true, SURF = true,
          STRENGTH = true, WATERFALL = true, WHIRLPOOL = true, HEADBUTT = true,
          ROCK_SMASH = true, DIG = true, TELEPORT = true, SOFTBOILED = true,
          MILK_DRINK = true, SWEET_SCENT = true,
        }
        for _, mv in ipairs(mon.moves) do
          local mid = type(mv) == "table" and (mv.id or mv.name) or tostring(mv)
          local uId = mid:upper()
          if GEN2_FIELD_SET[uId] then
            table.insert(subItems, { label = uId, action = uId:lower() })
          end
        end
      end
      table.insert(subItems, { label = "STATS", action = "stats" })
      table.insert(subItems, { label = "SWITCH", action = "switch" })
      table.insert(subItems, { label = "CANCEL", action = "cancel" })
    end

    local subCur = state.subIndex or state.subCursor
        or (state.mode == "item_action" and state.itemActionCursor)
        or (state.mode == "action" and state.actionCursor)
        or (type(state.submenu) == "table" and state.submenu.index)
        or (subState and (subState.index or subState.subIndex or (type(subState.submenu) == "table" and subState.submenu.index)))
        or 1

    -- Dimmed scrim backdrop for focus
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)

    local modalW = isCompact and math.min(w - 32, 280) or math.min(270, math.max(220, math.floor(w * 0.38)))
    local itemH = isCompact and 36 or 38
    local itemGap = 5
    local itemStride = itemH + itemGap
    local headerH = 42

    local selMon = party[curIdx]
    local monName = selMon and (selMon.nickname or (game.data and game.data.pokemon and game.data.pokemon[selMon.species] and game.data.pokemon[selMon.species].name) or selMon.species) or "POKÉMON"

    local maxModalH = h - 36
    local neededModalH = headerH + #subItems * itemStride + 14
    local isModalScrollable = (neededModalH > maxModalH)
    local visibleCount = #subItems
    local modalH = neededModalH

    if isModalScrollable then
      visibleCount = math.max(2, math.floor((maxModalH - headerH - 14) / itemStride))
      visibleCount = math.min(#subItems, visibleCount)
      modalH = headerH + visibleCount * itemStride + 14
    end

    local modalScroll = state.modalScroll or 1
    if subCur < modalScroll then
      modalScroll = subCur
    elseif subCur >= modalScroll + visibleCount then
      modalScroll = subCur - visibleCount + 1
    end
    modalScroll = math.max(1, math.min(math.max(1, #subItems - visibleCount + 1), modalScroll))
    state.modalScroll = modalScroll

    local modalX
    local modalY
    if isCompact then
      modalX = math.floor((w - modalW) / 2)
      modalY = math.max(16, math.floor((h - modalH) / 2))
    else
      local targetSlotY = 50 + (curIdx - 1) * (cardH + 4)
      modalX = math.min(w - modalW - 20, math.max(math.floor(w * 0.52), w - modalW - 24))
      modalY = math.max(20, math.min(h - modalH - 24, targetSlotY - 6))
    end

    -- Floating Modal Container Card
    Layout.drawCard(modalX, modalY, modalW, modalH, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    -- Modal Header
    Layout.drawText(monName, modalX + 16, modalY + 12, { font = "headline", color = theme.heading, bold = true })
    Layout.drawBadge(modalX + modalW - 74, modalY + 10, "ACTIONS", { kind = "accent", font = "tiny", width = 60 })
    Layout.drawDivider(modalX + 12, modalY + 36, modalW - 24, theme.border)

    -- Submenu Actions List
    local startY = modalY + headerH
    local btnW = isModalScrollable and (modalW - 28) or (modalW - 20)

    for vi = 1, visibleCount do
      local si = modalScroll + vi - 1
      local entry = subItems[si]
      if entry then
        local isSubSel = (subCur == si)
        local rawLabel = type(entry) == "table" and (entry.label or entry.name or entry.text or entry.action) or tostring(entry)
        local label = tostring(rawLabel):upper()
        local iy = startY + (vi - 1) * itemStride

        local isFieldMove = (entry.action == "fly" or entry.action == "surf" or entry.action == "cut"
            or entry.action == "flash" or entry.action == "strength" or entry.action == "softboiled"
            or entry.action == "teleport" or entry.action == "dig" or entry.move ~= nil
            or label == "CUT" or label == "FLY" or label == "SURF" or label == "STRENGTH"
            or label == "FLASH" or label == "ROCK SMASH" or label == "WATERFALL" or label == "DIVE"
            or label == "TELEPORT" or label == "DIG" or label == "SOFTBOILED" or label == "MILK DRINK")

        local btnKind = isSubSel and "primary" or "ghost"
        Layout.drawButton(modalX + 10, iy, btnW, itemH, label, {
          selected = isSubSel,
          align = "left",
          padX = 14,
          font = "button",
          kind = btnKind,
        })

        -- Informative Action Type Badges
        if isFieldMove then
          Layout.drawBadge(modalX + 10 + btnW - 46, iy + math.floor((itemH - 20) / 2), "FIELD", {
            kind = isSubSel and "good" or "accent",
            font = "tiny",
            height = 20,
            width = 40,
          })
        elseif entry.action == "stats" or label == "STATS" or label == "STATUS" or label == "SUMMARY" then
          Layout.drawBadge(modalX + 10 + btnW - 46, iy + math.floor((itemH - 20) / 2), "INFO", {
            kind = isSubSel and "team" or "ghost",
            font = "tiny",
            height = 20,
            width = 40,
          })
        elseif entry.action == "switch" or label == "SWITCH" or entry.action == "battle_switch" then
          Layout.drawBadge(modalX + 10 + btnW - 48, iy + math.floor((itemH - 20) / 2), "SWAP", {
            kind = isSubSel and "warn" or "ghost",
            font = "tiny",
            height = 20,
            width = 42,
          })
        end
      end
    end

    if isModalScrollable then
      Layout.drawScrollBar(modalX + modalW - 14, startY, 5, modalH - headerH - 12, #subItems, visibleCount, modalScroll, {
        is1Indexed = true,
        radius = 3,
      })
    end
  end

  local hints
  if isSubmenu then
    hints = {
      { key = "▲ ▼", label = "Select", primary = true },
      { key = "A", label = "Confirm", primary = true },
      { key = "B", label = "Cancel" },
    }
  else
    hints = {
      { key = "▲ ▼", label = "Select", primary = true },
      { key = "A", label = isTM and "Teach" or (isEvoStone and "Use" or "Actions") },
      { key = "B", label = "Back" },
    }
  end
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isCompact and 8 or 16, gap = isCompact and 14 or 20 })

  -- 4. Item Result / Level-Up Stat Box Overlay (e.g. Rare Candy, Potions, Status items)
  local itemRes = state and state.itemResult
  if itemRes then
    local rText = itemRes.text
    local isLevelUp = itemRes.level ~= nil or itemRes.leveledTo ~= nil
      or (type(rText) == "string" and (rText:lower():find("grew") ~= nil or rText:lower():find("level") ~= nil))
    local targetMon = (itemRes.slot and party[itemRes.slot]) or party[curIdx] or state.mon
    if isLevelUp and targetMon then
      local LevelUpStatRenderer = require("mods.omni_ui.renderers.LevelUpStatRenderer")
      LevelUpStatRenderer.draw(game, { mon = targetMon }, w, h, theme)
    elseif rText and rText ~= "" then
      local dw = math.min(w - 32, 600)
      local dh = 90
      local dx = math.floor((w - dw) / 2)
      local dy = h - dh - 42
      Layout.drawCard(dx, dy, dw, dh, {
        color = theme.surfaceHigh,
        borderColor = theme.borderStrong,
        borderWidth = 1.5,
        radius = 10,
      })
      Layout.drawTextWrapped(tostring(rText), dx + 16, dy + 16, dw - 32, {
        font = "headline",
        color = theme.heading,
        lineHeight = 1.3,
      })
    end
  end
end

return PartyRenderer
