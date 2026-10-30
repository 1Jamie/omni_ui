-- OmniUI PokéNav Modern Renderer (Gen 3 RSE)
-- Multifunction companion navigator featuring Hoenn Map, Match Call / Trainer's Eyes,
-- Contest Condition Radar, and Ribbons Showcase.
-- Implements responsive layouts, progressive tab gating, and two-tier modal navigation.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local TownMapRenderer = require("mods.omni_ui.renderers.TownMapRenderer")
local SpriteHelper = require("mods.omni_ui.core.SpriteHelper")

local PokenavRenderer = {}

-- -----------------------------------------------------------------------------
-- Card Metadata & Colors
-- -----------------------------------------------------------------------------

local CARD_METADATA = {
  map = {
    id = "map",
    label = "HOENN MAP",
    tag = "MAP",
    color = { 0.30, 0.85, 0.45, 1.0 },
    desc = "Regional Hoenn Navigation & Fly",
  },
  call = {
    id = "call",
    label = "MATCH CALL",
    tag = "CALL",
    color = { 0.20, 0.70, 0.90, 1.0 },
    desc = "Trainer Directory & Rematches",
  },
  eyes = {
    id = "eyes",
    label = "TRAINER'S EYE",
    tag = "EYE",
    color = { 0.20, 0.70, 0.90, 1.0 },
    desc = "Trainer Dossier & Strategies",
  },
  condition = {
    id = "condition",
    label = "CONDITION",
    tag = "COND",
    color = { 0.85, 0.40, 0.90, 1.0 },
    desc = "Contest Category Radar Chart",
  },
  ribbons = {
    id = "ribbons",
    label = "RIBBONS",
    tag = "RIB",
    color = { 0.95, 0.70, 0.20, 1.0 },
    desc = "Champion & Contest Accolades",
  },
}

-- -----------------------------------------------------------------------------
-- Progressive Tab Discovery & Gating
-- -----------------------------------------------------------------------------

local function getSession(game, state)
  return (state and state.session)
    or (state and state.shell and state.shell.session)
    or (game and game.session)
    or (package.loaded["src.core.game3.runtime"] and package.loaded["src.core.game3.runtime"]._session)
    or {}
end

local function isRubySapphire(session)
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if ok and GameVersion and GameVersion.isRubySapphire then
    return GameVersion.isRubySapphire()
  end
  return false
end

local function checkFlag(session, name)
  local okRematch, Rematch = pcall(require, "src.core.game3.rse.rematch")
  if okRematch and Rematch and Rematch.flag then
    local ok, res = pcall(Rematch.flag, session, name)
    if ok then return res == true end
  end
  local f = session and session.flags
  if f and f[name] ~= nil then return f[name] == true or f[name] == 1 end
  return false
end

function PokenavRenderer.getAvailableCards(game, state)
  local session = getSession(game, state)
  local cards = {}

  -- 1. Hoenn Regional Map (Always Available upon receiving PokéNav)
  cards[#cards + 1] = CARD_METADATA.map

  -- 2. Match Call (Emerald) vs Trainer's Eye (Ruby/Sapphire)
  -- Gated by FLAG_ADDED_MATCH_CALL_TO_POKENAV (received from Mr. Stone / Rustboro Exit)
  local matchCallUnlocked = checkFlag(session, "FLAG_ADDED_MATCH_CALL_TO_POKENAV")
    or (state and state.matchCallUnlocked == true)
  if matchCallUnlocked or (state and state.card == "call") or (state and state.card == "eyes") then
    if isRubySapphire(session) then
      cards[#cards + 1] = CARD_METADATA.eyes
    else
      cards[#cards + 1] = CARD_METADATA.call
    end
  end

  -- 3. Condition Radar
  cards[#cards + 1] = CARD_METADATA.condition

  -- 4. Ribbons Showcase (Gated by FLAG_SYS_RIBBON_GET or party/PC ribbon presence)
  local ribbonsUnlocked = checkFlag(session, "FLAG_SYS_RIBBON_GET")
    or (state and state.ribbonsUnlocked == true)
  if not ribbonsUnlocked then
    local okRib, Ribbons = pcall(require, "src.core.game3.rse.ribbons")
    if okRib and Ribbons and Ribbons.anyMonHasRibbon then
      local ok, anyR = pcall(Ribbons.anyMonHasRibbon, session)
      if ok and anyR then ribbonsUnlocked = true end
    end
  end
  if ribbonsUnlocked or (state and state.card == "ribbons") then
    cards[#cards + 1] = CARD_METADATA.ribbons
  end

  return cards
end

-- -----------------------------------------------------------------------------
-- Helpers: Safe Mon & Contact Info
-- -----------------------------------------------------------------------------

local function getMonName(mon)
  if not mon then return "POKÉMON" end
  if mon.nickname and mon.nickname ~= "" then return tostring(mon.nickname):upper() end
  local okPk, Pokemon = pcall(require, "src.core.game3.pokemon")
  if okPk and Pokemon and Pokemon.speciesOf then
    local sp = Pokemon.speciesOf(mon) or 1
    if Pokemon.name then
      local okN, name = pcall(Pokemon.name, sp)
      if okN and name and name ~= "" then return tostring(name):upper() end
    end
  end
  return "POKÉMON"
end

local function getContactInfo(session, c)
  local desc, name = "TRAINER", "TRAINER"
  local isRematch = false
  local okMC, MatchCall = pcall(require, "src.core.game3.rse.match_call")
  if okMC and MatchCall then
    if MatchCall.headerNameAndDesc then
      local okH, d, n = pcall(MatchCall.headerNameAndDesc, c and c.headerId)
      if okH and n then
        desc, name = d or desc, n
      end
    end
    if MatchCall.headerIsRematchable then
      local okR, rem = pcall(MatchCall.headerIsRematchable, session, c and c.headerId)
      if okR and rem ~= nil then
        isRematch = rem == true
      end
    end
  end
  return desc, name, isRematch
end

-- -----------------------------------------------------------------------------
-- Card 2: Match Call & Trainer's Eyes
-- -----------------------------------------------------------------------------

local function getMatchCallList(session)
  local okMC, MatchCall = pcall(require, "src.core.game3.rse.match_call")
  if okMC and MatchCall and MatchCall.buildList then
    local ok, list = pcall(MatchCall.buildList, session)
    if ok and type(list) == "table" then return list end
  end
  return {}
end

local function drawMatchCallCard(game, state, x, y, w, h, theme, isNarrow)
  local session = getSession(game, state)
  local contacts = state._matchCallList
  if not contacts then
    contacts = getMatchCallList(session)
    state._matchCallList = contacts
  end

  local okMapsec, Mapsec = pcall(require, "src.ui.game3.rse.mapsec")

  if #contacts == 0 then
    Layout.drawCard(x, y, w, h, { color = theme.surface, borderColor = theme.border, radius = 8 })
    local emptySlotW = math.min(w - 32, 420)
    local emptySlotH = 140
    local ex = x + math.floor((w - emptySlotW) / 2)
    local ey = y + math.floor((h - emptySlotH) / 2)
    Layout.drawSlot(ex, ey, emptySlotW, emptySlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
    Layout.drawText("NO CONTACTS REGISTERED", ex + 24, ey + 24, { font = "headline", color = theme.colors.accent, bold = true })
    Layout.drawTextWrapped(
      "You have not registered any trainers or Gym Leaders in the Match Call directory yet. Battle trainers in the field to register their numbers.",
      ex + 24, ey + 54, emptySlotW - 48, { font = "body", color = theme.textDim }
    )
    return
  end

  state.contactSel = math.max(1, math.min(#contacts, state.contactSel or 1))
  local curContact = contacts[state.contactSel]

  if isNarrow then
    -- Portrait layout: full-width contacts list with modal call view
    local listH = h
    Layout.drawCard(x, y, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })
    local rowH = 38
    local gap = 6
    local visibleRows = math.max(1, math.floor((listH - 24) / (rowH + gap)))
    local scroll = math.max(0, math.min(#contacts - visibleRows, state.contactSel - math.floor(visibleRows / 2)))
    local itemW = (#contacts > visibleRows) and (w - 32) or (w - 20)

    for r = 1, visibleRows do
      local idx = scroll + r
      local c = contacts[idx]
      if c then
        local iy = y + 12 + (r - 1) * (rowH + gap)
        local isSel = (idx == state.contactSel)
        local desc, name, isRematch = getContactInfo(session, c)

        Layout.drawSlot(x + 10, iy, itemW, rowH, {
          color = isSel and theme.accentDark or theme.surfaceHigh,
          borderColor = isSel and theme.colors.accent or theme.border,
          borderWidth = isSel and 2 or 1,
          radius = 6,
        })
        Layout.drawText(tostring(name):upper(), x + 20, iy + 10, { font = "button", color = theme.heading, bold = true })
        if isRematch then
          Layout.drawBadge(x + itemW - 85, iy + 8, "REMATCH", { kind = "good", font = "tiny", width = 80 })
        elseif desc and desc ~= "" then
          Layout.drawBadge(x + itemW - 85, iy + 8, desc:upper(), { kind = "ghost", font = "tiny", width = 80 })
        end
      end
    end
    if #contacts > visibleRows then
      Layout.drawScrollBar(x + w - 14, y + 12, 6, listH - 24, #contacts, visibleRows, scroll)
    end
  else
    -- Landscape 2-Pane: Left contacts directory, Right contact dossier & call action
    local leftW = math.min(320, math.max(260, math.floor(w * 0.38)))
    local rightX = x + leftW + 12
    local rightW = w - leftW - 12

    -- Left Directory Panel
    Layout.drawCard(x, y, leftW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("REGISTERED TRAINERS", x + 16, y + 14, { font = "caption", color = theme.colors.accent, bold = true })

    local rowH = 40
    local gap = 6
    local listTopY = y + 36
    local visibleRows = math.max(1, math.floor((h - 52) / (rowH + gap)))
    local scroll = math.max(0, math.min(#contacts - visibleRows, state.contactSel - math.floor(visibleRows / 2)))
    local itemW = (#contacts > visibleRows) and (leftW - 32) or (leftW - 20)

    for r = 1, visibleRows do
      local idx = scroll + r
      local c = contacts[idx]
      if c then
        local iy = listTopY + (r - 1) * (rowH + gap)
        local isSel = (idx == state.contactSel)
        local desc, name, isRematch = getContactInfo(session, c)

        Layout.drawSlot(x + 10, iy, itemW, rowH, {
          color = isSel and theme.accentDark or theme.surfaceHigh,
          borderColor = isSel and theme.colors.accent or theme.border,
          borderWidth = isSel and 2 or 1,
          radius = 6,
        })
        Layout.drawText(tostring(name):upper(), x + 20, iy + 6, { font = "button", color = isSel and theme.heading or theme.text, bold = true, width = itemW - 90, singleLine = true })
        local subLabel = (desc and desc ~= "") and desc:upper() or "TRAINER"
        Layout.drawText(subLabel, x + 20, iy + 22, { font = "tiny", color = theme.textDim })

        if isRematch then
          Layout.drawBadge(x + 10 + itemW - 74, iy + 10, "REMATCH", { kind = "good", font = "tiny", width = 68, height = 20 })
        end
      end
    end
    if #contacts > visibleRows then
      Layout.drawScrollBar(x + leftW - 14, listTopY, 6, h - 52, #contacts, visibleRows, scroll)
    end

    -- Right Dossier & Outbound Call Panel
    Layout.drawCard(rightX, y, rightW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })

    if curContact then
      local desc, name, isRematch = getContactInfo(session, curContact)

      local locName = "HOENN REGION"
      if okMapsec and Mapsec and Mapsec.name and curContact.mapSec then
        local okM, mName = pcall(Mapsec.name, curContact.mapSec)
        if okM and mName and mName ~= "" then
          locName = mName
        end
      end

      -- Top Contact Hero Header
      Layout.drawText(tostring(name):upper(), rightX + 24, y + 20, { font = "title", color = theme.heading, bold = true })
      Layout.drawText(tostring(desc or "TRAINER"):upper(), rightX + 24, y + 54, { font = "caption", color = theme.colors.accent, bold = true })

      if isRematch then
        Layout.drawBadge(rightX + rightW - 140, y + 22, "READY FOR REMATCH", { kind = "good", font = "tiny", width = 120, height = 24 })
      else
        Layout.drawBadge(rightX + rightW - 120, y + 22, "STANDBY", { kind = "ghost", font = "tiny", width = 100, height = 24 })
      end

      -- Location Info Slot
      local locSlotY = y + 84
      Layout.drawSlot(rightX + 20, locSlotY, rightW - 40, 52, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText("FIELD LOCATION", rightX + 32, locSlotY + 10, { font = "tiny", color = theme.textDim })
      Layout.drawText(locName:upper(), rightX + 32, locSlotY + 26, { font = "button", color = theme.heading, bold = true })

      -- Call Dialogue / Communication Window
      local msgSlotY = locSlotY + 64
      local msgSlotH = h - (msgSlotY - y) - 20
      Layout.drawSlot(rightX + 20, msgSlotY, rightW - 40, msgSlotH, { color = theme.surfaceHigh, borderColor = theme.borderStrong, radius = 6 })
      Layout.drawText("MATCH CALL COMMUNICATOR", rightX + 32, msgSlotY + 12, { font = "caption", color = theme.colors.accent, bold = true })

      if state.callActive then
        local dialogText = state.callMessage or "Connecting to trainer radio signal..."
        Layout.drawTextWrapped(dialogText, rightX + 32, msgSlotY + 40, rightW - 64, { font = "body", color = theme.heading })
      else
        Layout.drawTextWrapped(
          "Press [A] to initiate an outbound call. When trainers are ready for a rematch, their battle status and location will synchronize live with the PokéNav.",
          rightX + 32, msgSlotY + 40, rightW - 64, { font = "body", color = theme.textDim }
        )
        local btnW = 140
        local btnH = 34
        local btnX = rightX + math.floor((rightW - btnW) / 2)
        local btnY = msgSlotY + msgSlotH - btnH - 16
        Layout.drawButton(btnX, btnY, btnW, btnH, "CALL TRAINER", { kind = "primary", font = "button" })
      end
    end
  end
end

-- -----------------------------------------------------------------------------
-- Card 3: Contest Condition Radar
-- -----------------------------------------------------------------------------

local function getPartyMons(game, state)
  local session = getSession(game, state)
  if session and session.party and #session.party > 0 then return session.party end
  if game and game.save and game.save.party and #game.save.party > 0 then return game.save.party end
  return {}
end

local function drawConditionCard(game, state, x, y, w, h, theme, isNarrow)
  local party = getPartyMons(game, state)
  if #party == 0 then
    Layout.drawCard(x, y, w, h, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("NO POKÉMON IN PARTY", x + 24, y + 24, { font = "headline", color = theme.colors.accent, bold = true })
    return
  end

  state.condMonSel = math.max(1, math.min(#party, state.condMonSel or 1))
  local activeMon = party[state.condMonSel]
  local monName = getMonName(activeMon)

  if isNarrow then
    -- Narrow / Mobile View: Top Mon Strip, Center Radar
    local stripH = 54
    Layout.drawCard(x, y, w, stripH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local tabW = math.floor((w - 16) / math.min(6, #party))
    for i, mon in ipairs(party) do
      local isSel = (i == state.condMonSel)
      local tx = x + 8 + (i - 1) * tabW
      local name = getMonName(mon):sub(1, 4)
      Layout.drawButton(tx, y + 8, tabW - 4, 38, name, {
        kind = isSel and "primary" or "ghost",
        selected = isSel,
        font = "tiny",
      })
    end

    local radarCardY = y + stripH + 8
    local radarCardH = h - stripH - 8
    Layout.drawCard(x, radarCardY, w, radarCardH, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText(monName, x + 16, radarCardY + 14, { font = "headline", color = theme.heading, bold = true })

    local rcx = x + math.floor(w / 2)
    local rcy = radarCardY + math.floor((radarCardH - 20) / 2)
    local radius = math.min(75, math.floor(w * 0.28))
    Widgets.drawConditionRadar(rcx, rcy, radius, activeMon, { theme = theme })
  else
    -- Landscape 2-Pane View: Left Party List, Right Condition Radar
    local leftW = math.min(260, math.max(200, math.floor(w * 0.32)))
    local rightX = x + leftW + 12
    local rightW = w - leftW - 12

    -- Left Party List
    Layout.drawCard(x, y, leftW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText("PARTY POKÉMON", x + 16, y + 14, { font = "caption", color = theme.colors.accent, bold = true })

    local rowH = 46
    local gap = 6
    local startY = y + 36

    for i, mon in ipairs(party) do
      local isSel = (i == state.condMonSel)
      local iy = startY + (i - 1) * (rowH + gap)
      local name = getMonName(mon)
      local lvl = mon.level or (mon.box and mon.box.level) or 5

      Layout.drawSlot(x + 10, iy, leftW - 20, rowH, {
        color = isSel and theme.accentDark or theme.surfaceHigh,
        borderColor = isSel and theme.colors.accent or theme.border,
        borderWidth = isSel and 2 or 1,
        radius = 6,
      })

      Layout.drawText(name, x + 20, iy + 8, { font = "button", color = isSel and theme.heading or theme.text, bold = true })
      Layout.drawText(("LV. %d"):format(lvl), x + 20, iy + 26, { font = "tiny", color = theme.textDim })

      local sheen = mon.sheen or (mon.contest and mon.contest.sheen) or 0
      if sheen > 0 then
        Layout.drawBadge(x + leftW - 74, iy + 12, ("SHN %d"):format(sheen), { kind = "ghost", font = "tiny", width = 50 })
      end
    end

    -- Right Radar & Stats Canvas
    Layout.drawCard(rightX, y, rightW, h, { color = theme.surface, borderColor = theme.border, radius = 8 })
    Layout.drawText(("%s'S CONTEST STATS"):format(monName), rightX + 24, y + 18, { font = "headline", color = theme.heading, bold = true })

    local rcx = rightX + math.floor(rightW / 2)
    local rcy = y + math.floor(h / 2) - 8
    local radius = math.min(100, math.floor(h * 0.28))
    Widgets.drawConditionRadar(rcx, rcy, radius, activeMon, { theme = theme })
  end
end

-- -----------------------------------------------------------------------------
-- Card 4: Ribbons Showcase
-- -----------------------------------------------------------------------------

local function getRibbonHolders(session)
  local okRib, Ribbons = pcall(require, "src.core.game3.rse.ribbons")
  if not (okRib and Ribbons and Ribbons.count) then return {} end
  local holders = {}
  for i, mon in ipairs(session and session.party or {}) do
    if Ribbons.hasSpeciesNotEgg(mon) then
      local cnt = Ribbons.count(mon)
      if cnt > 0 then
        holders[#holders + 1] = { mon = mon, partyIdx = i, count = cnt }
      end
    end
  end
  return holders
end

local function drawRibbonsCard(game, state, x, y, w, h, theme, isNarrow)
  local session = getSession(game, state)
  local holders = state._ribbonHolders
  if not holders then
    holders = getRibbonHolders(session)
    state._ribbonHolders = holders
  end

  if #holders == 0 then
    Layout.drawCard(x, y, w, h, { color = theme.surface, borderColor = theme.border, radius = 8 })
    local emptySlotW = math.min(w - 32, 420)
    local emptySlotH = 140
    local ex = x + math.floor((w - emptySlotW) / 2)
    local ey = y + math.floor((h - emptySlotH) / 2)
    Layout.drawSlot(ex, ey, emptySlotW, emptySlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })
    Layout.drawText("NO RIBBON WINNERS", ex + 24, ey + 24, { font = "headline", color = theme.colors.accent, bold = true })
    Layout.drawTextWrapped(
      "None of your Pokémon have won ribbons yet. Compete in Pokémon Contests or defeat the Pokémon League Champion to earn commemorative ribbons.",
      ex + 24, ey + 54, emptySlotW - 48, { font = "body", color = theme.textDim }
    )
    return
  end

  state.ribbonMonSel = math.max(1, math.min(#holders, state.ribbonMonSel or 1))
  local activeHolder = holders[state.ribbonMonSel]
  local name = getMonName(activeHolder and activeHolder.mon)

  Layout.drawCard(x, y, w, h, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText(("%s'S COMMEMORATIVE RIBBONS"):format(name), x + 24, y + 18, { font = "headline", color = theme.heading, bold = true })
  Layout.drawBadge(x + w - 140, y + 16, ("TOTAL: %d"):format(activeHolder.count), { kind = "gold", font = "tiny", width = 110, height = 24 })

  local slotY = y + 54
  local slotH = h - 68
  Layout.drawSlot(x + 20, slotY, w - 40, slotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })

  -- Showcase Badge Cards
  local badges = {
    { title = "CHAMPION RIBBON", desc = "Ribbon awarded for clearing the Hoenn Pokémon League." },
    { title = "WINNING RIBBON",  desc = "Ribbon awarded for clearing Level 50 Battle Tower." },
    { title = "VICTORY RIBBON",  desc = "Ribbon awarded for clearing Open Level Battle Tower." },
    { title = "ARTIST RIBBON",   desc = "Ribbon awarded for being chosen as a super sketch model." },
    { title = "EFFORT RIBBON",   desc = "Ribbon awarded for being an extraordinarily hard worker." },
  }

  local cols = isNarrow and 1 or 2
  local cardW = math.floor((w - 60 - (cols - 1) * 12) / cols)
  local cardH = 48

  for i = 1, math.min(#badges, 4) do
    local b = badges[i]
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local bx = x + 30 + col * (cardW + 12)
    local by = slotY + 16 + row * (cardH + 10)

    Layout.drawCard(bx, by, cardW, cardH, { color = theme.surface, borderColor = theme.border, radius = 6 })
    Layout.drawBadge(bx + 8, by + 12, "★", { kind = "gold", width = 24, height = 24 })
    Layout.drawText(b.title, bx + 40, by + 8, { font = "caption", color = theme.heading, bold = true })
    Layout.drawText(b.desc, bx + 40, by + 24, { font = "tiny", color = theme.textDim, width = cardW - 48, singleLine = true })
  end
end

-- -----------------------------------------------------------------------------
-- Main Entry Point: PokenavRenderer.draw
-- -----------------------------------------------------------------------------

function PokenavRenderer.draw(game, state, w, h, theme, subState, animProgress)
  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 600) or ctx.isPortrait

  local cards = PokenavRenderer.getAvailableCards(game, state)
  state.cardIndex = math.max(1, math.min(#cards, state.cardIndex or 1))
  local activeCard = cards[state.cardIndex] or cards[1]
  local activeId = activeCard.id

  -- 1. Top Header Card & Tab Bar
  local headH = 48
  Layout.drawCard(0, 0, w, headH, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText("POKÉNAV", 18, 14, { font = "headline", color = theme.heading, bold = true })

  -- Top Tabs for Unlocked Cards
  local tabStartX = 120
  local tabW = math.min(110, math.max(65, math.floor((w - tabStartX - 20) / #cards)))
  local tabH = 32
  local tabY = 8

  for i, c in ipairs(cards) do
    local isCardActive = (i == state.cardIndex)
    local tx = tabStartX + (i - 1) * (tabW + 6)
    if tx + tabW <= w - 10 then
      Layout.drawButton(tx, tabY, tabW, tabH, isNarrow and c.tag or c.label, {
        kind = isCardActive and "primary" or "ghost",
        selected = isCardActive,
        font = "caption",
      })
    end
  end

  -- 2. Card Content Viewport
  local contentY = headH + 8
  local contentH = h - headH - 48

  if activeId == "map" then
    -- Embed TownMapRenderer in view/inspection mode
    TownMapRenderer.draw(game, state, w, h, theme, subState, animProgress)
    return
  elseif activeId == "call" or activeId == "eyes" then
    drawMatchCallCard(game, state, 0, contentY, w, contentH, theme, isNarrow)
  elseif activeId == "condition" then
    drawConditionCard(game, state, 0, contentY, w, contentH, theme, isNarrow)
  elseif activeId == "ribbons" then
    drawRibbonsCard(game, state, 0, contentY, w, contentH, theme, isNarrow)
  end

  -- 3. Bottom Two-Tier Navigation Hint Bar
  local footY = h - 38
  local inCard = (state.mode == "card")
  local hints = {}

  if not inCard then
    -- Tier 1: Device Chassis Tab Bar
    hints = {
      { key = "◄ ►", label = "Cycle Cards" },
      { key = "A",   label = "Enter Card", primary = true },
      { key = "B",   label = "Turn Off PokéNav" },
    }
  else
    -- Tier 2: Inside Active Card
    if activeId == "call" or activeId == "eyes" then
      hints = {
        { key = "▲ ▼", label = "Select Trainer" },
        { key = "A",   label = "Call Trainer", primary = true },
        { key = "B",   label = "Back to Cards" },
      }
    elseif activeId == "condition" then
      hints = {
        { key = "▲ ▼", label = "Select Pokémon" },
        { key = "B",   label = "Back to Cards" },
      }
    elseif activeId == "ribbons" then
      hints = {
        { key = "▲ ▼", label = "Select Pokémon" },
        { key = "B",   label = "Back to Cards" },
      }
    else
      hints = {
        { key = "B",   label = "Back to Cards" },
      }
    end
  end

  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

return PokenavRenderer
