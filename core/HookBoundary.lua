-- OmniUI Sandboxed Modder Hook Engine
-- Executes third-party modder hooks within protected error boundaries with OpenGL state fencing.

local HookBoundary = {}

-- Cache of faulted hooks that have thrown runtime errors
local disabledHooks = {}

-- Executes an arbitrary modder callback function safely
function HookBoundary.safeCall(hookId, hookFn, ...)
  if not hookFn or type(hookFn) ~= "function" then return nil end
  if disabledHooks[hookId] then return nil end

  local ok, res1, res2, res3 = pcall(hookFn, ...)
  if not ok then
    disabledHooks[hookId] = true
    if print then
      print(("[OmniUI Hook Error] Disabling faulted hook '%s': %s"):format(tostring(hookId), tostring(res1)))
    end
    return nil
  end
  return res1, res2, res3
end

-- Executes a modder render callback safely with full graphics state protection
function HookBoundary.safeRender(hookId, renderFn, ...)
  if not renderFn or type(renderFn) ~= "function" then return false end
  if disabledHooks[hookId] then return false end

  local g = love and love.graphics
  local hasPushAll = g and g.push and g.pop

  if hasPushAll then
    pcall(g.push, "all")
  end

  local ok, err = pcall(renderFn, ...)

  if hasPushAll then
    pcall(g.pop)
  end

  if not ok then
    disabledHooks[hookId] = true
    if print then
      print(("[OmniUI Render Hook Error] Disabling faulted badge '%s': %s"):format(tostring(hookId), tostring(err)))
    end
    return false
  end

  return true
end

-- Checks if a hook is disabled
function HookBoundary.isDisabled(hookId)
  return disabledHooks[hookId] == true
end

-- Resets disabled hooks (e.g. for testing / mod reload)
function HookBoundary.reset()
  disabledHooks = {}
end

return HookBoundary
