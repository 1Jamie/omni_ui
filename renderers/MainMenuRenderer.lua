-- OmniUI Main Menu Renderer
-- 1:1 aligned with the Cartridge Studio launcher design:
-- Graphite cards, vector typography, 3-column save metrics, loaded badges, orientation adaptability, and vibrant green primary action keys.

local Layout = require("mods.omni_ui.core.Layout")
local Theme = require("mods.omni_ui.core.Theme")
local BaseAdapter = require("mods.omni_ui.adapters.BaseAdapter")

local MainMenuRenderer = {}

local function resolveMonName(pMon)
  if not pMon then return "MON" end
  local nick = pMon.nickname or pMon.name or pMon.displayName
  if nick and nick ~= "" and not tonumber(nick) then return tostring(nick) end
  local sp = pMon.species or pMon.speciesId
  if type(sp) == "number" then
    local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
    if okP and Pokemon and Pokemon.name then
      local n = Pokemon.name(sp)
      if n and n ~= "" then return tostring(n) end
    end
  end
  return tostring(nick or sp or "MON")
end

function MainMenuRenderer.draw(game, state, w, h, theme, subState)
  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait

  -- 1. Identify Game Version & Title
  local ver = (game and game.gameVersion) or (game and game.cart and game.cart.gameVersion)
  if not ver then
    local okV, GV = pcall(require, "src.core.GameVersion")
    if okV and GV and GV.get then ver = GV.get() end
  end
  ver = tostring(ver or "red"):lower()
  local verTitle = "Pokémon Red"
  if ver == "blue" then verTitle = "Pokémon Blue"
  elseif ver == "yellow" then verTitle = "Pokémon Yellow"
  elseif ver == "gold" then verTitle = "Pokémon Gold"
  elseif ver == "silver" then verTitle = "Pokémon Silver"
  elseif ver == "crystal" then verTitle = "Pokémon Crystal"
  elseif ver == "firered" then verTitle = "Pokémon FireRed"
  elseif ver == "leafgreen" then verTitle = "Pokémon LeafGreen"
  elseif ver == "emerald" then verTitle = "Pokémon Emerald"
  elseif ver == "ruby" then verTitle = "Pokémon Ruby"
  elseif ver == "sapphire" then verTitle = "Pokémon Sapphire"
  end

  -- 2. Extract Save Information
  local save = (subState and subState.save) or state.save or state.saveInfo
  if not save and state.continueInfo and state.continueInfo.save then
    save = state.continueInfo.save
  end
  if not save and subState and subState.continueInfo and subState.continueInfo.save then
    save = subState.continueInfo.save
  end
  if not save and state.__cachedSave then
    save = state.__cachedSave
  end
  if not save and state.items and state.items.__omniSave then
    save = state.items.__omniSave
  end
  if not save and state.list and state.list.items and state.list.items.__omniSave then
    save = state.list.items.__omniSave
  end
  if not save and game and game.__omniTitleSave then
    save = game.__omniTitleSave
  end
  if not save and game and game.save then
    save = game.save
  end

  if not save and game and game.stack and game.stack.states then
    for _, s in ipairs(game.stack.states) do
      if s.save and type(s.save) == "table" and s.save ~= (game and game.save) then
        save = s.save
        break
      elseif s.continueInfo and s.continueInfo.save then
        save = s.continueInfo.save
        break
      elseif s.items and s.items.__omniSave then
        save = s.items.__omniSave
        break
      elseif s.list and s.list.items and s.list.items.__omniSave then
        save = s.list.items.__omniSave
        break
      end
    end
  end

  -- If save is missing or missing party data (e.g. FRLG continue screen where continueInfo only holds header stats),
  -- load the full save file to populate active party and full dex records.
  if not save or not save.party or #save.party == 0 then
    local loadedSave = nil
    local okKit, Kit = pcall(require, "src.ui.game3.rse.scene_kit")
    if okKit and Kit and Kit.loadRawSave then
      local okRaw, raw = pcall(Kit.loadRawSave)
      if okRaw and raw and type(raw) == "table" and raw.party and #raw.party > 0 then
        loadedSave = raw
      end
    end
    if not loadedSave then
      local okS, SD = pcall(require, "src.core.SaveData")
      if okS and SD and SD.load then
        local okGV, GV = pcall(require, "src.core.GameVersion")
        local activeVer = (okGV and GV and GV.get and GV.get()) or ver
        local okL2, loaded2 = pcall(SD.load, activeVer)
        if okL2 and loaded2 and type(loaded2) == "table" and loaded2.party and #loaded2.party > 0 then
          loadedSave = loaded2
        end
        if not loadedSave then
          local okL, loaded = pcall(SD.load)
          if okL and loaded and type(loaded) == "table" and loaded.party and #loaded.party > 0 then
            loadedSave = loaded
          end
        end
      end
    end
    if not loadedSave then
      local okG2S, G2Save = pcall(require, "src.core.gen2.Save")
      if okG2S and G2Save and G2Save.load then
        local okL, loaded = pcall(G2Save.load)
        if okL and loaded and type(loaded) == "table" and loaded.party and #loaded.party > 0 then
          loadedSave = loaded
        end
      end
    end

    if loadedSave then
      if save and type(save) == "table" then
        for k, v in pairs(loadedSave) do
          if save[k] == nil then save[k] = v end
        end
        if not save.party or #save.party == 0 then save.party = loadedSave.party end
        if not save.pokedex then save.pokedex = loadedSave.pokedex end
      else
        save = loadedSave
      end
    end
  end

  if not save and state.continueInfo then
    save = state.continueInfo
  end
  if not save and subState and subState.continueInfo then
    save = subState.continueInfo
  end

  if save and not state.__cachedSave then
    state.__cachedSave = save
  end

  local hasSave = (state.hasSave ~= nil and state.hasSave)
      or (state.hasContinue ~= nil and state.hasContinue)
      or (state.continueInfo ~= nil)
      or (save and (save.player or save.playerName or (save.party and #save.party > 0)))
  local player = save and (save.player or save) or {}
  local playerName = player.name or (save and save.playerName) or "GOLD"
  local badgesCount = BaseAdapter.resolveBadgeCount(save, game)

  local pokedexCount = 0
  if save and save.pokedex then
    local ownedTbl = save.pokedex.owned or save.pokedex.caught or {}
    if type(ownedTbl) == "number" then
      pokedexCount = ownedTbl
    elseif type(ownedTbl) == "table" then
      for _ in pairs(ownedTbl) do pokedexCount = pokedexCount + 1 end
    end
  end
  if pokedexCount == 0 and save and save.pokedexCount then
    pokedexCount = tonumber(save.pokedexCount) or 0
  end

  local playTime = (save and (save.playTime or save.time or (save.player and save.player.playTime))) or 0
  local playTimeString = "0:00"
  if type(playTime) == "number" then
    local ph = math.floor(playTime / 3600)
    local pm = math.floor((playTime % 3600) / 60)
    playTimeString = ("%d:%02d"):format(ph, pm)
  elseif type(playTime) == "table" then
    local ph = playTime.hours or playTime.h or 0
    local pm = playTime.minutes or playTime.m or 0
    playTimeString = ("%d:%02d"):format(ph, pm)
  end

  local info = (state and state.info) or (subState and subState.info) or (state and state.continueInfo) or (subState and subState.continueInfo)
  if info and type(info) == "table" then
    if info.name and info.name ~= "" then playerName = tostring(info.name) end
    if info.badges ~= nil then badgesCount = tonumber(info.badges) or badgesCount end
    if info.dexCount ~= nil then pokedexCount = tonumber(info.dexCount) or pokedexCount end
    if info.hours ~= nil or info.minutes ~= nil then
      playTimeString = ("%d:%02d"):format(tonumber(info.hours) or 0, tonumber(info.minutes) or 0)
    end
    if state.hasContinue or info.name ~= nil then hasSave = true end
  end

  local party = (save and save.party) or {}
  if #party == 0 and save and save.activeParty then
    party = save.activeParty
  end

  -- Modal child states
  local isContinuePrompt = (subState and (subState.save or (subState.titleUiBox and subState.title))) ~= nil
  local isConfirm = false
  local confirmChoice = 1
  if (state.phase == "confirm") or (subState and subState.phase == "confirm") then
    isConfirm = true
    confirmChoice = state.confirmChoice or (subState and subState.confirmChoice) or 1
  elseif subState and (subState.labels or subState.onChoose or subState.pending ~= nil or subState.isChoiceBox or isContinuePrompt) then
    isConfirm = true
    confirmChoice = subState.confirmChoice or subState.index or 1
  elseif state._confirming or state.isConfirm or (state.choice and state.choice.labels) then
    isConfirm = true
    confirmChoice = (state.choice and (state.choice.confirmChoice or state.choice.index)) or state.confirmChoice or state.index or 1
  end

  -- Top Brand Header
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText(verTitle, 18, 11, { font = "title", color = theme.heading, bold = true })
  Layout.drawBadge(Layout.textWidth(verTitle, "title") + 28, 12, "Ready", { kind = "ready" })
  Layout.drawText("MAIN MENU", w - 110, 15, { font = "caption", color = theme.textDim })

  local items = state.items or state.entries or (state.list and state.list.items)

  if not items or #items == 0 then
    if type(state.menuItems) == "function" then
      local okM, m = pcall(state.menuItems, state)
      if okM and m and #m > 0 then items = m end
    elseif type(state.menuItems) == "table" and #state.menuItems > 0 then
      items = state.menuItems
    end
  end

  if not items or #items == 0 then
    local Boot = package.loaded["src.ui.game3.boot"]
    if Boot and Boot.menuItems and (state.phase == "menu" or state.menuIndex ~= nil) then
      local okM, m = pcall(Boot.menuItems, state)
      if okM and m and #m > 0 then items = m end
    end
  end

  if (not items or #items == 0) and game and game.stack and game.stack.states then
    for _, s in ipairs(game.stack.states) do
      if s.items and type(s.items) == "table" and #s.items > 0 then
        items = s.items
        break
      elseif s.entries and type(s.entries) == "table" and #s.entries > 0 then
        items = s.entries
        break
      elseif s.list and type(s.list.items) == "table" and #s.list.items > 0 then
        items = s.list.items
        break
      end
    end
  end

  if not items or #items == 0 then
    if state.menuIndex ~= nil or state.phase == "menu" or ver == "firered" or ver == "leafgreen" then
      local canCont = state.hasContinue
      if canCont == nil then canCont = hasSave end
      if canCont then
        items = { "CONTINUE", "NEW GAME", "MYSTERY GIFT", "EXIT" }
      else
        items = { "NEW GAME", "EXIT" }
      end
    end
  end

  items = items or {}
  local curIdx = isConfirm and 1 or (state.menuIndex or (subState and subState.menuIndex) or state.index or state.cursor or (subState and (subState.index or subState.cursor)) or (state.list and state.list.index) or 1)
  if #items > 0 then
    curIdx = math.max(1, math.min(#items, curIdx))
  end
  local footY = h - 38

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE STACKED ACTION BUTTONS + FULL-WIDTH HERO PREVIEW
    -- =========================================================================
    local btnCount = math.max(1, #items)
    local btnH = 34
    local btnGap = 4
    local btnsH = btnCount * (btnH + btnGap) + 8
    Layout.drawCard(0, 48, w, btnsH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    for i, it in ipairs(items) do
      local isSel = (curIdx == i)
      local rawLabel = tostring(it.label or it.name or it.value or it or ""):upper():gsub("<[^>]+>", "")
      local displayLabel = it.label or it.name or it.value or rawLabel
      local iy = 52 + (i - 1) * (btnH + btnGap)

      if isSel then
        Layout.drawCard(6, iy, w - 12, btnH, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 6,
        })
        Layout.drawText("▶ " .. displayLabel, 14, iy + 8, { font = "button", color = theme.heading, bold = true })
      else
        Layout.drawSlot(6, iy, w - 12, btnH, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 6,
        })
        Layout.drawText("  " .. displayLabel, 14, iy + 8, { font = "button", color = theme.text })
      end
    end

    -- Full-Width Save / Feature Preview Card
    local previewY = 48 + btnsH + 6
    local previewH = footY - previewY - 6
    Layout.drawCard(0, previewY, w, previewH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = items[curIdx]
    local curRaw = tostring(curItem and (curItem.label or curItem.name or curItem.value or curItem) or ""):upper()

    if curRaw:find("CONTINUE") or isConfirm or (#items > 0 and curIdx == 1 and hasSave) then
      Layout.drawText("SAVE FILE", 14, previewY + 8, { font = "caption", color = theme.heading, bold = true })
      Layout.drawBadge(w - 76, previewY + 6, "LOADED", { kind = "loaded", font = "tiny" })

      -- Metrics row (Badges, Played, Caught)
      local metricY = previewY + 28
      local metricW = math.floor((w - 28) / 3)
      Layout.drawStatMetric(14, metricY, metricW, badgesCount, "badges")
      Layout.drawStatMetric(14 + metricW, metricY, metricW, playTimeString, "played")
      Layout.drawStatMetric(14 + metricW * 2, metricY, metricW, pokedexCount, "caught")

      Layout.drawDivider(14, previewY + 74, w - 28)

      -- Active Party: 2 rows of 3 columns
      Layout.drawText("ACTIVE PARTY (" .. tostring(#party) .. "/6)", 14, previewY + 80, { font = "tiny", color = theme.textDim, bold = true })

      if #party == 0 then
        Layout.drawText("No Pokémon in active party.", 14, previewY + 98, { font = "tiny", color = theme.textDim })
      else
        local colCount = 3
        local cellW = math.floor((w - 28 - (colCount - 1) * 6) / colCount)
        local cellH = 36
        for pi = 1, math.min(#party, 6) do
          local pMon = party[pi]
          local col = (pi - 1) % colCount
          local row = math.floor((pi - 1) / colCount)
          local px = 14 + col * (cellW + 6)
          local py = previewY + 98 + row * (cellH + 4)

          local pNick = resolveMonName(pMon)
          local pLvl = tonumber(pMon.level or 1)
          local curHp = tonumber(pMon.hp or (pMon.stats and pMon.stats.hp) or 0)
          local maxHp = tonumber(pMon.maxHp or (pMon.stats and pMon.stats.hp) or 1)

          Layout.drawSlot(px, py, cellW, cellH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 4 })
          Layout.drawText(pNick:sub(1, 8), px + 4, py + 3, { font = "tiny", color = theme.heading, bold = true, width = cellW - 8 })
          Layout.drawText(("Lv.%d"):format(pLvl), px + cellW - 32, py + 3, { font = "tiny", color = theme.textDim })
          Layout.drawHealthBar(px + 4, py + 22, cellW - 8, 4, curHp, maxHp)
        end
      end
    elseif curRaw:find("NEW") then
      Layout.drawText("NEW ADVENTURE", 14, previewY + 8, { font = "headline", color = theme.heading, bold = true })
      local featY = previewY + 36
      local features = {
        "1. Explore the vibrant region of Kanto",
        "2. Catch wild species and build your team",
        "3. Defeat 8 Gym Leaders & conquer the League",
      }
      for _, feat in ipairs(features) do
        Layout.drawSlot(10, featY, w - 20, 28, { color = theme.surfaceHigh, borderColor = theme.border, radius = 5 })
        Layout.drawText(feat, 16, featY + 6, { font = "tiny", color = theme.textDim })
        featY = featY + 34
      end
    elseif curRaw:find("EXIT") or curRaw:find("QUIT") then
      Layout.drawText("EXIT GAME", 14, previewY + 8, { font = "headline", color = theme.heading, bold = true })
      Layout.drawTextWrapped("Exit this game and return to the launcher.", 14, previewY + 36, w - 28, { font = "caption", color = theme.textDim })
    elseif curRaw:find("MOD") then
      Layout.drawText("MOD MANAGER", 14, previewY + 8, { font = "headline", color = theme.heading, bold = true })
      Layout.drawTextWrapped("Manage community add-ons, runtime profiles, and developer tools.", 14, previewY + 36, w - 28, { font = "caption", color = theme.textDim })
    elseif curRaw:find("MYSTERY") then
      Layout.drawText("MYSTERY EVENT", 14, previewY + 8, { font = "headline", color = theme.heading, bold = true })
      Layout.drawTextWrapped("Receive special mystery gifts and wonder card distributions.", 14, previewY + 36, w - 28, { font = "caption", color = theme.textDim })
    else
      local itemLabel = tostring(curItem and (curItem.label or curItem.name or curItem.value or curItem) or "OPTIONS")
      Layout.drawText(itemLabel:upper(), 14, previewY + 8, { font = "headline", color = theme.heading, bold = true })
      Layout.drawTextWrapped("Configure sound effects, music levels, visual themes, battle animations, and controls.", 14, previewY + 36, w - 28, { font = "caption", color = theme.textDim })
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANEL LAYOUT
    -- =========================================================================
    local colW = math.floor(w * 0.38)
    local panelH = h - 56

    -- Left Actions Navigation Card
    Layout.drawCard(0, 52, colW, panelH, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("SELECT ADVENTURE", 16, 64, { font = "caption", color = theme.textDim, bold = true })

    for i, it in ipairs(items) do
      local isSel = (curIdx == i)
      local rawLabel = tostring(it.label or it.name or it.value or it or ""):upper():gsub("<[^>]+>", "")
      local displayLabel = it.label or it.name or it.value or rawLabel
      local desc = "Select option"

      if rawLabel:find("CONTINUE") then
        desc = "Resume saved adventure"
      elseif rawLabel:find("NEW") then
        desc = "Begin a fresh journey"
      elseif rawLabel:find("OPTION") then
        desc = "Game settings and themes"
      elseif rawLabel:find("MOD") then
        desc = "Manage add-ons and profiles"
      elseif rawLabel:find("MYSTERY") then
        desc = "Special event distribution"
      elseif rawLabel:find("EXIT") or rawLabel:find("QUIT") then
        desc = "Exit this game back to the launcher"
      end

      local iy = 88 + (i - 1) * 56
      if isSel then
        Layout.drawCard(8, iy, colW - 16, 50, {
          color = theme.accentDark,
          borderColor = theme.borderStrong,
          borderWidth = 2,
          radius = 8,
        })
        Layout.drawText(displayLabel, 20, iy + 8, { font = "headline", color = theme.heading, bold = true })
        Layout.drawText(desc, 20, iy + 28, { font = "caption", color = theme.heading })
      else
        Layout.drawSlot(8, iy, colW - 16, 50, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 8,
        })
        Layout.drawText(displayLabel, 20, iy + 8, { font = "headline", color = theme.text })
        Layout.drawText(desc, 20, iy + 28, { font = "caption", color = theme.textDim })
      end
    end

    -- Right Hero Details Column
    local rightX = colW + 12
    local rightW = w - rightX
    Layout.drawCard(rightX, 52, rightW, panelH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local curItem = items[curIdx]
    local curRaw = tostring(curItem and (curItem.label or curItem.name or curItem.value or curItem) or ""):upper()
    local footerY = panelH + 52 - 46

    if curRaw:find("CONTINUE") or isConfirm or (#items > 0 and curIdx == 1 and hasSave) then
      Layout.drawText("SAVE", rightX + 16, 66, { font = "headline", color = theme.heading, bold = true })

      local slotY = 96
      local slotH = 180
      Layout.drawSlot(rightX + 12, slotY, rightW - 24, slotH, {
        color = theme.surfaceHigh,
        borderColor = isConfirm and theme.hpGreen or theme.border,
        borderWidth = 1,
        radius = 8,
      })

      Layout.drawText(playerName, rightX + 24, slotY + 12, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(rightX + rightW - 96, slotY + 12, "LOADED", { kind = "loaded" })

      local metricY = slotY + 44
      local metricW = math.floor((rightW - 48) / 3)
      Layout.drawStatMetric(rightX + 24, metricY, metricW, badgesCount, "badges")
      Layout.drawStatMetric(rightX + 24 + metricW, metricY, metricW, playTimeString, "played")
      Layout.drawStatMetric(rightX + 24 + metricW * 2, metricY, metricW, pokedexCount, "caught")

      Layout.drawDivider(rightX + 24, slotY + 104, rightW - 60)
      Layout.drawText("ACTIVE PARTY (" .. tostring(#party) .. "/6)", rightX + 24, slotY + 112, { font = "caption", color = theme.textDim, bold = true })

      if #party == 0 then
        Layout.drawText("No Pokémon in active party.", rightX + 24, slotY + 134, { font = "body", color = theme.textDim })
      else
        local pGridW = math.floor((rightW - 56) / math.min(math.max(#party, 1), 6))
        for pi = 1, math.min(#party, 6) do
          local pMon = party[pi]
          local px = rightX + 24 + (pi - 1) * pGridW
          local py = slotY + 132

          local pNick = resolveMonName(pMon)
          local pLvl = tonumber(pMon.level or 1)
          Layout.drawText(pNick:sub(1, 8), px, py, { font = "caption", color = theme.heading, bold = true })
          Layout.drawText(("Lv. %d"):format(pLvl), px, py + 16, { font = "tiny", color = theme.textDim })

          local curHp = tonumber(pMon.hp or (pMon.stats and pMon.stats.hp) or 0)
          local maxHp = tonumber(pMon.maxHp or (pMon.stats and pMon.stats.hp) or 1)
          Layout.drawHealthBar(px, py + 30, pGridW - 8, 4, curHp, maxHp)
        end
      end

      local subSlotY = slotY + slotH + 12
      Layout.drawSlot(rightX + 12, subSlotY, rightW - 24, 48, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
      Layout.drawText("READY TO RESUME", rightX + 24, subSlotY + 10, { font = "caption", color = theme.hpGreen, bold = true })
      Layout.drawText("Press [A] to resume your saved journey where you left off.", rightX + 24, subSlotY + 28, { font = "tiny", color = theme.textDim })

    elseif curRaw:find("NEW") then
      Layout.drawText("NEW ADVENTURE", rightX + 16, 66, { font = "headline", color = theme.heading, bold = true })

      local featureY = 96
      local features = {
        {
          title = "1. Explore the Kanto Region",
          desc = "Travel across vibrant towns, routes, forests, and caves.",
        },
        {
          title = "2. Catch & Train Pokémon",
          desc = "Encounter wild species, build your team, and fill the Pokédex.",
        },
        {
          title = "3. Challenge Gym Leaders",
          desc = "Defeat all 8 Gym Leaders and conquer the Pokémon League.",
        },
      }

      local maxTextW = rightW - 48
      for _, feat in ipairs(features) do
        Layout.drawSlot(rightX + 12, featureY, rightW - 24, 68, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 8,
        })
        Layout.drawText(feat.title, rightX + 24, featureY + 12, { font = "headline", color = theme.heading, bold = true })
        Layout.drawTextWrapped(feat.desc, rightX + 24, featureY + 36, maxTextW, { font = "caption", color = theme.textDim })
        featureY = featureY + 78
      end

    elseif curRaw:find("EXIT") or curRaw:find("QUIT") then
      local itemLabel = tostring(curItem and (curItem.label or curItem.name or curItem.value or curItem) or "EXIT GAME")
      Layout.drawText(itemLabel:upper(), rightX + 16, 66, { font = "headline", color = theme.heading, bold = true })

      local maxTextW = rightW - 48
      Layout.drawSlot(rightX + 12, 96, rightW - 24, 110, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
      Layout.drawText("Return to Launcher", rightX + 24, 110, { font = "headline", color = theme.heading, bold = true })
      Layout.drawTextWrapped("Exit this game back to the launcher.", rightX + 24, 136, maxTextW, { font = "caption", color = theme.textDim })

      Layout.drawSlot(rightX + 12, 218, rightW - 24, 52, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
      Layout.drawText("PRESS [ A ] TO EXIT", rightX + 24, 228, { font = "caption", color = theme.hpRed or theme.accent, bold = true })
      Layout.drawText("Close the current game session and return to the launcher.", rightX + 24, 246, { font = "tiny", color = theme.textDim })

    elseif curRaw:find("MOD") then
      local itemLabel = tostring(curItem and (curItem.label or curItem.name or curItem.value or curItem) or "MOD MANAGER")
      Layout.drawText(itemLabel:upper(), rightX + 16, 66, { font = "headline", color = theme.heading, bold = true })

      local maxTextW = rightW - 48
      Layout.drawSlot(rightX + 12, 96, rightW - 24, 110, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
      Layout.drawText("Mods & Profiles", rightX + 24, 110, { font = "headline", color = theme.heading, bold = true })
      Layout.drawTextWrapped("Manage enabled mods, view active profiles, and inspect mod errors.", rightX + 24, 136, maxTextW, { font = "caption", color = theme.textDim })

      Layout.drawSlot(rightX + 12, 218, rightW - 24, 52, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
      Layout.drawText("PRESS [ A ] TO MANAGE", rightX + 24, 228, { font = "caption", color = theme.accent, bold = true })
      Layout.drawText("Open mod manager to configure active add-ons.", rightX + 24, 246, { font = "tiny", color = theme.textDim })

    elseif curRaw:find("MYSTERY") then
      local itemLabel = tostring(curItem and (curItem.label or curItem.name or curItem.value or curItem) or "MYSTERY EVENT")
      Layout.drawText(itemLabel:upper(), rightX + 16, 66, { font = "headline", color = theme.heading, bold = true })

      local maxTextW = rightW - 48
      Layout.drawSlot(rightX + 12, 96, rightW - 24, 110, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
      Layout.drawText("Special Distributions", rightX + 24, 110, { font = "headline", color = theme.heading, bold = true })
      Layout.drawTextWrapped("Receive special event distributions and wonder card gifts.", rightX + 24, 136, maxTextW, { font = "caption", color = theme.textDim })

      Layout.drawSlot(rightX + 12, 218, rightW - 24, 52, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
      Layout.drawText("PRESS [ A ] TO RECEIVE", rightX + 24, 228, { font = "caption", color = theme.accent, bold = true })
      Layout.drawText("Connect to mystery distribution services.", rightX + 24, 246, { font = "tiny", color = theme.textDim })

    else
      local itemLabel = tostring(curItem and (curItem.label or curItem.name or curItem.value or curItem) or "OPTIONS")
      Layout.drawText(itemLabel:upper(), rightX + 16, 66, { font = "headline", color = theme.heading, bold = true })

      local maxTextW = rightW - 48
      Layout.drawSlot(rightX + 12, 96, rightW - 24, 110, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
      Layout.drawText("Settings & Customization", rightX + 24, 110, { font = "headline", color = theme.heading, bold = true })
      Layout.drawTextWrapped("Configure sound effects, music levels, visual themes, battle animations, and controls to your preference.", rightX + 24, 136, maxTextW, { font = "caption", color = theme.textDim })

      Layout.drawSlot(rightX + 12, 218, rightW - 24, 52, {
        color = theme.surfaceHigh,
        borderColor = theme.border,
        borderWidth = 1,
        radius = 8,
      })
      Layout.drawText("PRESS [ A ] TO CONFIGURE", rightX + 24, 228, { font = "caption", color = theme.accent, bold = true })
      Layout.drawText("Open options to adjust all in-game parameters.", rightX + 24, 246, { font = "tiny", color = theme.textDim })
    end
  end

  -- Bottom Button Hints Footer Bar
  local hints = {
    { key = "A", label = "Select", primary = true },
    { key = "▲ ▼", label = "Navigate" },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })

  -- Modal Confirm Dialog
  if isConfirm then
    local mw = math.min(w - 24, 340)
    local mh = 148
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", -100, -100, w + 200, h + 200)

    Layout.drawCard(mx, my, mw, mh, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      borderWidth = 2,
      radius = 10,
    })

    Layout.drawText("Resume Saved Adventure", mx + 24, my + 18, { font = "headline", color = theme.heading, bold = true })
    Layout.drawText("Continue your journey with " .. playerName .. "?", mx + 24, my + 48, { font = "body", color = theme.textDim })

    local btnW = math.floor((mw - 64) / 2)
    local btnH = 40
    local btnY = my + 88
    local yesX = mx + 24
    local noX = mx + 24 + btnW + 16

    Layout.drawButton(yesX, btnY, btnW, btnH, "Yes", {
      kind = (confirmChoice == 1) and "primary" or "ghost",
      selected = (confirmChoice == 1),
    })

    Layout.drawButton(noX, btnY, btnW, btnH, "No", {
      kind = (confirmChoice == 2) and "primary" or "ghost",
      selected = (confirmChoice == 2),
    })
  end
end

return MainMenuRenderer
