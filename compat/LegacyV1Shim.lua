-- OmniUI Legacy v1 Compatibility Shim
-- Implements the legacy `registerAdapter` contract used by Kanto-Reforged & other mods.

local LegacyV1Shim = {}

LegacyV1Shim.registeredAdapters = {}

function LegacyV1Shim.registerAdapter(opts)
  if not opts or type(opts) ~= "table" then return false end
  local owner = opts.owner or "unknown"
  local contract = opts.contract

  if not contract or type(contract) ~= "table" then return false end

  LegacyV1Shim.registeredAdapters[owner] = contract
  return true
end

-- Fallback/compat helper for functions expecting legacy draw signatures
function LegacyV1Shim.drawMonDetail(game, mon, x, y, w, h, theme, context)
  -- Safe default rendering implementation that satisfies legacy hooks
  local Layout = require("mods.omni_ui.core.Layout")
  Layout.drawPanel(x, y, w, h)
end

return LegacyV1Shim
