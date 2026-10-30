-- OmniUI Public v2 Extension API
-- Stable mod-facing interface for registering custom tabs, pockets, widgets, custom screens, and composable themes.

local LegacyV1Shim = require("mods.omni_ui.compat.LegacyV1Shim")
local Theme = require("mods.omni_ui.core.Theme")
local Layout = require("mods.omni_ui.core.Layout")
local Widgets = require("mods.omni_ui.core.Widgets")
local HookBoundary = require("mods.omni_ui.core.HookBoundary")

local MoveDatabase = require("mods.omni_ui.core.MoveDatabase")
local ItemDatabase = require("mods.omni_ui.core.ItemDatabase")

local PublicApi = {}

-- Extension Registries
PublicApi.startMenuItems = {}
PublicApi.optionRows = {}
PublicApi.summaryTabs = {}
PublicApi.bagPockets = {}
PublicApi.partyActions = {}
PublicApi.customScreens = {}
PublicApi.battleWidgets = {}
PublicApi.preRenderHooks = {}
PublicApi.postRenderHooks = {}

-- Core Engine Primitives & Databases for Modders
PublicApi.Theme = Theme
PublicApi.Layout = Layout
PublicApi.Widgets = Widgets
PublicApi.HookBoundary = HookBoundary
PublicApi.MoveDatabase = MoveDatabase
PublicApi.ItemDatabase = ItemDatabase
PublicApi.safeCall = HookBoundary.safeCall
PublicApi.safeRender = HookBoundary.safeRender

-- Custom Move & Item Registration for Modders
PublicApi.registerMove = MoveDatabase.registerMove
PublicApi.registerMoves = MoveDatabase.registerMoves
PublicApi.registerMoveDescriptionProvider = MoveDatabase.registerDescriptionProvider
PublicApi.registerItem = ItemDatabase.registerItem
PublicApi.registerItems = ItemDatabase.registerItems
PublicApi.registerItemDescriptionProvider = ItemDatabase.registerDescriptionProvider

-- =========================================================================
-- 1. Theme Composition & Registration API
-- =========================================================================

function PublicApi.registerTheme(id, themeDef)
  return Theme.register(id, themeDef)
end

function PublicApi.extendTheme(baseIdOrTheme, overrides)
  return Theme.extend(baseIdOrTheme, overrides)
end

function PublicApi.setTheme(themeId)
  Theme.setTheme(themeId)
end

function PublicApi.getTheme(id)
  return Theme.get(id)
end

function PublicApi.getThemes()
  return Theme.list()
end

-- =========================================================================
-- 2. Menu & Screen Extension API
-- =========================================================================

--- Registers a custom entry into the Pause / Start Menu.
--- @param itemDef table { id = string, label = string, badge = string|nil, kind = string|nil, onSelect = function(game), insertBefore = string|nil, insertAfter = string|nil, render = function|nil }
function PublicApi.registerStartMenuItem(itemDef)
  if not itemDef or not itemDef.id then return false end
  PublicApi.startMenuItems[itemDef.id] = itemDef
  return true
end

--- Registers a custom setting or row into the Options Menu.
--- @param rowDef table { id = string, label = string, choices = table|nil, values = table|nil, step = number|nil, get = function|nil, set = function|nil, onSelect = function|nil }
function PublicApi.registerOptionRow(rowDef)
  if not rowDef or not rowDef.id then return false end
  PublicApi.optionRows[rowDef.id] = rowDef
  return true
end

--- Registers an extra page tab in the Pokémon Summary Screen.
--- @param tabDef table { id = string, label = string, draw = function(game, mon, rx, ry, rw, rh, theme) }
function PublicApi.registerSummaryTab(tabDef)
  if not tabDef or not tabDef.id then return false end
  PublicApi.summaryTabs[tabDef.id] = tabDef
  return true
end

--- Registers an extra category pocket in the Bag / Inventory Screen.
--- @param pocketDef table { id = string, label = string, filter = function(itemId, itemDef)|nil }
function PublicApi.registerBagPocket(pocketDef)
  if not pocketDef or not pocketDef.id then return false end
  PublicApi.bagPockets[pocketDef.id] = pocketDef
  return true
end

--- Registers an action in the Pokémon Party Context Submenu.
--- @param actionDef table { id = string, label = string, onSelect = function(game, mon, partyIndex)|nil }
function PublicApi.registerPartyAction(actionDef)
  if not actionDef or not actionDef.id then return false end
  PublicApi.partyActions[actionDef.id] = actionDef
  return true
end

--- Registers a completely custom modal or screen that integrates seamlessly with OmniUI modern styling.
--- @param screenId string Identifier for the custom screen
--- @param screenDef table { match = function(state): boolean, draw = function(game, state, w, h, theme, subState, animProgress) }
function PublicApi.registerScreen(screenId, screenDef)
  if not screenId or not screenDef then return false end
  PublicApi.customScreens[screenId] = screenDef
  return true
end

-- =========================================================================
-- 3. Battle HUD Extension API
-- =========================================================================

local BattleRenderer = require("mods.omni_ui.renderers.BattleRenderer")

function PublicApi.registerBattleWidget(widgetDef)
  if not widgetDef or not widgetDef.id then return false end
  PublicApi.battleWidgets[widgetDef.id] = widgetDef
  return true
end

function PublicApi.registerBattleAction(actionDef)
  BattleRenderer.registerAction(actionDef)
  return true
end

function PublicApi.registerBattlerBadge(badgeDef)
  BattleRenderer.registerBadge(badgeDef)
  return true
end

function PublicApi.registerMoveDetailProvider(providerFn)
  BattleRenderer.registerMoveDetailProvider(providerFn)
  return true
end

-- =========================================================================
-- 4. Lifecycle Render Interceptors (Pre- & Post-Render Hooks)
-- =========================================================================

--- Intercepts before OmniUI draws a screen.
--- @param screenKind string Screen identifier (e.g., "start_menu", "party", "bag", "summary", "pokedex", "battle")
--- @param hookId string Unique identifier for the hook
--- @param hookFn function(game, state, w, h, theme, subState)
function PublicApi.onPreRender(screenKind, hookId, hookFn)
  if type(hookId) == "function" then
    hookFn = hookId
    hookId = "anonymous_" .. tostring(hookFn)
  end
  if not screenKind or not hookFn then return false end
  PublicApi.preRenderHooks[screenKind] = PublicApi.preRenderHooks[screenKind] or {}
  PublicApi.preRenderHooks[screenKind][hookId] = hookFn
  return true
end

--- Intercepts after OmniUI draws a screen (for HUD overlays, watermarks, custom telemetry).
--- @param screenKind string Screen identifier
--- @param hookId string Unique identifier for the hook
--- @param hookFn function(game, state, w, h, theme, subState)
function PublicApi.onPostRender(screenKind, hookId, hookFn)
  if type(hookId) == "function" then
    hookFn = hookId
    hookId = "anonymous_" .. tostring(hookFn)
  end
  if not screenKind or not hookFn then return false end
  PublicApi.postRenderHooks[screenKind] = PublicApi.postRenderHooks[screenKind] or {}
  PublicApi.postRenderHooks[screenKind][hookId] = hookFn
  return true
end

-- =========================================================================
-- 5. v1 Backward-Compatibility Exports
-- =========================================================================
PublicApi.registerAdapter = LegacyV1Shim.registerAdapter
PublicApi.drawMonDetail = LegacyV1Shim.drawMonDetail
PublicApi.setPalette = PublicApi.setTheme

return PublicApi
