-- OmniUI Composable Theme & Design System
-- Dynamic theme registry, hex color parser, layout geometry profiles, and customizable primitives.

local Theme = {}

-- Utility: Convert "#RRGGBB" or "#RRGGBBAA" to {r, g, b, a}
function Theme.hex(hexStr, defaultAlpha)
  if type(hexStr) == "table" then
    local r = hexStr[1] or 1
    local g = hexStr[2] or 1
    local b = hexStr[3] or 1
    local a = hexStr[4] or defaultAlpha or 1.0
    return { r, g, b, a }
  end
  if type(hexStr) ~= "string" then
    return { 1, 1, 1, defaultAlpha or 1.0 }
  end

  local clean = hexStr:gsub("#", ""):gsub("%s+", "")
  if #clean == 3 then
    local r = tonumber(clean:sub(1, 1):rep(2), 16) or 255
    local g = tonumber(clean:sub(2, 2):rep(2), 16) or 255
    local b = tonumber(clean:sub(3, 3):rep(2), 16) or 255
    return { r / 255, g / 255, b / 255, defaultAlpha or 1.0 }
  elseif #clean == 6 then
    local r = tonumber(clean:sub(1, 2), 16) or 255
    local g = tonumber(clean:sub(3, 4), 16) or 255
    local b = tonumber(clean:sub(5, 6), 16) or 255
    return { r / 255, g / 255, b / 255, defaultAlpha or 1.0 }
  elseif #clean == 8 then
    local r = tonumber(clean:sub(1, 2), 16) or 255
    local g = tonumber(clean:sub(3, 4), 16) or 255
    local b = tonumber(clean:sub(5, 6), 16) or 255
    local a = tonumber(clean:sub(7, 8), 16) or 255
    return { r / 255, g / 255, b / 255, a / 255 }
  end
  return { 1, 1, 1, defaultAlpha or 1.0 }
end

local function deepCopy(orig)
  if type(orig) ~= "table" then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = type(v) == "table" and deepCopy(v) or v
  end
  return copy
end

local function deepMerge(dst, src)
  if type(src) ~= "table" then return dst end
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      deepMerge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

-- Default Base Template
Theme.BASE = {
  id = "dark",
  label = "Dark Modern",
  author = "Cartridge Studio",
  version = "2.0.0",

  -- 1. Palette Colors (Hex strings or {r, g, b, a})
  colors = {
    bg          = { 20 / 255, 24 / 255, 29 / 255, 0.98 },    -- #14181D
    surface     = { 29 / 255, 34 / 255, 41 / 255, 0.96 },    -- #1D2229
    surfaceHigh = { 24 / 255, 29 / 255, 35 / 255, 0.96 },    -- #181D23
    raised      = { 42 / 255, 49 / 255, 59 / 255, 0.98 },    -- #2A313B
    ink         = { 240 / 255, 244 / 255, 249 / 255, 1.0 },  -- #F0F4F9

    border       = { 139 / 255, 157 / 255, 180 / 255, 0.35 }, -- #8B9DB4
    borderStrong = { 255 / 255, 255 / 255, 255 / 255, 1.0 },  -- White

    accent       = { 76 / 255, 163 / 255, 240 / 255, 1.0 },   -- #4CA3F0
    accentDark   = { 36 / 255, 106 / 255, 181 / 255, 1.0 },  -- #246AB5
    accentHover  = { 120 / 255, 185 / 255, 255 / 255, 1.0 }, -- #78B9FF

    heading     = { 245 / 255, 247 / 255, 250 / 255, 1.0 },
    text        = { 234 / 255, 239 / 255, 245 / 255, 1.0 },
    detail      = { 200 / 255, 200 / 255, 200 / 255, 1.0 },
    textDim     = { 161 / 255, 172 / 255, 187 / 255, 1.0 },
    textMuted   = { 125 / 255, 135 / 255, 150 / 255, 1.0 },
    textInverse = { 18 / 255, 22 / 255, 28 / 255, 1.0 },

    hpGreen     = { 85 / 255, 232 / 255, 135 / 255, 1.0 },
    hpYellow    = { 255 / 255, 214 / 255, 0 / 255, 1.0 },
    hpRed       = { 255 / 255, 80 / 255, 90 / 255, 1.0 },
    expBlue     = { 76 / 255, 163 / 255, 240 / 255, 1.0 },
  },

  -- 2. Metrics & Sizing Tokens
  metrics = {
    radius = {
      card      = 8,
      slot      = 6,
      button    = 6,
      badge     = 4,
      modal     = 10,
      dialogue  = 12,
      pill      = 14,
    },
    borderWidth = {
      hairline  = 1,
      normal    = 1.5,
      focus     = 2,
    },
    padding = {
      xs = 4,
      sm = 8,
      md = 12,
      lg = 16,
      xl = 24,
    },
    gap = {
      xs = 4,
      sm = 6,
      md = 10,
      lg = 16,
    },
  },

  -- 3. Visual Styling Styles
  styles = {
    cardStyle   = "flat",     -- "flat", "bordered", "glow", "glass", "angled"
    buttonStyle = "rounded",  -- "rounded", "pill", "sharp", "soft"
    badgeStyle  = "pill",     -- "pill", "tag", "minimal"
  },

  -- 4. Screen Layout & Positioning Configurations
  layout = {
    dock = {
      width         = 290,
      align         = "right", -- "left", "right", "center"
      marginX       = 24,
      marginY       = 24,
      profileHeight = 68,
      itemHeight    = 42,
      itemGap       = 6,
      footerHeight  = 36,
    },
    dialogue = {
      maxWidth        = 680,
      height          = 114,
      marginBottom    = 24,
      nameplateHeight = 30,
      nameplateAlign  = "left", -- "left", "center", "right"
      nameplateMargin = 20,
    },
    modal = {
      maxWidth     = 520,
      height       = 280,
      heroHeight   = 130,
      promptHeight = 64,
    },
    container = {
      maxWidth     = 820,
      maxHeight    = 520,
      headerHeight = 44,
      footerHeight = 36,
      gap          = 12,
    },
    pokedex = {
      leftWidth      = 320,
      rowHeight      = 38,
      rowGap         = 4,
      portraitHeight = 140,
    },
    bag = {
      leftRatio  = 0.54,
      rowHeight  = 40,
      rowGap     = 4,
      tabHeight  = 44,
    },
    party = {
      cardGap         = 4,
      previewBoxWidth = 56,
      meterHeight     = 6,
    },
    summary = {
      leftWidth      = 240,
      portraitHeight = 136,
      tabWidth       = 104,
    },
    shop = {
      leftRatio  = 0.54,
      rowHeight  = 40,
      rowGap     = 4,
    },
    options = {
      rowHeight = 46,
      rowGap    = 6,
    },
  },
}

-- Registry of Themes
Theme.REGISTRY = {}

-- Construct and normalize a theme object
function Theme.create(def)
  local t = deepCopy(Theme.BASE)
  if def then deepMerge(t, def) end

  -- Normalize colors: convert any hex string into {r, g, b, a}
  if t.colors then
    for k, v in pairs(t.colors) do
      if type(v) == "string" then
        t.colors[k] = Theme.hex(v)
      end
    end
  end

  -- Ensure drawBackground exists
  if type(t.drawBackground) ~= "function" then
    t.drawBackground = function(x, y, w, h) end
  end

  -- Metatable proxies direct color lookups (theme.bg -> theme.colors.bg)
  local mt = {
    __index = function(tbl, key)
      if tbl.colors and tbl.colors[key] ~= nil then
        return tbl.colors[key]
      end
      return rawget(tbl, key)
    end
  }
  setmetatable(t, mt)
  return t
end

-- Extend a theme with declarative overrides or custom draw delegate hooks
function Theme.extend(baseIdOrTheme, overrides)
  local base = (type(baseIdOrTheme) == "string") and (Theme.REGISTRY[baseIdOrTheme] or Theme.REGISTRY.dark) or baseIdOrTheme
  local newTheme = deepCopy(base or Theme.BASE)
  if overrides then deepMerge(newTheme, overrides) end
  return Theme.create(newTheme)
end

-- Register a theme
function Theme.register(id, def)
  if not id then return nil end
  local themeObj = Theme.create(def)
  themeObj.id = id
  Theme.REGISTRY[id] = themeObj
  return themeObj
end

-- Load all theme files from mods/omni_ui/themes/ or specified directory
function Theme.loadThemesDirectory(dirPath)
  local dir = dirPath or "mods/omni_ui/themes"

  -- 1. If love.filesystem is available, scan the directory for .lua files
  if love and love.filesystem and love.filesystem.getDirectoryItems then
    local ok, items = pcall(love.filesystem.getDirectoryItems, dir)
    if ok and items then
      for _, file in ipairs(items) do
        if file:match("%.lua$") then
          local modName = file:gsub("%.lua$", "")
          local requirePath = (dir:gsub("/", ".") .. "." .. modName):gsub("^%.", "")
          local sok, themeDef = pcall(require, requirePath)
          if sok and themeDef and type(themeDef) == "table" then
            local themeId = themeDef.id or modName
            Theme.register(themeId, themeDef)
          end
        end
      end
    end
  end

  -- 2. Fallback / ensure standard default themes are required
  local defaults = { "dark", "kanto", "emerald", "cyber", "classic", "catppuccin" }
  for _, name in ipairs(defaults) do
    if not Theme.REGISTRY[name] then
      local ok, themeDef = pcall(require, "mods.omni_ui.themes." .. name)
      if ok and themeDef and type(themeDef) == "table" then
        Theme.register(themeDef.id or name, themeDef)
      end
    end
  end
end

-- Interpolation utilities for smooth real-time theme morphing
local function lerp(a, b, t)
  return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
  c1 = (type(c1) == "table") and c1 or Theme.hex(c1)
  c2 = (type(c2) == "table") and c2 or Theme.hex(c2)
  local r = c1[1] + (c2[1] - c1[1]) * t
  local g = c1[2] + (c2[2] - c1[2]) * t
  local b = c1[3] + (c2[3] - c1[3]) * t
  local a = (c1[4] or 1.0) + ((c2[4] or 1.0) - (c1[4] or 1.0)) * t
  return { r, g, b, a }
end

local function lerpValue(v1, v2, t)
  if type(v1) == "number" and type(v2) == "number" then
    return lerp(v1, v2, t)
  elseif type(v1) == "table" and type(v2) == "table" then
    if (#v1 == 3 or #v1 == 4) and (#v2 == 3 or #v2 == 4) and type(v1[1]) == "number" and type(v2[1]) == "number" then
      return lerpColor(v1, v2, t)
    end
    local res = {}
    for k, v in pairs(v2) do
      if v1[k] ~= nil then
        res[k] = lerpValue(v1[k], v, t)
      else
        res[k] = (t >= 0.5) and v or nil
      end
    end
    for k, v in pairs(v1) do
      if res[k] == nil and t < 0.5 then
        res[k] = v
      end
    end
    return res
  else
    return (t < 0.5) and v1 or v2
  end
end

function Theme.interpolate(themeA, themeB, t)
  if not themeA then return themeB end
  if not themeB then return themeA end
  if t <= 0.0 then return themeA end
  if t >= 1.0 then return themeB end

  local res = {
    id = themeB.id,
    label = themeB.label,
    author = themeB.author,
    version = themeB.version,
    credits = themeB.credits,
    overlayDim = lerp(themeA.overlayDim or 0.60, themeB.overlayDim or 0.60, t),
    colors = {},
    metrics = lerpValue(themeA.metrics or {}, themeB.metrics or {}, t),
    layout = lerpValue(themeA.layout or {}, themeB.layout or {}, t),
    styles = (t < 0.5) and (themeA.styles or {}) or (themeB.styles or {}),
  }

  local allKeys = {}
  if themeA.colors then for k in pairs(themeA.colors) do allKeys[k] = true end end
  if themeB.colors then for k in pairs(themeB.colors) do allKeys[k] = true end end

  for k in pairs(allKeys) do
    local cA = (themeA.colors and themeA.colors[k]) or (themeB.colors and themeB.colors[k])
    local cB = (themeB.colors and themeB.colors[k]) or (themeA.colors and themeA.colors[k])
    res.colors[k] = lerpColor(cA, cB, t)
  end

  -- Copy custom theme drawing delegates from target theme
  for k, v in pairs(themeB) do
    if res[k] == nil and k ~= "colors" and k ~= "metrics" and k ~= "layout" then
      res[k] = v
    end
  end
  for k, v in pairs(themeA) do
    if res[k] == nil and k ~= "colors" and k ~= "metrics" and k ~= "layout" then
      res[k] = v
    end
  end

  local mt = {
    __index = function(tbl, key)
      if tbl.colors and tbl.colors[key] ~= nil then
        return tbl.colors[key]
      end
      local v = rawget(tbl, key)
      if v ~= nil then return v end
      return themeB[key]
    end
  }
  setmetatable(res, mt)
  return res
end

-- Initialize built-ins
Theme.register("dark", Theme.BASE)
Theme.loadThemesDirectory()

Theme.currentThemeId = "dark"
Theme.transition = nil

function Theme.get(id)
  if id and id ~= Theme.currentThemeId then
    return Theme.REGISTRY[id] or Theme.REGISTRY.dark
  end

  local targetTheme = Theme.REGISTRY[Theme.currentThemeId] or Theme.REGISTRY.dark
  if not Theme.transition then
    return targetTheme
  end

  local trans = Theme.transition
  local now = (love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
  local elapsed = now - (trans.startTime or now)
  local p = (trans.duration and trans.duration > 0) and math.max(0.0, math.min(1.0, elapsed / trans.duration)) or 1.0

  if p >= 1.0 then
    Theme.transition = nil
    return targetTheme
  end

  -- Smooth Hermite interpolation curve for silky color morphing
  local t = p * p * (3 - 2 * p)
  return Theme.interpolate(trans.from, trans.to, t)
end

function Theme.setTheme(id, duration)
  if not id or not Theme.REGISTRY[id] then return end

  local isInteractive = (love and love.window and love.window.isOpen and love.window.isOpen())
  if duration == nil then
    duration = isInteractive and 0.35 or 0
  end

  if id == Theme.currentThemeId and not Theme.transition then return end
  if id == Theme.currentThemeId and Theme.transition and Theme.transition.to and Theme.transition.to.id == id then
    return
  end

  local toTheme = Theme.REGISTRY[id]
  local fromTheme = Theme.get() -- captures in-flight blended state if already transitioning

  Theme.currentThemeId = id

  if duration > 0 then
    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
    Theme.transition = {
      from = deepCopy(fromTheme),
      to = toTheme,
      startTime = now,
      duration = duration,
    }
  else
    Theme.transition = nil
  end
end

-- Aliases for backward compatibility
Theme.setPalette = Theme.setTheme
Theme.PALETTES = Theme.REGISTRY

function Theme.list()
  local list = {}
  local seen = {}
  local preferred = { "dark", "classic", "emerald", "kanto", "cyber", "catppuccin" }
  for _, id in ipairs(preferred) do
    if Theme.REGISTRY[id] then
      list[#list + 1] = { id = id, label = Theme.REGISTRY[id].label or id }
      seen[id] = true
    end
  end
  local rest = {}
  for id, v in pairs(Theme.REGISTRY) do
    if not seen[id] then
      rest[#rest + 1] = { id = id, label = v.label or id }
    end
  end
  table.sort(rest, function(a, b) return a.id < b.id end)
  return list
end

function Theme.getThemeNames()
  local names = {}
  for id, _ in pairs(Theme.REGISTRY) do
    table.insert(names, id)
  end
  table.sort(names)
  return names
end

function Theme.getTheme(id)
  return Theme.get(id)
end

function Theme.cycleTheme(dir, duration)
  dir = dir or 1
  local list = Theme.list()
  if #list == 0 then return nil end
  local cur = Theme.currentThemeId or "dark"
  local curIdx = 1
  for i, item in ipairs(list) do
    if item.id == cur then
      curIdx = i
      break
    end
  end
  local nextIdx = ((curIdx - 1 + dir) % #list) + 1
  local nextId = list[nextIdx].id
  Theme.setTheme(nextId, duration)
  return nextId
end

-- Time-of-Day Palette Harmonization
function Theme.applyTimeOfDay(baseTheme, timeOfDay, strength)
  if not baseTheme or not timeOfDay or timeOfDay == "DAY" then
    return baseTheme
  end
  local s = strength or 0.15
  local t = deepCopy(baseTheme)
  local tod = tostring(timeOfDay):upper()

  if tod == "MORN" or tod == "MORNING" or tod == "DAWN" then
    -- Warm amber/golden morning bloom
    if t.colors then
      if t.colors.bg then
        t.colors.bg[1] = math.min(1.0, t.colors.bg[1] * (1.0 + s * 0.4))
        t.colors.bg[2] = math.min(1.0, t.colors.bg[2] * (1.0 + s * 0.2))
      end
      if t.colors.surface then
        t.colors.surface[1] = math.min(1.0, t.colors.surface[1] * (1.0 + s * 0.3))
      end
      if t.colors.accent then
        t.colors.accent = lerpColor(t.colors.accent, { 1.0, 0.78, 0.35, 1.0 }, s)
      end
    end
  elseif tod == "NITE" or tod == "NIGHT" or tod == "DUSK" then
    -- Deep lunar indigo night atmosphere
    if t.colors then
      if t.colors.bg then
        t.colors.bg[1] = t.colors.bg[1] * (1.0 - s * 0.3)
        t.colors.bg[3] = math.min(1.0, t.colors.bg[3] * (1.0 + s * 0.4))
      end
      if t.colors.surface then
        t.colors.surface[1] = t.colors.surface[1] * (1.0 - s * 0.2)
        t.colors.surface[3] = math.min(1.0, t.colors.surface[3] * (1.0 + s * 0.3))
      end
      if t.colors.accent then
        t.colors.accent = lerpColor(t.colors.accent, { 0.55, 0.60, 1.0, 1.0 }, s)
      end
    end
  end

  return Theme.create(t)
end

function Theme.getWithTimeOfDay(id, timeOfDay, strength)
  local base = Theme.get(id)
  if not timeOfDay then return base end
  return Theme.applyTimeOfDay(base, timeOfDay, strength)
end

return Theme
