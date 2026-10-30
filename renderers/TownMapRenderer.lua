-- OmniUI Town Map & Pokédex Area/Habitat Viewer Renderer
-- High-resolution regional map presenter with animated habitat radar pins,
-- live encounter list, player tracking, and fly destination routing.

local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local TownMapRenderer = {}

local function getHabitatTerrain(loc, game, nestSpecies)
  if type(loc) == "table" then
    if loc.terrain then return tostring(loc.terrain):upper() end
    if loc.kind then return tostring(loc.kind):upper() end
    if loc.habitat then return tostring(loc.habitat):upper() end
    if loc.type then return tostring(loc.type):upper() end
  end

  local name = tostring(type(loc) == "table" and (loc.name or loc.label) or loc or ""):gsub("[\r\n]+", " "):upper()

  -- Check if encounter data explicitly reveals water vs grass
  if game and game.data and game.data.encounters and nestSpecies and type(loc) == "table" then
    for mapId, enc in pairs(game.data.encounters) do
      local matchedLoc = false
      if loc.mapId and loc.mapId == mapId then
        matchedLoc = true
      elseif loc.name and (mapId:gsub("_", " ") == name or mapId == name) then
        matchedLoc = true
      end
      if matchedLoc then
        local inWater = false
        local inGrass = false
        if enc.water and enc.water.slots then
          for _, slot in ipairs(enc.water.slots) do
            if slot.species == nestSpecies then inWater = true break end
          end
        end
        if enc.grass and enc.grass.slots then
          for _, slot in ipairs(enc.grass.slots) do
            if slot.species == nestSpecies then inGrass = true break end
          end
        end
        if inWater and not inGrass then return "WATER" end
        if inGrass and not inWater then
          if name:find("CAVE") or name:find("TUNNEL") or name:find("MT") or name:find("ROCK") then
            return "CAVE"
          elseif name:find("TOWER") or name:find("MANSION") or name:find("POWER") or name:find("PLANT") or name:find("HIDEOUT") then
            return "DUNGEON"
          end
          return "GRASS"
        end
      end
    end
  end

  -- Direct water/ocean/sea checks (including Sea Routes 19, 20, 21)
  if name:find("SEA") or name:find("WATER") or name:find("OCEAN")
     or name:find("SURF") or name:find("LAKE") or name:find("RIVER")
     or name:find("BAY") or name:find("CHANNEL") or name:find("STRAIT")
     or name:find("SEAFOAM") or name:find("CURRENT") or name:find("BEACH")
     or name:find("ISLAND")
     or name:match("^ROUTE%s*19$") or name:match("^ROUTE%s*20$") or name:match("^ROUTE%s*21$") then
    return "WATER"
  end

  if name:find("CAVE") or name:find("TUNNEL") or name:find("MT") or name:find("MOUNT")
     or name:find("ROCK") or name:find("PEAK") or name:find("CHASM") or name:find("GROTTO") or name:find("MINE") then
    return "CAVE"
  end

  if name:find("TOWER") or name:find("MANSION") or name:find("POWER") or name:find("PLANT")
     or name:find("HIDEOUT") or name:find("SILPH") or name:find("RUIN") or name:find("DUNGEON")
     or name:find("PYRE") or name:find("LAB") then
    return "DUNGEON"
  end

  if name:find("SAFARI") or name:find("PARK") or name:find("MARSH") then
    return "SAFARI"
  end

  if name:find("FOREST") or name:find("WOODS") or name:find("JUNGLE") or name:find("BUSH") then
    return "GRASS"
  end

  if name:find("ROUTE") or name:find("ROAD") or name:find("PATH") then
    return "GRASS"
  end

  return "GRASS"
end

local function drawMapCursor(cx, cy, scale, time, theme)
  local pw = 8 * scale
  local ph = 8 * scale
  local px = cx - pw / 2
  local py = cy - ph / 2
  local pad = math.max(3, math.floor(2 * scale))

  local pulse = 0.5 + 0.5 * math.sin(time * 6)
  local haloR = (pw / 2) + pad + 2 + pulse * 3

  -- 1. Outer Pulsing Beacon Halo
  local acc = theme.colors and theme.colors.accent or { 0.38, 0.40, 0.95 }
  love.graphics.setColor(acc[1], acc[2], acc[3], 0.20 + 0.15 * pulse)
  love.graphics.circle("fill", cx, cy, haloR)

  -- 2. Semi-transparent luminous interior tint
  love.graphics.setColor(acc[1], acc[2], acc[3], 0.25 + 0.12 * pulse)
  love.graphics.rectangle("fill", px - pad, py - pad, pw + pad * 2, ph + pad * 2, 4, 4)

  -- 3. High-Contrast Outer Shadow
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.setLineWidth(4.5)
  love.graphics.rectangle("line", px - pad, py - pad, pw + pad * 2, ph + pad * 2, 4, 4)

  -- 4. Inner Cursor Box
  love.graphics.setColor(acc[1] + (1 - acc[1]) * 0.2 * pulse, acc[2] + (1 - acc[2]) * 0.2 * pulse, acc[3] + (1 - acc[3]) * 0.2 * pulse, 1.0)
  love.graphics.setLineWidth(3.0)
  love.graphics.rectangle("line", px - pad, py - pad, pw + pad * 2, ph + pad * 2, 4, 4)

  -- 5. Sharp Corner Target Reticles
  local cornerLen = math.max(4, math.floor(3 * scale))
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.setLineWidth(2.0)
  local x1 = px - pad
  local y1 = py - pad
  local x2 = px + pw + pad
  local y2 = py + ph + pad

  love.graphics.line(x1, y1 + cornerLen, x1, y1, x1 + cornerLen, y1)
  love.graphics.line(x2 - cornerLen, y1, x2, y1, x2, y1 + cornerLen)
  love.graphics.line(x1, y2 - cornerLen, x1, y2, x1 + cornerLen, y2)
  love.graphics.line(x2 - cornerLen, y2, x2, y2, x2 + cornerLen, y2)

  love.graphics.setLineWidth(1)
end

function TownMapRenderer.frlgMarkerOffset(loc)
  loc = loc or {}
  if loc.marker then
    return (loc.marker.x or 0) - 32, loc.marker.y or 0
  end
  local lx = loc.x or (loc.coords and loc.coords.x) or 0
  local ly = loc.y or (loc.coords and loc.coords.y) or 0
  return lx - 32, ly
end

function TownMapRenderer.swapTarget(active, info)
  local regs = info and info.availableRegions
  if type(regs) == "table" then
    for _, region in ipairs(regs) do
      if region ~= active then return tostring(region):upper() end
    end
  end
  if active == "johto" or active == "sevii" then return "KANTO" end
  if active == "kanto" then return "JOHTO" end
  return "KANTO"
end

local function frlgDexImage(region)
  local ok, Chrome = pcall(require, "src.ui.game3.pokedex_chrome")
  if not (ok and Chrome and Chrome.getImage) then return nil end
  local key = "map_" .. tostring(region or "kanto")
  local okI, img = pcall(Chrome.getImage, key)
  if okI and img then return img end
  local okK, fallback = pcall(Chrome.getImage, "map_kanto")
  if okK then return fallback end
  return nil
end

-- The overlay scales and shifts the panel. Scissor is in screen pixels, so the
-- slot has to be converted or the map is cut down to its top-left corner.
local function clipSlot(x, y, w, h)
  local tp = love.graphics.transformPoint
  if tp then
    local x1, y1 = tp(x, y)
    local x2, y2 = tp(x + w, y + h)
    local sx, sy = math.min(x1, x2), math.min(y1, y2)
    love.graphics.setScissor(sx, sy, math.abs(x2 - x1), math.abs(y2 - y1))
  else
    love.graphics.setScissor(x, y, w, h)
  end
end

local function drawFittedImage(img, mapX, mapY, scale, canvasW, canvasH, srcX, srcY)
  love.graphics.setColor(1, 1, 1, 1)
  srcX, srcY = srcX or 0, srcY or 0
  local iw, ih = img:getWidth(), img:getHeight()
  local qw = math.min(canvasW, math.max(0, iw - srcX))
  local qh = math.min(canvasH, math.max(0, ih - srcY))
  if qw < 1 or qh < 1 then return end
  if srcX ~= 0 or srcY ~= 0 or qw < iw or qh < ih then
    local quad = love.graphics.newQuad(srcX, srcY, qw, qh, iw, ih)
    love.graphics.draw(img, quad, mapX, mapY, 0, scale, scale)
  else
    love.graphics.draw(img, mapX, mapY, 0, scale, scale)
  end
end

local function frlgWallImage(state)
  if not (state and state.cursorX ~= nil and (state.open or state.mode)) then return nil end
  local ok, Gpu = pcall(require, "src.ui.game3.region_map_gpu")
  if not (ok and Gpu and Gpu.image) then return nil end
  local names = { [0] = "kanto_map", "sevii123_map", "sevii45_map", "sevii67_map" }
  local name = names[state.shownRegion or 0] or "kanto_map"
  local okI, img = pcall(Gpu.image, name)
  if okI then return img end
  return nil
end

function TownMapRenderer.draw(game, state, w, h, theme, subState)
  local adapter = AdapterResolver.resolve(game)
  local isAreaMode = (state.nestSpecies ~= nil) or (state.view == "area") or (state.page == 5)
  local isFlyMode = (state.fly == true)

  local curSpecies = state.nestSpecies or (state.info and state.info.dexNum) or (state.current and state:current() and state:current().species) or (type(state.rows) == "table" and state.index and state.rows[state.index] and state.rows[state.index].species) or state.species
  local areaInfo = isAreaMode and adapter.getAreaInfo and adapter:getAreaInfo(curSpecies, state.areaRegion)
  local activeRegion = areaInfo and areaInfo.region or (state.areaRegion or (adapter.region == "HOENN" and "hoenn" or (adapter.region == "JOHTO" and "johto" or "kanto")))
  local isHoenn = (activeRegion == "hoenn")
  local canSwapRegion = areaInfo and areaInfo.canSwapRegion or false  local activeNests = (areaInfo and areaInfo.nests) or state.nests or {}
  local displayLocations = (areaInfo and areaInfo.locations) or activeNests or {}

  local monName = nil
  if adapter and adapter.getDexEntry and curSpecies then
    local okDex, dex = pcall(adapter.getDexEntry, adapter, curSpecies)
    if okDex and dex and dex.name and dex.name ~= "" and not tostring(dex.name):match("^%d+$") then
      monName = dex.name:upper()
    end
  end
  if not monName then
    local def = curSpecies and game.data and game.data.pokemon and game.data.pokemon[curSpecies]
    monName = def and (def.name or def.species)
    if not monName and type(curSpecies) == "number" then
      local okP, Pokemon = pcall(require, "src.core.game3.pokemon")
      if okP and Pokemon and Pokemon.name then
        local okN, n = pcall(Pokemon.name, curSpecies)
        if okN and n and n ~= "" and not n:find("^%?+$") and not tostring(n):match("^%d+$") then
          monName = n:upper()
        end
      end
    end
    monName = monName or tostring(curSpecies or "POKÉMON"):upper()
  end

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 560) or ctx.isPortrait
  local footY = h - 38

  local isPokenav = state._inPokenav or state.isPokenav or (state.cardIndex ~= nil)

  -- 1. Top Header Card
  if not isPokenav then
    Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
    if isAreaMode then
      Layout.drawText(("%s'S HABITAT AREA"):format(monName), 18, 12, { font = "headline", color = theme.heading, bold = true })
      local regionBadge = canSwapRegion and ("%s [◄ ►: %s]"):format(activeRegion:upper(), TownMapRenderer.swapTarget(activeRegion, areaInfo)) or activeRegion:upper()
      local rw = Layout.textWidth(regionBadge, "caption") + 24
      Layout.drawBadge(w - rw - 16, 10, regionBadge, { kind = (activeRegion == "johto") and "good" or "accent", font = "caption", height = 24, width = rw })
    elseif isFlyMode then
      Layout.drawText("FLY DESTINATION SELECT", 18, 12, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(w - (isNarrow and 100 or 180), 10, "AIR TRAVEL", { kind = "accent", font = "caption", height = 24 })
    else
      local regLabel = (activeRegion:upper() .. " REGIONAL MAP")
      Layout.drawText(regLabel, 18, 12, { font = "headline", color = theme.heading, bold = true })
      Layout.drawBadge(w - (isNarrow and 90 or 180), 10, activeRegion:upper(), { kind = "ghost", font = "caption", height = 24 })
    end
  end

  local bg = state.bg
  local hoennImg = state.mapImg or (bg and bg.img)
  if not hoennImg and isHoenn then
    local okKit, Kit = pcall(require, "src.ui.game3.rse.scene_kit")
    local okRM, RegionMap = pcall(require, "src.ui.game3.rse.region_map")
    if okKit and Kit and Kit.image and okRM and RegionMap and RegionMap.manifest then
      local okM, man = pcall(RegionMap.manifest)
      local entry = okM and man and man.layers and man.layers.map
      local path = type(entry) == "table" and entry.png or entry
      if path then
        local okI, img = pcall(Kit.image, path)
        if okI then hoennImg = img end
      end
    end
    if not hoennImg and okKit and Kit and Kit.image then
      local okI, img = pcall(Kit.image, "data/generated/gba/rse/region_map/map.png")
      if okI then hoennImg = img end
    end
  end

  local gen2Gfx = game.data and (game.data.gen2MenuGfx or (game.data.menuGfx and game.data.menuGfx.pokegear))
  local gen2MapCells = (state.mapGfx and state.mapGfx.maps and state.mapGfx.maps[activeRegion])
    or (gen2Gfx and gen2Gfx.pokegear and gen2Gfx.pokegear.maps and gen2Gfx.pokegear.maps[activeRegion])

  local mapKind = "classic"
  local frlgDexImg, frlgWallImg
  local gen3 = adapter and adapter.generation == 3
  if gen3 and isAreaMode and (activeRegion == "kanto" or activeRegion == "sevii") then
    frlgDexImg = frlgDexImage(activeRegion)
    if frlgDexImg then mapKind = "frlg-dex" end
  elseif gen3 and not isAreaMode and not isHoenn then
    frlgWallImg = frlgWallImage(state)
    if frlgWallImg then mapKind = "frlg-wall" end
  end
  -- Same fit as Gen 1/2: one native canvas, scaled uniformly into the slot.
  -- FRLG dex art is 96×72. The region sheet is 240×160, but the land sits in
  -- the window at (24, 16, 192×144); the side strips are blank and would
  -- letterbox the map if we scaled the whole sheet.
  local mapBaseW, mapBaseH = 160, 144
  local mapOriginX, mapOriginY = 0, 0
  if mapKind == "frlg-dex" then
    mapBaseW, mapBaseH = 96, 72
  elseif mapKind == "frlg-wall" then
    mapBaseW, mapBaseH = 192, 144
    mapOriginX, mapOriginY = 24, 16
  elseif isHoenn then
    mapBaseW, mapBaseH = 240, 160
  end

  local function drawRegionalMap(mapX, mapY, scale, slotX, slotY, slotW, slotH)
    if mapKind == "frlg-dex" and frlgDexImg then
      drawFittedImage(frlgDexImg, mapX, mapY, scale, 96, 72)
      return true
    elseif mapKind == "frlg-wall" and frlgWallImg then
      drawFittedImage(frlgWallImg, mapX, mapY, scale, mapBaseW, mapBaseH, mapOriginX, mapOriginY)
      return true
    elseif isHoenn and hoennImg then
      drawFittedImage(hoennImg, mapX, mapY, scale, 240, 160)
      return true
    elseif isHoenn then
      love.graphics.setColor(0.10, 0.18, 0.28, 1.0)
      love.graphics.rectangle("fill", mapX, mapY, 240 * scale, 160 * scale, 4)
      love.graphics.setColor(0.18, 0.35, 0.25, 0.8)
      love.graphics.rectangle("fill", mapX + 8 * scale, mapY + 16 * scale, 224 * scale, 128 * scale, 4)
      return true
    elseif gen2MapCells and state.drawTilemap then
      love.graphics.push()
      love.graphics.translate(mapX, mapY)
      love.graphics.scale(scale, scale)
      state:drawTilemap(gen2MapCells)
      love.graphics.pop()
      return true
    elseif bg and bg.img and bg.quads and bg.map then
      love.graphics.setColor(1, 1, 1, 1)
      for i, t in ipairs(bg.map) do
        local col = (i - 1) % 20
        local row = math.floor((i - 1) / 20)
        local q = bg.quads[t]
        if q then
          love.graphics.draw(bg.img, q, mapX + col * 8 * scale, mapY + row * 8 * scale, 0, scale, scale)
        end
      end
      return true
    end
    return false
  end

  -- Converts landmark or player location coordinates into screen pixels centered on the landmark
  local function locToCenterPixel(loc, mapX, mapY, scale)
    local lx = loc.x or (loc.coords and loc.coords.x) or 0
    local ly = loc.y or (loc.coords and loc.coords.y) or 0
    local cx, cy
    if mapKind == "frlg-dex" then
      local mx, my = TownMapRenderer.frlgMarkerOffset(loc)
      return mapX + mx * scale, mapY + my * scale
    elseif isHoenn or (loc.mapId == "hoenn") then
      -- Hoenn GBA Tile Coordinates (1:1 with 256x160 canvas, tiles are 8x8)
      cx = mapX + (lx * 8 + 4) * scale
      cy = mapY + (ly * 8 + 4) * scale
    elseif lx >= 20 or ly >= 18 or (gen2MapCells and state.drawTilemap) then
      -- Gen 2 Pixel Coordinates (0..160, 0..144)
      cx = mapX + lx * scale
      cy = mapY + ly * scale
    else
      -- Gen 1 Tile Coordinates (0..19, 0..17)
      cx = mapX + (lx * 8 + 4) * scale
      cy = mapY + (ly * 8 + 4) * scale
    end
    return cx, cy
  end

  local function drawFrlgDungeonIcons(mapX, mapY, scale)
    if mapKind ~= "frlg-wall" then return end
    local ok, RegionMap = pcall(require, "src.ui.game3.region_map")
    if not (ok and RegionMap and RegionMap.dungeonIcons) then return end
    local okL, icons = pcall(RegionMap.dungeonIcons)
    if not (okL and type(icons) == "table") then return end
    local okG, Gpu = pcall(require, "src.ui.game3.region_map_gpu")
    if not (okG and Gpu and Gpu.image) then return end
    love.graphics.setColor(1, 1, 1, 1)
    for _, icon in ipairs(icons) do
      if icon.visible and icon.px and icon.py then
        local name = icon.frame == 1 and "dungeon_icon_visited" or "dungeon_icon"
        local okI, img = pcall(Gpu.image, name)
        if okI and img then
          love.graphics.draw(img, mapX + (icon.px - mapOriginX) * scale, mapY + (icon.py - mapOriginY) * scale, 0, scale, scale)
        end
      end
    end
  end

  local function drawMapCursor(mapX, mapY, scale)
    if isAreaMode or state.cursorX == nil then return end
    local cx, cy
    if isHoenn then
      cx = mapX + (state.cursorX * 8 + 4) * scale
      cy = mapY + ((state.cursorY or 0) * 8 + 4) * scale
    elseif mapKind == "frlg-wall" then
      cx = mapX + (state.cursorX * 8 + 36 - mapOriginX) * scale
      cy = mapY + ((state.cursorY or 0) * 8 + 36 - mapOriginY) * scale
    else
      return
    end
    love.graphics.setColor(1, 0.92, 0.35, 0.95)
    love.graphics.circle("line", cx, cy, math.max(4, 6 * scale))
    love.graphics.circle("fill", cx, cy, math.max(2, 2.5 * scale))
    local px, py
    if mapKind == "frlg-wall" and state.playerX ~= nil then
      px = mapX + (state.playerX * 8 + 28 - mapOriginX) * scale
      py = mapY + ((state.playerY or 0) * 8 + 28 - mapOriginY) * scale
    elseif isHoenn and state.playerIconX ~= nil then
      px = mapX + (state.playerIconX * 8 + 4) * scale
      py = mapY + ((state.playerIconY or 0) * 8 + 4) * scale
    end
    if px then
      love.graphics.setColor(0.95, 0.28, 0.28, 0.95)
      love.graphics.circle("fill", px, py, math.max(2, 3 * scale))
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local time = love.timer and love.timer.getTime() or 0

  local function romPlain(key)
    if type(key) ~= "string" or key == "" then return nil end
    local ok, text = pcall(function()
      return require("src.core.game3.rom_text").plain(key)
    end)
    if not (ok and type(text) == "string") then return nil end
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " ")
    if text == "" or text == key then return nil end
    return text
  end

  local function cursorInfo()
    if isAreaMode then return nil end
    if isHoenn and state.mapSecName then
      local sub = state.flyText and state.flyText.sub
      return { name = state.mapSecName, dungeon = (sub and sub ~= state.mapSecName) and sub or nil }
    end
    if state.cursorX == nil then return nil end
    local ok, RegionMap = pcall(require, "src.ui.game3.region_map")
    if not (ok and RegionMap and RegionMap.cursorPrompt) then return nil end
    local pOk, card = pcall(RegionMap.cursorPrompt)
    if not (pOk and type(card) == "table") then return nil end
    card.hint = romPlain(card.hintKey)
    return card
  end

  local cursorCard = cursorInfo()

  local function destinationCopy()
    local selLoc = state.locs and state.locs[state.sel or 1]
    local name = state.mapSecName or (selLoc and (selLoc.name or selLoc.label)) or "KANTO REGION"
    local detail, hint
    if cursorCard then
      if cursorCard.kind == "cancel" then
        name = cursorCard.hint or "CANCEL"
      elseif cursorCard.kind == "switch" then
        name = cursorCard.hint or "SWITCH REGION"
      elseif cursorCard.name and cursorCard.name ~= "" then
        name = cursorCard.name
        detail = cursorCard.dungeon
        hint = cursorCard.hint
      else
        name = cursorCard.hint or "—"
      end
      if cursorCard.preview then
        detail = cursorCard.preview.name or detail
        hint = cursorCard.preview.desc or hint
      end
    end
    local function clean(value)
      if not value or value == "" then return nil end
      return tostring(value):gsub("[\r\n]+", " "):gsub("%s+", " ")
    end
    return clean(name) or "KANTO REGION", clean(detail), clean(hint)
  end

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE VIEW
    -- =========================================================================
    local mapBoxH = math.floor(h * 0.46)
    Layout.drawCard(0, 50, w, mapBoxH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local pad = 8
    local slotX = pad
    local slotY = 50 + pad
    local slotW = w - pad * 2
    local slotH = mapBoxH - pad * 2

    local baseW, baseH = mapBaseW, mapBaseH
    local scale = math.min(slotW / baseW, slotH / baseH)

    local mapX = slotX + math.floor((slotW - baseW * scale) / 2)
    local mapY = slotY + math.floor((slotH - baseH * scale) / 2)

    state._mapGeometry = {
      mapX = mapX, mapY = mapY, drawW = slotW, drawH = slotH, scale = scale,
      isHoenn = isHoenn, activeRegion = activeRegion, mapKind = mapKind,
    }

    Layout.drawSlot(slotX, slotY, slotW, slotH, {
      color = { 0.05, 0.07, 0.10, 1.0 },
      borderColor = theme.borderStrong,
      borderWidth = 1.5,
      radius = 6,
    })

    clipSlot(slotX, slotY, slotW, slotH)
    drawRegionalMap(mapX, mapY, scale, slotX, slotY, slotW, slotH)
    drawFrlgDungeonIcons(mapX, mapY, scale)

    if isAreaMode and activeNests and #activeNests > 0 then
      local pulse = 0.5 + 0.5 * math.sin(time * 3.5)
      for _, loc in ipairs(activeNests) do
        if isHoenn or loc.mapId == "hoenn" then
          local lx = loc.x or (loc.coords and loc.coords.x) or 0
          local ly = loc.y or (loc.coords and loc.coords.y) or 0
          local rx = mapX + lx * 8 * scale
          local ry = mapY + ly * 8 * scale
          local rw = 8 * scale
          local rh = 8 * scale

          -- Crisp luminous route tile fill
          love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.38 + 0.16 * pulse)
          love.graphics.rectangle("fill", rx, ry, rw, rh)

          -- Sleek boundary outline
          love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.75 + 0.20 * pulse)
          love.graphics.setLineWidth(1)
          love.graphics.rectangle("line", rx + 0.5, ry + 0.5, rw - 1, rh - 1)

          if loc.isSpecial then
            local cx, cy = locToCenterPixel(loc, mapX, mapY, scale)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", cx, cy, 2 * scale)
          end
        else
          local cx, cy = locToCenterPixel(loc, mapX, mapY, scale)
          local shape = mapKind == "frlg-dex" and loc.marker and loc.marker.shape
          if shape then
            -- Same sprite and origin as the FRLG dex: top-left at (x - 32, y), scaled with the map.
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.scale(scale, scale)
            pcall(function()
              local Chrome = require("src.ui.game3.pokedex_chrome")
              if Chrome.drawAreaMarker then Chrome.drawAreaMarker(shape, 0, 0) end
            end)
            love.graphics.pop()
          else
            local haloR = (6 + 3 * pulse) * scale
            love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.35 + 0.25 * pulse)
            love.graphics.circle("fill", cx, cy, haloR)

            love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.95)
            love.graphics.circle("fill", cx, cy, 2.5 * scale)

            love.graphics.setColor(1, 1, 1, 0.90)
            love.graphics.circle("fill", cx, cy, 1.2 * scale)
          end
        end
      end
    end

    if state.playerLoc then
      local px, py = locToCenterPixel(state.playerLoc, mapX, mapY, scale)
      love.graphics.setColor(theme.colors.hpRed[1], theme.colors.hpRed[2], theme.colors.hpRed[3], 0.40)
      love.graphics.circle("fill", px, py, 8 * scale)

      love.graphics.setColor(theme.colors.hpRed[1], theme.colors.hpRed[2], theme.colors.hpRed[3], 1.0)
      love.graphics.circle("fill", px, py, 3.5 * scale)

      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.circle("fill", px, py, 1.5 * scale)
    end

    if not isAreaMode then
      local selLoc = state.locs and state.locs[state.sel or 1]
      if selLoc then
        local cx, cy = locToCenterPixel(selLoc, mapX, mapY, scale)
        drawMapCursor(cx, cy, scale, time, theme)
      end
    end

    drawMapCursor(mapX, mapY, scale)
    love.graphics.setScissor()

    -- Bottom Full-Width Habitats / Locations List Card
    local listY = 50 + mapBoxH + 6
    local listH = footY - listY - 6
    Layout.drawCard(0, listY, w, listH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    if isAreaMode then
      local locs = displayLocations or {}
      if #locs > 0 then
        local rowH = 30
        local itemGap = 3
        local visibleRows = math.max(1, math.floor((listH - 12) / (rowH + itemGap)))
        local scroll = state.nestScroll or 0
        local maxScroll = math.max(0, #locs - visibleRows)
        scroll = math.max(0, math.min(maxScroll, scroll))
        state.nestScroll = scroll

        local itemW = (#locs > visibleRows) and (w - 24) or (w - 16)

        for r = 1, visibleRows do
          local idx = scroll + r
          local loc = locs[idx]
          if loc then
            local iy = listY + 6 + (r - 1) * (rowH + itemGap)
            local badgeText = loc.terrain or getHabitatTerrain(loc, game, curSpecies)
            local badgeKind = (badgeText == "WATER") and "accent"
                              or (badgeText == "CAVE") and "warn"
                              or (badgeText == "DUNGEON") and "danger"
                              or (badgeText == "SAFARI") and "team"
                              or "good"
            local slotBorder = (badgeText == "WATER") and theme.colors.accent
                                or (badgeText == "CAVE") and theme.colors.hpYellow
                                or (badgeText == "DUNGEON") and theme.colors.hpRed
                                or theme.colors.hpGreen

            Layout.drawSlot(8, iy, itemW, rowH, {
              color = theme.surfaceHigh,
              borderColor = slotBorder,
              borderWidth = 1,
              radius = 5,
            })

            local name = tostring(loc.name or "WILD AREA"):gsub("[\r\n]+", " "):gsub("%s+", " "):upper()
            local bw = Layout.textWidth(badgeText, "tiny") + 16
            local bx = 8 + itemW - bw - 6
            Layout.drawText(name, 16, iy + 6, { font = "caption", color = theme.heading, bold = true, width = itemW - bw - 20, singleLine = true })
            Layout.drawBadge(bx, iy + 5, badgeText, { kind = badgeKind, font = "tiny", width = bw, height = 20 })
          end
        end

        if #locs > visibleRows then
          Layout.drawScrollBar(w - 10, listY + 6, 4, listH - 12, #locs, visibleRows, scroll)
        end
      else
        Layout.drawSlot(8, listY + 6, w - 16, listH - 12, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("AREA UNKNOWN", 18, listY + 10, { font = "caption", color = theme.colors.hpYellow, bold = true })
        if listH >= 50 then
          Layout.drawTextWrapped(
            "AREA UNKNOWN. This Pokémon cannot be found in wild encounters throughout the region.",
            18, listY + 28, w - 36, { font = "tiny", color = theme.textDim }
          )
        end
      end
    else
      local selLoc = state.locs and state.locs[state.sel or 1]
      local selName, selDetail, selHint = destinationCopy()

      local slotPad = math.max(4, math.floor((listH - 36) / 2))
      local slotH = listH - slotPad * 2
      Layout.drawSlot(8, listY + slotPad, w - 16, slotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      local nameY = listY + slotPad + (((selDetail or selHint) and 10) or math.floor((slotH - 16) / 2))
      Layout.drawText(selName:upper(), 18, nameY, { font = "headline", color = theme.heading, bold = true, width = w - 140, singleLine = true })
      if selDetail then
        Layout.drawText(selDetail:upper(), 18, nameY + 24, { font = "caption", color = theme.colors.accent, bold = true, width = w - 36, singleLine = true })
      end
      if selHint then
        Layout.drawTextWrapped(selHint, 18, nameY + (selDetail and 46 or 24), w - 36, { font = "tiny", color = theme.textDim })
      end

      if state.playerLoc and not cursorCard then
        local isHere = (selLoc and selLoc.name == state.playerLoc.name)
        local badgeLabel = isHere and "YOU ARE HERE" or "DESTINATION"
        local bWidth = Layout.textWidth(badgeLabel, "tiny") + 20
        Layout.drawBadge(w - 20 - bWidth, listY + slotPad + math.floor((slotH - 24) / 2), badgeLabel, { kind = isHere and "good" or "ghost", font = "tiny", width = bWidth, height = 24 })
      end
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANE LAYOUT
    -- =========================================================================
    local bodyH = h - 96
    local leftW = math.min(300, math.max(240, math.floor(w * 0.32)))
    local rightX = leftW + 12
    local rightW = w - rightX

    -- Left Information & Habitat List Panel
    Layout.drawCard(0, 52, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    if isAreaMode then
      Layout.drawText("KNOWN HABITAT LOCATIONS", 18, 66, { font = "caption", color = theme.colors.accent, bold = true })

      local locs = displayLocations or {}
      if #locs > 0 then
        local rowH = 38
        local itemGap = 6
        local visibleRows = math.max(1, math.floor((bodyH - 90) / (rowH + itemGap)))
        local scroll = state.nestScroll or 0
        local maxScroll = math.max(0, #locs - visibleRows)
        scroll = math.max(0, math.min(maxScroll, scroll))
        state.nestScroll = scroll

        local itemW = (#locs > visibleRows) and (leftW - 32) or (leftW - 24)

        for r = 1, visibleRows do
          local idx = scroll + r
          local loc = locs[idx]
          if loc then
            local iy = 90 + (r - 1) * (rowH + itemGap)
            local badgeText = loc.terrain or getHabitatTerrain(loc, game, curSpecies)
            local badgeKind = (badgeText == "WATER") and "accent"
                              or (badgeText == "CAVE") and "warn"
                              or (badgeText == "DUNGEON") and "danger"
                              or (badgeText == "SAFARI") and "team"
                              or "good"
            local slotBorder = (badgeText == "WATER") and theme.colors.accent
                               or (badgeText == "CAVE") and theme.colors.hpYellow
                               or (badgeText == "DUNGEON") and theme.colors.hpRed
                               or theme.colors.hpGreen

            Layout.drawSlot(12, iy, itemW, rowH, {
              color = theme.surfaceHigh,
              borderColor = slotBorder,
              borderWidth = 1,
              radius = 6,
            })

            local name = tostring(loc.name or "WILD AREA"):gsub("[\r\n]+", " "):gsub("%s+", " "):upper()
            local bw = Layout.textWidth(badgeText, "tiny") + 24
            local bx = 12 + itemW - bw - 8
            Layout.drawText(name, 22, iy + 10, { font = "button", color = theme.heading, bold = true, width = itemW - bw - 24, singleLine = true })
            Layout.drawBadge(bx, iy + 8, badgeText, { kind = badgeKind, font = "tiny", width = bw })
          end
        end

        if #locs > visibleRows then
          Layout.drawScrollBar(leftW - 14, 90, 6, bodyH - 100, #locs, visibleRows, scroll)
        end
      else
        local unknownY = 96
        Layout.drawSlot(16, unknownY, leftW - 32, 120, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("AREA UNKNOWN", 26, unknownY + 14, { font = "button", color = theme.colors.hpYellow, bold = true })
        Layout.drawTextWrapped(
          "AREA UNKNOWN. This Pokémon cannot be found in standard wild encounters throughout the region (starter, legendary, gift, trade, or evolutionary form).",
          26, unknownY + 38, leftW - 52, { font = "tiny", color = theme.textDim }
        )
      end

      local playerLoc = state.playerLoc
      if playerLoc then
        local curY = 52 + bodyH - 52
        local slotX = 12
        local slotW = leftW - 24
        local pName = tostring(playerLoc.name or "KANTO"):gsub("[\r\n]+", " "):gsub("%s+", " "):upper()
        Layout.drawSlot(slotX, curY, slotW, 40, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText("CURRENT POSITION", 22, curY + 6, { font = "tiny", color = theme.textDim })
        Layout.drawText(pName, 22, curY + 20, { font = "caption", color = theme.heading, bold = true, width = slotW - 60, singleLine = true })
        local youW = Layout.textWidth("YOU", "tiny") + 24
        local youX = slotX + slotW - youW - 8
        Layout.drawBadge(youX, curY + 10, "YOU", { kind = "accent", font = "tiny", width = youW })
      end
    else
      local selLoc = state.locs and state.locs[state.sel or 1]
      local selName, selDetail, selHint = destinationCopy()
      local infoH = (selDetail or selHint) and 132 or 80

      Layout.drawText("SELECTED DESTINATION", 18, 66, { font = "caption", color = theme.colors.accent, bold = true })
      Layout.drawSlot(16, 90, leftW - 32, infoH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
      Layout.drawText(selName:upper(), 26, 104, { font = "headline", color = theme.heading, bold = true, width = leftW - 60, singleLine = true })
      if selDetail then
        Layout.drawText(selDetail:upper(), 26, 132, { font = "caption", color = theme.colors.accent, bold = true, width = leftW - 60, singleLine = true })
      end
      if selHint then
        Layout.drawTextWrapped(selHint, 26, selDetail and 156 or 132, leftW - 60, { font = "body", color = theme.textDim })
      end

      if state.playerLoc and not cursorCard then
        local isHere = (selLoc and selLoc.name == state.playerLoc.name)
        Layout.drawBadge(26, 136, isHere and "YOU ARE HERE" or "TARGET", { kind = isHere and "good" or "ghost" })
      end

      if isFlyMode then
        local flyTipY = 90 + infoH + 12
        Layout.drawSlot(16, flyTipY, leftW - 32, 100, { color = theme.surfaceHigh, borderColor = theme.borderStrong, radius = 6 })
        Layout.drawText("FLIGHT CONTROLS", 26, flyTipY + 12, { font = "caption", color = theme.colors.accent, bold = true })
        Layout.drawTextWrapped("Press A to take flight and travel directly to the highlighted town or city.", 26, flyTipY + 34, leftW - 52, { font = "body", color = theme.textDim })
      end
    end

    -- Right Map Canvas & Graphic Visualizer
    Layout.drawCard(rightX, 52, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local pad = 10
    local slotX = rightX + pad
    local slotY = 52 + pad
    local slotW = rightW - pad * 2
    local slotH = bodyH - pad * 2

    local baseW, baseH = mapBaseW, mapBaseH
    local scale = math.min(slotW / baseW, slotH / baseH)

    local mapX = slotX + math.floor((slotW - baseW * scale) / 2)
    local mapY = slotY + math.floor((slotH - baseH * scale) / 2)

    state._mapGeometry = {
      mapX = mapX, mapY = mapY, drawW = slotW, drawH = slotH, scale = scale,
      isHoenn = isHoenn, activeRegion = activeRegion, mapKind = mapKind,
    }

    Layout.drawSlot(slotX, slotY, slotW, slotH, {
      color = { 0.05, 0.07, 0.10, 1.0 },
      borderColor = theme.borderStrong,
      borderWidth = 1.5,
      radius = 6,
    })

    clipSlot(slotX, slotY, slotW, slotH)
    drawRegionalMap(mapX, mapY, scale, slotX, slotY, slotW, slotH)
    drawFrlgDungeonIcons(mapX, mapY, scale)

    if isAreaMode and activeNests and #activeNests > 0 then
      local pulse = 0.5 + 0.5 * math.sin(time * 3.5)
      for _, loc in ipairs(activeNests) do
        if isHoenn or loc.mapId == "hoenn" then
          local lx = loc.x or (loc.coords and loc.coords.x) or 0
          local ly = loc.y or (loc.coords and loc.coords.y) or 0
          local rx = mapX + lx * 8 * scale
          local ry = mapY + ly * 8 * scale
          local rw = 8 * scale
          local rh = 8 * scale

          -- Crisp luminous route tile fill
          love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.38 + 0.16 * pulse)
          love.graphics.rectangle("fill", rx, ry, rw, rh)

          -- Sleek boundary outline
          love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.75 + 0.20 * pulse)
          love.graphics.setLineWidth(1)
          love.graphics.rectangle("line", rx + 0.5, ry + 0.5, rw - 1, rh - 1)

          if loc.isSpecial then
            local cx, cy = locToCenterPixel(loc, mapX, mapY, scale)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", cx, cy, 2 * scale)
          end
        else
          local cx, cy = locToCenterPixel(loc, mapX, mapY, scale)
          local shape = mapKind == "frlg-dex" and loc.marker and loc.marker.shape
          if shape then
            -- Same sprite and origin as the FRLG dex: top-left at (x - 32, y), scaled with the map.
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.scale(scale, scale)
            pcall(function()
              local Chrome = require("src.ui.game3.pokedex_chrome")
              if Chrome.drawAreaMarker then Chrome.drawAreaMarker(shape, 0, 0) end
            end)
            love.graphics.pop()
          else
            local haloR = (6 + 3 * pulse) * scale
            love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.35 + 0.25 * pulse)
            love.graphics.circle("fill", cx, cy, haloR)

            love.graphics.setColor(theme.colors.hpGreen[1], theme.colors.hpGreen[2], theme.colors.hpGreen[3], 0.95)
            love.graphics.circle("fill", cx, cy, 2.5 * scale)

            love.graphics.setColor(1, 1, 1, 0.90)
            love.graphics.circle("fill", cx, cy, 1.2 * scale)
          end
        end
      end
    elseif isAreaMode and (not activeNests or #activeNests == 0) then
      local badgeW = 160
      local badgeH = 30
      local bx = slotX + math.floor((slotW - badgeW) / 2)
      local by = slotY + math.floor((slotH - badgeH) / 2)
      Layout.drawBadge(bx, by, "AREA UNKNOWN", { kind = "warn", font = "caption", width = badgeW, height = badgeH })
    end

    if state.playerLoc then
      local px, py = locToCenterPixel(state.playerLoc, mapX, mapY, scale)
      love.graphics.setColor(theme.colors.hpRed[1], theme.colors.hpRed[2], theme.colors.hpRed[3], 0.40)
      love.graphics.circle("fill", px, py, 8 * scale)

      love.graphics.setColor(theme.colors.hpRed[1], theme.colors.hpRed[2], theme.colors.hpRed[3], 1.0)
      love.graphics.circle("fill", px, py, 3.5 * scale)

      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.circle("fill", px, py, 1.5 * scale)
    end

    if not isAreaMode then
      local selLoc = state.locs and state.locs[state.sel or 1]
      if selLoc then
        local cx, cy = locToCenterPixel(selLoc, mapX, mapY, scale)
        drawMapCursor(cx, cy, scale, time, theme)
      end
    end

    drawMapCursor(mapX, mapY, scale)
    love.graphics.setScissor()
  end

  -- 4. Bottom Button Hints Footer Bar
  local hints
  if isPokenav then
    if state.mode ~= "card" then
      hints = {
        { key = "◄ ►", label = "Cycle Cards" },
        { key = "A",   label = "Inspect Map", primary = true },
        { key = "B",   label = "Turn Off PokéNav" },
      }
    else
      hints = {
        { key = "▲ ▼ ◄ ►", label = "Pan Map", primary = true },
        { key = "B",       label = "Back to Cards" },
      }
    end
  else
    hints = isAreaMode and (canSwapRegion and {
      { key = "◄ ►", label = "Swap Region", primary = true },
      { key = "▲ ▼", label = "Scroll Locations" },
      { key = "B", label = "Back to Pokédex" },
    } or {
      { key = "▲ ▼", label = "Scroll Locations", primary = true },
      { key = "B", label = "Back to Pokédex" },
    }) or (isFlyMode and {
      { key = "▲ ▼", label = "Town", primary = true },
      { key = "A", label = "Fly" },
      { key = "B", label = "Cancel" },
    } or {
      { key = "▲ ▼", label = "Explore", primary = true },
      { key = "B", label = "Close" },
    })
  end

  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16, gap = isNarrow and 10 or 20 })
end

function TownMapRenderer.screenToTile(screenX, screenY, mapX, mapY, scale, isHoenn)
  scale = scale or 1
  local tx = math.floor((screenX - mapX) / (8 * scale))
  local ty = math.floor((screenY - mapY) / (8 * scale))
  return tx, ty
end

return TownMapRenderer
