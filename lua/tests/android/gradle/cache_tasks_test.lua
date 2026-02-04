local M = {}

local assert = require("tests.helpers.assert")
local helper = require("tests.helpers.gradle_cache")


local function caches_tasks_until_module_build_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ { name = "assemble", description = "" } })

  local tasks = cache.tasks("/repo", { ":app" }, loader)
  assert.eq(#tasks, 1, "tasks first")
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "tasks cached")

  mtimes["/repo/app/build.gradle"] = 2
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "tasks invalidated")
end

local function caches_tasks_until_settings_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ { name = "assemble", description = "" } })

  cache.tasks("/repo", { ":app" }, loader)
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "tasks cached before settings change")

  mtimes["/repo/settings.gradle"] = 2
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "tasks invalidated by settings")
end

local function caches_tasks_until_settings_kts_changes()
  local mtimes = {
    ["/repo/settings.gradle.kts"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ { name = "assemble", description = "" } })

  cache.tasks("/repo", { ":app" }, loader)
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "tasks cached before settings kts change")

  mtimes["/repo/settings.gradle.kts"] = 2
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "tasks invalidated by settings kts")
end

local function caches_tasks_until_root_build_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ { name = "assemble", description = "" } })

  cache.tasks("/repo", { ":app" }, loader)
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "tasks cached before root build change")

  mtimes["/repo/build.gradle"] = 2
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "tasks invalidated by root build")
end

local function caches_tasks_until_root_build_kts_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle.kts"] = 1,
    ["/repo/app/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ { name = "assemble", description = "" } })

  cache.tasks("/repo", { ":app" }, loader)
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "tasks cached before root build kts change")

  mtimes["/repo/build.gradle.kts"] = 2
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "tasks invalidated by root build kts")
end

local function caches_tasks_until_module_build_kts_changes()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/app/build.gradle.kts"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ { name = "assemble", description = "" } })

  cache.tasks("/repo", { ":app" }, loader)
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 1, "tasks cached with module build kts")

  mtimes["/repo/app/build.gradle.kts"] = 2
  cache.tasks("/repo", { ":app" }, loader)
  assert.eq(calls(), 2, "tasks invalidated by module build kts")
end

local function caches_tasks_ignore_module_builds_for_large_workspaces()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
    ["/repo/module200/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ { name = "assemble", description = "" } })
  local modules = helper.build_modules(201)

  cache.tasks("/repo", modules, loader)
  cache.tasks("/repo", modules, loader)
  assert.eq(calls(), 1, "tasks cached for large workspaces")

  mtimes["/repo/module200/build.gradle"] = 2
  cache.tasks("/repo", modules, loader)
  assert.eq(calls(), 1, "tasks ignore module build changes for large workspaces")
end

local function caches_tasks_invalidate_on_root_changes_for_large_workspaces()
  local mtimes = {
    ["/repo/settings.gradle"] = 1,
    ["/repo/build.gradle"] = 1,
  }
  local cache = helper.new_memory_cache(mtimes)
  local loader, calls = helper.track_loader({ { name = "assemble", description = "" } })
  local modules = helper.build_modules(201)

  cache.tasks("/repo", modules, loader)
  cache.tasks("/repo", modules, loader)
  assert.eq(calls(), 1, "tasks cached before root change")

  mtimes["/repo/build.gradle"] = 2
  cache.tasks("/repo", modules, loader)
  assert.eq(calls(), 2, "tasks invalidated by root build")

  mtimes["/repo/settings.gradle"] = 2
  cache.tasks("/repo", modules, loader)
  assert.eq(calls(), 3, "tasks invalidated by settings")
end

function M.run()
  caches_tasks_until_module_build_changes()
  caches_tasks_until_settings_changes()
  caches_tasks_until_settings_kts_changes()
  caches_tasks_until_root_build_changes()
  caches_tasks_until_root_build_kts_changes()
  caches_tasks_until_module_build_kts_changes()
  caches_tasks_ignore_module_builds_for_large_workspaces()
  caches_tasks_invalidate_on_root_changes_for_large_workspaces()
end

return M
