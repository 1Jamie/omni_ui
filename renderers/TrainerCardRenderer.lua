-- OmniUI Trainer Card Renderer
-- Player passport overview and 8-badge achievement showcase grid with vector typography,
-- authentic gym badge / leader face sprite rendering, and trainer portrait avatar.

local Layout = require("mods.omni_ui.core.Layout")
local AdapterResolver = require("mods.omni_ui.adapters.AdapterResolver")

local TrainerCardRenderer = {}

local _cachedGbaAssets = {}
local function readGbaCacheFile(path, preferredVer)
  local cacheKey = (preferredVer or "global") .. ":" .. path
  if _cachedGbaAssets[cacheKey] ~= nil and _cachedGbaAssets[cacheKey] ~= false then
    return _cachedGbaAssets[cacheKey]
  end

  local CacheBlob = nil
  local okBlob, cb = pcall(require, "src.import.CacheBlob")
  if okBlob and cb then CacheBlob = cb end

  -- 1. Try CacheFs
  local okFs, CacheFs = pcall(require, "src.import.CacheFs")
  if okFs and CacheFs then
    if CacheFs.readActive then
      local d = CacheFs.readActive(path)
      if d and #d > 0 then
        _cachedGbaAssets[cacheKey] = d
        return d
      end
    end
    if preferredVer and CacheFs.readAt then
      local d = CacheFs.readAt(preferredVer .. "/" .. path)
      if d and #d > 0 then
        _cachedGbaAssets[cacheKey] = d
        return d
      end
    end
    local prefix = ""
    pcall(function() prefix = require("src.core.GameVersion").cachePrefix() end)
    if CacheFs.readAt and prefix ~= "" then
      local d = CacheFs.readAt(prefix .. path)
      if d and #d > 0 then
        _cachedGbaAssets[cacheKey] = d
        return d
      end
    end
    if CacheFs.read then
      local d = CacheFs.read(path)
      if d and #d > 0 then
        _cachedGbaAssets[cacheKey] = d
        return d
      end
    end
  end

  -- 2. Try love.filesystem via CacheBlob
  if CacheBlob and love and love.filesystem and love.filesystem.read then
    local d = CacheBlob.readFs(path)
    if d and #d > 0 then
      _cachedGbaAssets[cacheKey] = d
      return d
    end
    local alt = "data/generated/gba/" .. (path:gsub("^data/generated/gba/", ""))
    d = CacheBlob.readFs(alt)
    if d and #d > 0 then
      _cachedGbaAssets[cacheKey] = d
      return d
    end
    if preferredVer then
      d = CacheBlob.readFs(preferredVer .. "/" .. path)
      if d and #d > 0 then
        _cachedGbaAssets[cacheKey] = d
        return d
      end
    end
  end

  -- 3. Direct filesystem check in love save directory / local store
  if CacheBlob then
    local saveDir = (love and love.filesystem and love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory())
      or (os.getenv("HOME") and (os.getenv("HOME") .. "/.local/share/love/pokemon-love2d"))
    if saveDir then
      local candidates = {}
      local isRsePref = (preferredVer == "emerald" or preferredVer == "ruby" or preferredVer == "sapphire")
      if isRsePref then
        candidates[#candidates + 1] = saveDir .. "/emerald/" .. path
        candidates[#candidates + 1] = saveDir .. "/ruby/" .. path
        candidates[#candidates + 1] = saveDir .. "/sapphire/" .. path
        candidates[#candidates + 1] = saveDir .. "/firered/" .. path
        candidates[#candidates + 1] = saveDir .. "/leafgreen/" .. path
      else
        candidates[#candidates + 1] = saveDir .. "/firered/" .. path
        candidates[#candidates + 1] = saveDir .. "/leafgreen/" .. path
        candidates[#candidates + 1] = saveDir .. "/emerald/" .. path
        candidates[#candidates + 1] = saveDir .. "/ruby/" .. path
        candidates[#candidates + 1] = saveDir .. "/sapphire/" .. path
      end
      candidates[#candidates + 1] = path

      for _, sp in ipairs(candidates) do
        local f = io.open(sp, "rb")
        if f then
          local raw = f:read("*a")
          f:close()
          local d = CacheBlob.decode(path, raw)
          if d and #d > 0 then
            _cachedGbaAssets[cacheKey] = d
            return d
          end
        end
      end
    end
  end

  return nil
end

local function quads16(img, count, stride, x0, y0)
  local q = {}
  local iw, ih = img:getDimensions()
  for i = 0, count - 1 do
    q[i] = love.graphics.newQuad(x0 or 0, (y0 or 0) + i * stride, 16, 16, iw, ih)
  end
  return q
end

local function resolveBadges(game, state)
  if state and state.badges and state.faces then
    return state.badges, state.faces, state.nums
  end

  local adapter = AdapterResolver.resolve(game)
  local info = (adapter and adapter.getPlayerInfo and adapter:getPlayerInfo()) or {}
  local isGen3 = (info.generation == 3) or (adapter and adapter.generation == 3)
    or (info.region == "HOENN") or (state and (state.region == "HOENN" or state._rse == true))
    or (adapter and adapter.gameVersion and (
      adapter.gameVersion == "firered" or adapter.gameVersion == "leafgreen"
      or adapter.gameVersion == "emerald" or adapter.gameVersion == "ruby" or adapter.gameVersion == "sapphire"
    )) or (state and (state.isGen3 == true or state._card ~= nil or state.cardFace ~= nil))
    or (package.loaded["src.ui.game3.trainer_card"] ~= nil and (state == package.loaded["src.ui.game3.trainer_card"] or (state and state.draw == package.loaded["src.ui.game3.trainer_card"].draw)))

  if isGen3 then
    local isRse = (info.region == "HOENN") or (state and (state.region == "HOENN" or state._rse == true))
      or (adapter and adapter.gameVersion and (adapter.gameVersion == "emerald" or adapter.gameVersion == "ruby" or adapter.gameVersion == "sapphire"))
    local prefVer = isRse and "emerald" or "firered"

    local raw = readGbaCacheFile("data/generated/gba/trainer_card/badges.rgba", prefVer)
    if raw and #raw >= 128 * 16 * 4 and love and love.image and love.graphics then
      local okData, imgData = pcall(love.image.newImageData, 128, 16, "rgba8", raw)
      if okData and imgData then
        local okImg, img = pcall(love.graphics.newImage, imgData)
        if okImg and img then
          if img.setFilter then img:setFilter("nearest", "nearest") end
          local bQuads = {}
          for i = 0, 7 do
            bQuads[i] = love.graphics.newQuad(i * 16, 0, 16, 16, 128, 16)
          end
          local badges = { img = img, quads = bQuads }
          local faces = nil
          if not isRse and info.region ~= "HOENN" and (not state or (state.region ~= "HOENN" and not state._rse)) then
            local badgePath = "assets/generated/trainer_card/badges.png"
            local okF, fImg = pcall(love.graphics.newImage, badgePath)
            if okF and fImg then
              faces = { img = fImg, quads = quads16(fImg, 8, 32, 0, 0) }
            end
          end
          return badges, faces, nil
        end
      end
    end
  end

  local Assets = nil
  local okAssets, A = pcall(require, "src.render.Assets")
  if okAssets and A then Assets = A end

  local badgePath = Assets and Assets.resolve and Assets.resolve("assets/generated/trainer_card/badges.png") or "assets/generated/trainer_card/badges.png"
  local ok, img = pcall(love.graphics.newImage, badgePath)
  local badges, faces, nums = nil, nil, nil
  if ok and img then
    faces = { img = img, quads = quads16(img, 8, 32, 0, 0) }
    badges = { img = img, quads = quads16(img, 8, 32, 0, 16) }
  end

  local numPath = Assets and Assets.resolve and Assets.resolve("assets/generated/trainer_card/badge_numbers.png") or "assets/generated/trainer_card/badge_numbers.png"
  local okN, nImg = pcall(love.graphics.newImage, numPath)
  if okN and nImg then
    local iw, ih = nImg:getDimensions()
    nums = { img = nImg, quads = {} }
    for i = 0, 7 do
      nums.quads[i] = love.graphics.newQuad((i % 2) * 8, math.floor(i / 2) * 8, 8, 8, iw, ih)
    end
  end

  return badges, faces, nums
end

local function resolvePlayerPic(game, state)
  if state and state.pic then
    return state.pic, state.picQuad, state.picW or 40, state.picH or 56
  end

  local adapter = AdapterResolver.resolve(game)
  local info = (adapter and adapter.getPlayerInfo and adapter:getPlayerInfo()) or {}
  local isGen3 = (info.generation == 3) or (adapter and adapter.generation == 3)
    or (info.region == "HOENN") or (state and (state.region == "HOENN" or state._rse == true))
    or (adapter and adapter.gameVersion and (
      adapter.gameVersion == "firered" or adapter.gameVersion == "leafgreen"
      or adapter.gameVersion == "emerald" or adapter.gameVersion == "ruby" or adapter.gameVersion == "sapphire"
    )) or (state and (state.isGen3 == true or state._card ~= nil or state.cardFace ~= nil))
    or (package.loaded["src.ui.game3.trainer_card"] ~= nil and (state == package.loaded["src.ui.game3.trainer_card"] or (state and state.draw == package.loaded["src.ui.game3.trainer_card"].draw)))

  if isGen3 then
    local female = (info.gender == "FEMALE" or info.gender == 1) or (state and state._card and state._card.female == true)
    local isRse = (info.region == "HOENN") or (state and (state.region == "HOENN" or state._rse == true))
      or (adapter and adapter.gameVersion and (adapter.gameVersion == "emerald" or adapter.gameVersion == "ruby" or adapter.gameVersion == "sapphire"))

    local picId = isRse and (female and 90 or 89) or (female and 136 or 135)
    local prefVer = isRse and "emerald" or "firered"
    local raw = readGbaCacheFile(string.format("data/generated/gba/trainers/front/%d.rgba", picId), prefVer)
    if raw and #raw >= 64 * 64 * 4 and love and love.image and love.graphics then
      local okData, imgData = pcall(love.image.newImageData, 64, 64, "rgba8", raw)
      if okData and imgData then
        local okImg, img = pcall(love.graphics.newImage, imgData)
        if okImg and img then
          if img.setFilter then img:setFilter("nearest", "nearest") end
          local quad = love.graphics.newQuad(0, 0, 64, 64, 64, 64)
          return img, quad, 64, 64
        end
      end
    end
  end

  local okSprites, Sprites = pcall(require, "src.pokemon.Sprites")
  if okSprites and Sprites and game and game.data then
    local path, _ = Sprites.playerPath(game.data, "front", { kind = "trainer_card" })
    if path then
      local Assets = nil
      local okAssets, A = pcall(require, "src.render.Assets")
      if okAssets and A then Assets = A end
      local resolved = Assets and Assets.resolve and Assets.resolve(path) or path
      local ok, img = pcall(love.graphics.newImage, resolved)
      if ok and img then
        local pw, ph = img:getDimensions()
        local picW = math.max(0, math.min(40, pw))
        local picH = math.min(56, ph)
        local quad = love.graphics.newQuad(0, 0, picW, picH, pw, ph)
        return img, quad, picW, picH
      end
    end
  end

  local ok, img = pcall(love.graphics.newImage, "assets/generated/trainer_card/red.png")
  if ok and img then
    local pw, ph = img:getDimensions()
    local quad = love.graphics.newQuad(0, 0, pw, ph, pw, ph)
    return img, quad, pw, ph
  end

  return nil, nil, 0, 0
end

local JOHTO_LEADERS = { "FALKNER", "BUGSY", "WHITNEY", "MORTY", "CHUCK", "JASMINE", "PRYCE", "CLAIR" }
local KANTO_LEADERS = { "BROCK", "MISTY", "LT. SURGE", "ERIKA", "KOGA", "SABRINA", "BLAINE", "GIOVANNI" }
local GSC_KANTO_LEADERS = { "BROCK", "MISTY", "LT. SURGE", "ERIKA", "JANINE", "SABRINA", "BLAINE", "BLUE" }
local HOENN_LEADERS_RS = { "ROXANNE", "BRAWLY", "WATTSON", "FLANNERY", "NORMAN", "WINONA", "TATE & LIZA", "WALLACE" }
local HOENN_LEADERS_EM = { "ROXANNE", "BRAWLY", "WATTSON", "FLANNERY", "NORMAN", "WINONA", "TATE & LIZA", "JUAN" }

local function isBadgeEarned(game, badgeIndex, region, info)
  if info and info.badgeFlags and info.badgeFlags[badgeIndex] ~= nil then
    return info.badgeFlags[badgeIndex] == true
  end

  if info and info.johtoBadgeFlags and info.kantoBadgeFlags then
    if region == "KANTO" then
      return info.kantoBadgeFlags[badgeIndex] == true
    else
      return info.johtoBadgeFlags[badgeIndex] == true
    end
  end

  local save = game and game.save
  if not save then return false end

  local Badges = nil
  local okB, B = pcall(require, "src.inventory.Badges")
  if okB and B then Badges = B end

  if save.inventory and Badges then
    local list = Badges.list(game.data)
    local entry = list and list[badgeIndex]
    if entry then
      local itemKey = Badges.itemFor(entry)
      if save.inventory[itemKey] then return true end
    end
  end

  local adapter = AdapterResolver.resolve(game)
  local pInfo = info or (adapter and adapter:getPlayerInfo()) or {}
  if (pInfo.badges or 0) >= badgeIndex then
    return true
  end

  return false
end

function TrainerCardRenderer.draw(game, state, w, h, theme, animProgress)
  local adapter = AdapterResolver.resolve(game)
  local info = adapter:getPlayerInfo()

  local isDualRegion = (info.maxBadges == 16) or (info.johtoBadgeFlags ~= nil and info.kantoBadgeFlags ~= nil)
  state = state or {}
  local activeRegion = state.cardFace or state.region or (isDualRegion and "JOHTO" or (info.region or "KANTO"))
  if activeRegion ~= "JOHTO" and activeRegion ~= "KANTO" and activeRegion ~= "HOENN" then
    activeRegion = isDualRegion and "JOHTO" or "KANTO"
  end

  local badgesSheet, facesSheet, numsSheet = resolveBadges(game, state)
  local picImg, picQuad, picW, picH = resolvePlayerPic(game, state)

  local badgeNames = (activeRegion == "HOENN")
    and (info.badgeNames or { "STONE", "KNUCKLE", "DYNAMO", "HEAT", "BALANCE", "FEATHER", "MIND", "RAIN" })
    or ((activeRegion == "JOHTO")
      and (info.johtoBadgeNames or { "ZEPHYR", "HIVE", "PLAIN", "FOG", "STORM", "MINERAL", "GLACIER", "RISING" })
      or (info.kantoBadgeNames or { "BOULDER", "CASCADE", "THUNDER", "RAINBOW", "SOUL", "MARSH", "VOLCANO", "EARTH" }))

  local isEmerald = false
  if activeRegion == "HOENN" then
    local ver = (adapter and adapter.gameVersion) or (info and info.gameVersion) or (state._rse and "emerald")
    if not ver then pcall(function() ver = require("src.core.GameVersion").get() end) end
    if ver and tostring(ver):lower():find("emerald") then isEmerald = true end
  end
  local gymLeaders = (activeRegion == "HOENN")
    and (isEmerald and HOENN_LEADERS_EM or HOENN_LEADERS_RS)
    or ((activeRegion == "JOHTO")
      and JOHTO_LEADERS
      or (isDualRegion and GSC_KANTO_LEADERS or KANTO_LEADERS))

  local activeEarned = 0
  for i = 1, #badgeNames do
    if isBadgeEarned(game, i, activeRegion, info) then
      activeEarned = activeEarned + 1
    end
  end

  local totalEarned = (info.johtoBadges and (info.johtoBadges + (info.kantoBadges or 0))) or info.badges or activeEarned
  local maxTotalBadges = isDualRegion and 16 or 8

  local ctx = Layout.getContext(w, h)
  local isNarrow = (w < 600) or ctx.isPortrait

  -- 1. Top Header Card
  Layout.drawCard(0, 0, w, 44, { color = theme.surface, borderColor = theme.border, radius = 8 })
  Layout.drawText("TRAINER PASSPORT", 18, 12, { font = "headline", color = theme.heading, bold = true })
  Layout.drawBadge(w - (isNarrow and 110 or 150), 10, ("ID %05d"):format(info.id or 0), { kind = "ghost", font = "caption", height = 24 })

  local footY = h - 38

  if isNarrow then
    -- =========================================================================
    -- PORTRAIT / COMPACT MOBILE STACKED PASSPORT + BADGES SHOWCASE
    -- =========================================================================
    local profileH = 146
    Layout.drawCard(0, 50, w, profileH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    -- Left Avatar Container
    local frameX = 12
    local frameY = 58
    local frameW = 74
    local frameH = profileH - 16
    Layout.drawCard(frameX, frameY, frameW, frameH, {
      color = theme.surfaceHigh,
      borderColor = theme.borderStrong,
      radius = 6,
    })

    Layout.drawPedestal(frameX + math.floor(frameW / 2), frameY + frameH - 12, 22, 5, {
      color = theme.surface,
      borderColor = theme.colors.accentDim,
    })

    if picImg and picQuad then
      local scale = (picW == 64) and 1.1 or 1.45
      local dw = math.floor(picW * scale)
      local dh = math.floor(picH * scale)
      local dx = frameX + math.floor((frameW - dw) / 2)
      local dy = frameY + math.floor((frameH - dh) / 2)
      if picW ~= 64 then
        local visualCenterX = (picW == 40) and 23 or (picW / 2)
        dx = frameX + math.floor(frameW / 2) - math.floor(visualCenterX * scale)
        dy = frameY + math.floor((frameH - dh) / 2) - 4
      end
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(picImg, picQuad, dx, dy, 0, scale, scale)
    end

    -- Right Profile Metadata
    local rx = frameX + frameW + 12
    local rw = w - rx - 8
    Layout.drawText(info.name, rx, 58, { font = "headline", color = theme.heading, bold = true })

    local rankTitle = (totalEarned == maxTotalBadges) and "CHAMPION" or (totalEarned >= 8) and "ELITE RANK" or (totalEarned >= 4) and "CHALLENGER" or "ROOKIE"
    Layout.drawBadge(w - 96, 58, rankTitle, { kind = (totalEarned == maxTotalBadges) and "gold" or "accent", font = "tiny", width = 84 })

    local colW = math.floor(rw / 2)
    Layout.drawText("MONEY", rx, 88, { font = "tiny", color = theme.textDim })
    Layout.drawText(("¥%d"):format(info.money or 0), rx, 102, { font = "button", color = theme.colors.hpYellow, bold = true })

    Layout.drawText("PLAY TIME", rx + colW, 88, { font = "tiny", color = theme.textDim })
    Layout.drawText(info.playTimeString or "00:00", rx + colW, 102, { font = "button", color = theme.heading, bold = true })

    Layout.drawText("POKÉDEX", rx, 124, { font = "tiny", color = theme.textDim })
    Layout.drawText(("%d OWNED / %d SEEN"):format(info.pokedex and info.pokedex.owned or 0, info.pokedex and info.pokedex.seen or 0), rx, 138, { font = "tiny", color = theme.colors.accent, bold = true })

    -- Bottom Badges Showcase Card
    local badgeCardY = 50 + profileH + 6
    local badgeCardH = footY - badgeCardY - 6
    Layout.drawCard(0, badgeCardY, w, badgeCardH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local titleLabel = isDualRegion and (activeRegion .. " GYM BADGES") or "LEAGUE GYM BADGES"
    Layout.drawText(titleLabel, 14, badgeCardY + 8, { font = "headline", color = theme.heading, bold = true })

    if isDualRegion then
      local tabW = 60
      local johtoSel = (activeRegion == "JOHTO")
      Layout.drawButton(w - 140, badgeCardY + 6, tabW, 22, "JOHTO", { kind = johtoSel and "primary" or "ghost", font = "tiny" })
      Layout.drawButton(w - 74, badgeCardY + 6, tabW, 22, "KANTO", { kind = (not johtoSel) and "primary" or "ghost", font = "tiny" })
    else
      Layout.drawBadge(w - 96, badgeCardY + 8, ("%d/8 EARNED"):format(activeEarned), {
        kind = (activeEarned == 8) and "gold" or (activeEarned > 0) and "accent" or "ghost",
        font = "tiny",
        width = 84,
      })
    end

    local gridX = 8
    local gridY = badgeCardY + 34
    local gridCols = 4
    local colGap = 6
    local rowGapY = 6
    local cellW = math.floor((w - 16 - (gridCols - 1) * colGap) / gridCols)
    local cellH = math.floor((badgeCardH - 44 - rowGapY) / 2)

    for i = 1, #badgeNames do
      local isEarned = isBadgeEarned(game, i, activeRegion, info)
      local col = (i - 1) % gridCols
      local row = math.floor((i - 1) / gridCols)
      local bx = gridX + col * (cellW + colGap)
      local by = gridY + row * (cellH + rowGapY)

      if isEarned then
        Layout.drawCard(bx, by, cellW, cellH, {
          color = theme.surfaceHigh,
          borderColor = theme.colors.hpYellow,
          borderWidth = 1,
          radius = 6,
        })
        Layout.drawBadge(bx + 4, by + 4, ("#%d"):format(i), { kind = "gold", font = "tiny" })

        local pedSize = math.min(32, cellH - 36)
        local pedX = bx + math.floor((cellW - pedSize) / 2)
        local pedY = by + 20
        Layout.drawCard(pedX, pedY, pedSize, pedSize, {
          color = theme.surface,
          borderColor = theme.colors.hpYellow,
          radius = 4,
        })

        if badgesSheet and badgesSheet.quads and badgesSheet.quads[i - 1] and activeRegion ~= "JOHTO" then
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(badgesSheet.img, badgesSheet.quads[i - 1], pedX + math.floor((pedSize - 16) / 2), pedY + math.floor((pedSize - 16) / 2))
        else
          Layout.drawText("★", pedX, pedY + 4, { font = "button", color = theme.colors.hpYellow, align = "center", width = pedSize, bold = true })
        end

        local bName = badgeNames[i] or ("BADGE " .. i)
        Layout.drawText(bName, bx + 2, by + cellH - 14, { font = "tiny", color = theme.heading, bold = true, align = "center", width = cellW - 4 })
      else
        Layout.drawSlot(bx, by, cellW, cellH, {
          color = theme.surface,
          borderColor = theme.border,
          radius = 6,
        })
        Layout.drawBadge(bx + 4, by + 4, ("#%d"):format(i), { kind = "ghost", font = "tiny" })
        local leaderName = gymLeaders[i] or ("GYM " .. i)
        if activeRegion == "KANTO" and i == 8 then
          leaderName = "???"
        end
        Layout.drawText(leaderName, bx + 2, by + cellH - 14, { font = "tiny", color = theme.textMuted, align = "center", width = cellW - 4 })
      end
    end
  else
    -- =========================================================================
    -- LANDSCAPE / STANDARD 2-PANEL LAYOUT
    -- =========================================================================
    local bodyH = h - 96
    local leftW = math.floor(w * 0.38)
    Layout.drawCard(0, 52, leftW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local avatarSlotH = 124
    Layout.drawSlot(12, 64, leftW - 24, avatarSlotH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 8 })

    local frameX = 20
    local frameY = 72
    local frameW = 82
    local frameH = 108
    Layout.drawCard(frameX, frameY, frameW, frameH, {
      color = theme.surface,
      borderColor = theme.borderStrong,
      radius = 6,
    })

    Layout.drawPedestal(frameX + math.floor(frameW / 2), frameY + frameH - 12, 26, 6, {
      color = theme.surfaceHigh,
      borderColor = theme.colors.accentDim,
    })

    if picImg and picQuad then
      local scale = (picW == 64) and 1.35 or 1.65
      local dw = math.floor(picW * scale)
      local dh = math.floor(picH * scale)
      local dx = frameX + math.floor((frameW - dw) / 2)
      local dy = frameY + math.floor((frameH - dh) / 2)
      if picW ~= 64 then
        local visualCenterX = (picW == 40) and 23 or (picW / 2)
        dx = frameX + math.floor(frameW / 2) - math.floor(visualCenterX * scale)
        dy = frameY + math.floor((frameH - dh) / 2) - 3
      end
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(picImg, picQuad, dx, dy, 0, scale, scale)
    end

    local textX = frameX + frameW + 14
    Layout.drawText(info.name, textX, 76, { font = "title", color = theme.heading, bold = true })
    local leagueSub = isDualRegion and "KANTO & JOHTO LEAGUES" or (tostring(info.region or "KANTO"):upper() .. " LEAGUE")
    Layout.drawText(leagueSub, textX, 106, { font = "tiny", color = theme.colors.accent, bold = true })

    local rankTitle = (totalEarned == maxTotalBadges) and "CHAMPION" or (totalEarned >= 8) and "ELITE RANK" or (totalEarned >= 4) and "CHALLENGER" or "ROOKIE"
    local rankKind = (totalEarned == maxTotalBadges) and "gold" or (totalEarned >= 8) and "accent" or "ghost"
    Layout.drawBadge(textX, 134, rankTitle, { kind = rankKind, font = "caption", height = 24 })

    local py = 196
    local rowGap = 8
    local rowH = 46
    local badgeSummary = isDualRegion and ("%d / 16 TOTAL"):format(totalEarned) or ("%d / 8 EARNED"):format(activeEarned)
    local rows = {
      { "WALLET MONEY", ("¥%d"):format(info.money or 0), (info.money or 0) > 0 and theme.colors.hpYellow or theme.heading },
      { "TIME PLAYED", info.playTimeString or "00:00", theme.heading },
      { "POKÉDEX DATA", ("%d OWNED / %d SEEN"):format(info.pokedex and info.pokedex.owned or 0, info.pokedex and info.pokedex.seen or 0), theme.colors.accent },
      { "BADGES PROGRESS", badgeSummary, (totalEarned >= 8) and theme.colors.hpYellow or theme.colors.accent },
    }

    for _, r in ipairs(rows) do
      if py + rowH <= 52 + bodyH - 10 then
        Layout.drawSlot(12, py, leftW - 24, rowH, { color = theme.surfaceHigh, borderColor = theme.border, radius = 6 })
        Layout.drawText(r[1], 22, py + 6, { font = "tiny", color = theme.textDim })
        Layout.drawText(r[2], 22, py + 22, { font = "button", color = r[3], bold = true })
        py = py + rowH + rowGap
      end
    end

    -- Right: League Gym Badges Showcase Card
    local rightX = leftW + 12
    local rightW = w - rightX
    Layout.drawCard(rightX, 52, rightW, bodyH, { color = theme.surface, borderColor = theme.border, radius = 8 })

    local titleHeader = isDualRegion and (activeRegion .. " GYM BADGES") or "LEAGUE GYM BADGES"
    Layout.drawText(titleHeader, rightX + 16, 66, { font = "headline", color = theme.heading, bold = true })

    if isDualRegion then
      local tabW = 76
      local johtoSel = (activeRegion == "JOHTO")
      Layout.drawButton(rightX + rightW - 170, 62, tabW, 26, "JOHTO", { kind = johtoSel and "primary" or "ghost", font = "tiny", selected = johtoSel })
      Layout.drawButton(rightX + rightW - 88, 62, tabW, 26, "KANTO", { kind = (not johtoSel) and "primary" or "ghost", font = "tiny", selected = (not johtoSel) })
    else
      Layout.drawBadge(rightX + rightW - 120, 64, ("%d / 8 EARNED"):format(activeEarned), {
        kind = (activeEarned == 8) and "gold" or (activeEarned > 0) and "accent" or "ghost",
        font = "caption",
        height = 24,
      })
    end

    local subTitle = "OFFICIAL INDIGO GYM LEADER SANCTIONED SEALS"
    if activeRegion == "JOHTO" then
      subTitle = "OFFICIAL JOHTO GYM LEADER SANCTIONED SEALS"
    elseif activeRegion == "HOENN" then
      subTitle = "OFFICIAL HOENN GYM LEADER SANCTIONED SEALS"
    end
    Layout.drawText(subTitle, rightX + 16, 92, { font = "tiny", color = theme.textDim })

    local gridX = rightX + 14
    local gridY = 112
    local gridCols = 4
    local colGap = 8
    local rowGapY = 10
    local cellW = math.floor((rightW - 28 - (gridCols - 1) * colGap) / gridCols)
    local cellH = math.floor((bodyH - (gridY - 52) - 14 - rowGapY) / 2)

    for i = 1, #badgeNames do
      local isEarned = isBadgeEarned(game, i, activeRegion, info)
      local col = (i - 1) % gridCols
      local row = math.floor((i - 1) / gridCols)
      local bx = gridX + col * (cellW + colGap)
      local by = gridY + row * (cellH + rowGapY)

      if isEarned then
        Layout.drawCard(bx, by, cellW, cellH, {
          color = theme.surfaceHigh,
          borderColor = theme.colors.hpYellow,
          borderWidth = 1,
          radius = 8,
        })
        Layout.drawBadge(bx + 8, by + 8, ("#%d"):format(i), { kind = "gold", font = "tiny" })

        local pedSize = 44
        local pedX = bx + math.floor((cellW - pedSize) / 2)
        local pedY = by + 28
        Layout.drawCard(pedX, pedY, pedSize, pedSize, {
          color = theme.surface,
          borderColor = theme.colors.hpYellow,
          radius = 6,
        })

        if badgesSheet and badgesSheet.quads and badgesSheet.quads[i - 1] and activeRegion ~= "JOHTO" then
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(badgesSheet.img, badgesSheet.quads[i - 1], pedX + 6, pedY + 6, 0, 2, 2)
        else
          Layout.drawText("★", pedX, pedY + 10, { font = "title", color = theme.colors.hpYellow, align = "center", width = pedSize, bold = true })
        end

        Layout.drawText(badgeNames[i], bx, by + 78, { font = "button", color = theme.heading, align = "center", width = cellW, bold = true })
        Layout.drawBadge(bx + math.floor((cellW - 64) / 2), by + 102, "CLAIMED", { kind = "good", font = "tiny", width = 64 })
      else
        Layout.drawSlot(bx, by, cellW, cellH, {
          color = theme.surface,
          borderColor = theme.border,
          borderWidth = 1,
          radius = 8,
        })
        Layout.drawBadge(bx + 8, by + 8, ("#%d"):format(i), { kind = "ghost", font = "tiny" })

        local pedSize = 44
        local pedX = bx + math.floor((cellW - pedSize) / 2)
        local pedY = by + 28
        Layout.drawSlot(pedX, pedY, pedSize, pedSize, {
          color = theme.surfaceHigh,
          borderColor = theme.border,
          radius = 6,
        })

        if facesSheet and facesSheet.quads and facesSheet.quads[i - 1] and activeRegion == "KANTO" then
          local dimAlpha = theme.textMuted and theme.textMuted[4] or 0.6
          love.graphics.setColor(1, 1, 1, dimAlpha)
          love.graphics.draw(facesSheet.img, facesSheet.quads[i - 1], pedX + 6, pedY + 6, 0, 2, 2)
          love.graphics.setColor(1, 1, 1, 1)
        else
          Layout.drawText("○", pedX, pedY + 10, { font = "title", color = theme.textMuted, align = "center", width = pedSize })
        end

        Layout.drawText(badgeNames[i], bx, by + 78, { font = "button", color = theme.textMuted, align = "center", width = cellW })
        local leaderHint = gymLeaders[i] or "GYM LEADER"
        if activeRegion == "KANTO" and i == 8 then
          leaderHint = "???"
        end
        Layout.drawBadge(bx + math.floor((cellW - 74) / 2), by + 102, leaderHint, { kind = "ghost", font = "tiny", width = 74 })
      end
    end
  end

  -- 4. Bottom Button Hints Footer Bar
  local hints = isDualRegion and {
    { key = "◄ ►", label = "Flip Region (Johto/Kanto)", primary = true },
    { key = "A/B", label = "Close Passport" },
  } or {
    { key = "A/B", label = "Close Passport", primary = true },
  }
  Layout.drawHintBar(0, footY, w, 36, hints, { paddingX = isNarrow and 8 or 16 })
end

return TrainerCardRenderer
