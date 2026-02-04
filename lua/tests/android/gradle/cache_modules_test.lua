local M = {}

local assert = require("tests.helpers.assert")
local helper = require("tests.helpers.gradle_cache")

local function caches_modules_until_settings_or_build_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
  }
  local cache = helper.new_cache(mtimes)
  local loader, calls = helper.track_loader({ ":app" })

  local modules = cache.modules("/repo", loader)
  assert.table_eq(modules, { ":app" }, "modules first")
  cache.modules("/repo", loader)
  assert.eq(calls(), 1, "modules cached")

  mtimes["/repo/build.gradle"] = 2
  cache.modules("/repo", loader)
  assert.eq(calls(), 2, "modules invalidated")
end

local function caches_modules_until_settings_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
  }
  local cache = helper.new_cache(mtimes)
  local loader, calls = helper.track_loader({ ":app" })

  cache.modules("/repo", loader)
  cache.modules("/repo", loader)
  assert.eq(calls(), 1, "modules cached before settings change")

  mtimes["/repo/settings.gradle"] = 2
  cache.modules("/repo", loader)
  assert.eq(calls(), 2, "modules invalidated by settings")
end

local function caches_modules_until_settings_kts_changes()
  local mtimes = {
    ["/repo/settings.gradle.kts"] = 1,
    ["/repo/build.gradle"] = 1,
  }
  local cache = helper.new_cache(mtimes)
  local loader, calls = helper.track_loader({ ":app" })

  cache.modules("/repo", loader)
  cache.modules("/repo", loader)
  assert.eq(calls(), 1, "modules cached with settings kts")

  mtimes["/repo/settings.gradle.kts"] = 2
  cache.modules("/repo", loader)
  assert.eq(calls(), 2, "modules invalidated by settings kts")
end

local function caches_modules_until_root_build_kts_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle.kts"] = 1,
  }
  local cache = helper.new_cache(mtimes)
  local loader, calls = helper.track_loader({ ":app" })

  cache.modules("/repo", loader)
  cache.modules("/repo", loader)
  assert.eq(calls(), 1, "modules cached with root build kts")

  mtimes["/repo/build.gradle.kts"] = 2
  cache.modules("/repo", loader)
  assert.eq(calls(), 2, "modules invalidated by root build kts")
end

function M.run()
  caches_modules_until_settings_or_build_changes()
  caches_modules_until_settings_changes()
  caches_modules_until_settings_kts_changes()
  caches_modules_until_root_build_kts_changes()
end

return M
