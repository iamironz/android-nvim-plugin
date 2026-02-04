local M = {}

local assert = require("tests.helpers.assert")
local helper = require("tests.helpers.gradle_cache")

local function assert_not_contains(haystack, needle, message)
  if type(haystack) == "string" and haystack:find(needle, 1, true) then
    error(message or ("unexpected " .. tostring(needle) .. " in " .. tostring(haystack)))
  end
end


local function stamps_include_kts_paths()
  local cache, captured = helper.capture_cache()
  local mtimes = {
    ["/repo/settings.gradle.kts"] = 1,
    ["/repo/build.gradle.kts"] = 1,
    ["/repo/app/build.gradle.kts"] = 1,
  }
  local api = helper.new_cache(mtimes, cache)

  api.modules("/repo", function()
    return { ":app" }
  end)
  api.tasks("/repo", { ":app" }, function()
    return {}
  end)

  assert.contains(captured.modules, "/repo/settings.gradle.kts", "modules stamp settings kts")
  assert.contains(captured.modules, "/repo/build.gradle.kts", "modules stamp root build kts")
  assert.contains(captured.tasks, "/repo/app/build.gradle.kts", "tasks stamp module build kts")
end

local function stamps_use_root_paths_for_large_workspaces()
  local cache, captured = helper.capture_cache()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/module200/build.gradle"] = 1,
  }
  local api = helper.new_cache(mtimes, cache)
  local modules = helper.build_modules(201)

  api.tasks("/repo", modules, function()
    return {}
  end)

  assert.contains(captured.tasks, "/repo/settings.gradle", "tasks stamp settings")
  assert.contains(captured.tasks, "/repo/build.gradle", "tasks stamp root build")
  assert_not_contains(
    captured.tasks,
    "/repo/module200/build.gradle",
    "tasks stamp excludes module build"
  )
end

function M.run()
  stamps_include_kts_paths()
  stamps_use_root_paths_for_large_workspaces()
end

return M
