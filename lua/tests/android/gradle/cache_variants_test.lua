local M = {}

local assert = require("tests.helpers.assert")
local helper = require("tests.helpers.gradle_cache")


local function caches_variants_until_root_build_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ "debug" })

  local variants = cache.variants("/repo", { ":app" }, loader)
  assert.table_eq(variants, { "debug" }, "variants first")
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "variants cached")

  mtimes["/repo/build.gradle"] = 2
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "variants invalidated")
end

local function caches_variants_until_settings_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ "debug" })

  cache.variants("/repo", { ":app" }, loader)
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "variants cached before settings change")

  mtimes["/repo/settings.gradle"] = 2
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "variants invalidated by settings")
end

local function caches_variants_until_settings_kts_changes()
  local mtimes = {
    ["/repo/settings.gradle.kts"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ "debug" })

  cache.variants("/repo", { ":app" }, loader)
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "variants cached before settings kts change")

  mtimes["/repo/settings.gradle.kts"] = 2
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "variants invalidated by settings kts")
end

local function caches_variants_until_module_build_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ "debug" })

  cache.variants("/repo", { ":app" }, loader)
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "variants cached before module build change")

  mtimes["/repo/app/build.gradle"] = 2
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "variants invalidated by module build")
end

local function caches_variants_until_module_build_kts_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle.kts"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ "debug" })

  cache.variants("/repo", { ":app" }, loader)
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "variants cached before module build kts change")

  mtimes["/repo/app/build.gradle.kts"] = 2
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "variants invalidated by module build kts")
end

local function caches_variants_until_root_build_kts_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle.kts"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ "debug" })

  cache.variants("/repo", { ":app" }, loader)
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "variants cached with root build kts")

  mtimes["/repo/build.gradle.kts"] = 2
  cache.variants("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "variants invalidated by root build kts")
end

local function caches_variants_ignore_module_builds_for_large_workspaces()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/module200/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ "debug" })
  local modules = helper.build_modules(201)

  cache.variants("/repo", modules, loader)
  cache.variants("/repo", modules, loader)
  assert.eq(calls(), 1, "variants cached for large workspaces")

  mtimes["/repo/module200/build.gradle"] = 2
  cache.variants("/repo", modules, loader)
  assert.eq(calls(), 1, "variants ignore module build changes for large workspaces")
end

local function caches_variants_invalidate_on_root_changes_for_large_workspaces()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ "debug" })
  local modules = helper.build_modules(201)

  cache.variants("/repo", modules, loader)
  cache.variants("/repo", modules, loader)
  assert.eq(calls(), 1, "variants cached before root change")

  mtimes["/repo/build.gradle"] = 2
  cache.variants("/repo", modules, loader)
  assert.eq(calls(), 2, "variants invalidated by root build")

  mtimes["/repo/settings.gradle"] = 2
  cache.variants("/repo", modules, loader)
  assert.eq(calls(), 3, "variants invalidated by settings")
end

function M.run()
  caches_variants_until_root_build_changes()
  caches_variants_until_settings_changes()
  caches_variants_until_settings_kts_changes()
  caches_variants_until_module_build_changes()
  caches_variants_until_module_build_kts_changes()
  caches_variants_until_root_build_kts_changes()
  caches_variants_ignore_module_builds_for_large_workspaces()
  caches_variants_invalidate_on_root_changes_for_large_workspaces()
end

return M
