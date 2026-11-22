-- OmniUI Legacy v1 Compatibility Shim
-- Same registerAdapter contract as gen1_modern_ui. Other mods keep their
-- screens table and point find/register at Omni; Omni never touches the engine.

local LegacyV1Shim = {}

LegacyV1Shim.registeredAdapters = {}

local function screensOf(opts, contract)
  if type(contract) == "table" and type(contract.screens) == "table" then
    return contract.screens
  end
  if type(opts) == "table" and type(opts.screens) == "table" then
    return opts.screens
  end
  return nil
end

local function contractOf(modOrOpts)
  if type(modOrOpts) ~= "table" then return nil end
  local exports = modOrOpts.exports
  if type(exports) == "table" then
    local c = exports.gen1ModernUi or exports.gen1_modern_ui
    if type(c) == "table" then return c end
  end
  local c = modOrOpts.gen1ModernUi or modOrOpts.gen1_modern_ui
    or modOrOpts.contract or modOrOpts
  if type(c) == "table" and type(c.screens) == "table" then return c end
  return nil
end

local function nativeScreenOwns(kind, screenDef)
  local PublicApi = require("mods.omni_ui.api.PublicApi")
  local screens = PublicApi.customScreens or {}
  if screens[kind] then return true end
  if screenDef and type(screenDef.match) == "function" then
    for id, def in pairs(screens) do
      if type(id) == "string" and id:sub(1, 7) ~= "legacy_"
          and def and def.match == screenDef.match then
        return true
      end
    end
  end
  return false
end

local function publishScreen(kind, screenDef)
  if type(kind) ~= "string" or type(screenDef) ~= "table" then return end
  if type(screenDef.match) ~= "function" and type(screenDef.draw) ~= "function" then
    return
  end
  if nativeScreenOwns(kind, screenDef) then return end
  local PublicApi = require("mods.omni_ui.api.PublicApi")
  local screenId = "legacy_" .. kind
  PublicApi.registerScreen(screenId, {
    match = screenDef.match,
    model = screenDef.model,
    actions = screenDef.actions,
    draw = function(game, state, w, h, theme, subState, animProgress)
      if type(screenDef.draw) == "function" then
        return screenDef.draw(game, state, w, h, theme, subState, animProgress)
      end
      local LegacyRenderer = require("mods.omni_ui.renderers.LegacyRenderer")
      return LegacyRenderer.draw(game, state, screenDef, w, h, theme)
    end,
  })
end

function LegacyV1Shim.registerAdapter(opts)
  if not opts or type(opts) ~= "table" then return false end
  local contract = contractOf(opts)
  local screens = screensOf(opts, contract)
  if not screens then return false end

  local owner = opts.owner or opts.id or (opts.manifest and opts.manifest.id) or "unknown"
  LegacyV1Shim.registeredAdapters[owner] = contract or opts
  for kind, screenDef in pairs(screens) do
    publishScreen(kind, screenDef)
  end
  return true
end

-- One-call switch: pass the other mod after it fills exports.gen1ModernUi.
function LegacyV1Shim.adopt(mod)
  if type(mod) ~= "table" then return false end
  local contract = contractOf(mod)
  if not contract then return false end
  local owner = mod.id or (mod.manifest and mod.manifest.id) or mod.owner or "unknown"
  return LegacyV1Shim.registerAdapter({ owner = owner, contract = contract })
end

function LegacyV1Shim.publishAlias(exports)
  if type(exports) ~= "table" then return end
  package.loaded["gen1_modern_ui"] = exports
end

function LegacyV1Shim.drawMonDetail(game, mon, x, y, w, h, theme, context)
  local Layout = require("mods.omni_ui.core.Layout")
  local Theme = require("mods.omni_ui.core.Theme")
  theme = theme or Theme.get()
  Layout.drawCard(x, y, w, h, {
    color = theme.surface,
    borderColor = theme.border,
    radius = 8,
  })
  local label = (mon and (mon.nickname or mon.displayName or mon.species)) or "POKéMON"
  Layout.drawText(tostring(label), x + 12, y + 12, {
    font = "headline",
    color = theme.heading,
    bold = true,
    width = math.max(8, w - 24),
  })
end

return LegacyV1Shim
