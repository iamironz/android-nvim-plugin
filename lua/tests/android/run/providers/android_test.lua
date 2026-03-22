local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")
local provider = require("android.run.providers.android")

local workspace_counter = 0
local session_id = tostring(vim.loop.hrtime())

local function next_workspace_root()
  workspace_counter = workspace_counter + 1
  return "/workspace/test-" .. session_id .. "-" .. tostring(workspace_counter)
end

local function default_workspace(root)
  local workspace_root = root or next_workspace_root()
  return { root = workspace_root, android = { root = workspace_root } }
end

local function default_state()
  return { build = { variant = "debug" } }
end

local function detect_with(opts)
  local options = opts or {}
  local root = options.root
  options.root = nil
  return provider.detect(default_workspace(root), default_state(), options)
end

local function assert_android_config(list, expected)
  assert.eq(#list, 1, "one android config")
  if expected.target then
    assert.eq(list[1].target, expected.target, "android target")
  end
  if expected.module then
    assert.eq(list[1].meta.module, expected.module, "android module")
  end
  if expected.variant then
    assert.eq(list[1].meta.variant, expected.variant, "android variant")
  end
end

local function detects_android_modules_from_build_files()
  local list = detect_with({
    modules = { ":androidApp", ":server" },
    read = function(path)
      if path:match("androidApp") then
        return { "plugins", "com.android.application" }
      end
      return nil
    end,
  })

  assert_android_config(list, {
    target = "android",
    module = ":androidApp",
    variant = "debug",
  })
end

local function detects_android_modules_from_dotted_alias()
  local list = detect_with({
    modules = { ":app" },
    read = function()
      return { "plugins", "alias(libs.plugins.android.application)" }
    end,
  })

  assert_android_config(list, { module = ":app" })
end

local function ignores_android_modules_with_namespace_only()
  local list = detect_with({
    modules = { ":app" },
    read = function()
      return { "android {", "namespace = \"com.example\"", "}" }
    end,
    tasks = {},
  })

  assert.eq(#list, 0, "no android config")
end

local function ignores_modules_with_application_id_only()
  local list = detect_with({
    modules = { ":app" },
    read = function()
      return {
        "android {",
        "defaultConfig {",
        "applicationId = \"com.example\"",
        "}",
        "}",
      }
    end,
  })

  assert.eq(#list, 0, "applicationId alone should not classify Android app plugin")
end

local function detects_android_modules_from_gradle_tasks_when_build_scan_empty()
  local list = detect_with({
    modules = { ":app" },
    read = function()
      return nil
    end,
    tasks = {
      ":app:assembleDebug - Assembles",
      ":app:installDebug - Installs",
    },
  })

  assert_android_config(list, { module = ":app" })
end

local function detects_android_modules_from_gradle_tasks_when_forced()
  local list = detect_with({
    modules = { ":androidApp", ":app" },
    read = function(path)
      if path:match("androidApp") then
        return { "plugins", "com.android.application" }
      end
      return nil
    end,
    tasks = { ":app:assembleDebug - Assembles" },
    use_gradle_tasks = true,
  })

  assert_android_config(list, { module = ":app" })
end

local function skips_build_file_scan_when_use_gradle_tasks_enabled()
  local read_calls = 0
  local list = detect_with({
    modules = { ":app" },
    read = function()
      read_calls = read_calls + 1
      return { "plugins", "com.android.application" }
    end,
    tasks = { ":app:assembleDebug - Assembles" },
    use_gradle_tasks = true,
  })

  assert.eq(read_calls, 0, "build files not read")
  assert_android_config(list, { module = ":app" })
end

local function scans_large_workspaces_using_plugin_detection()
  local read_calls = 0
  local modules = {}
  for i = 1, 201 do
    modules[#modules + 1] = string.format(":module%03d", i)
  end
  modules[#modules + 1] = ":special:launcher"

  local list = detect_with({
    modules = modules,
    read = function(path)
      read_calls = read_calls + 1
      if path:match("special/launcher/build%.gradle") then
        return { "plugins", "com.android.application" }
      end
      return nil
    end,
  })

  assert.eq(read_calls > 0, true, "large workspace build files are scanned")
  assert_android_config(list, { module = ":special:launcher" })
end

local function fast_mode_skips_gradle_task_fallback()
  local fetch_calls = 0
  local stubs = {
    ["android.actions.build_helpers"] = {
      fetch_task_lines = function()
        fetch_calls = fetch_calls + 1
        return {}
      end,
    },
    ["android.gradle.cache"] = {
      persistent = function()
        return {
          modules = function(_, loader)
            return loader()
          end,
          android_modules = function(_, _, loader)
            return loader()
          end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.providers.android"] = nil
    local fast_provider = require("android.run.providers.android")
    local list = fast_provider.detect(default_workspace("/workspace/fast"), default_state(), {
      modules = { ":app" },
      read = function()
        return nil
      end,
      fast = true,
    })
    assert.eq(#list, 0, "fast mode defers android module discovery without metadata")
  end)

  assert.eq(fetch_calls, 0, "fast mode should not fetch gradle task list")
end

local function detects_android_modules_from_snapshot_before_build_scan()
  local read_calls = 0
  local list = detect_with({
    modules = { ":app", ":androidApp" },
    snapshot = {
      android = {
        modules = { ":androidApp" },
        by_module = {
          [":androidApp"] = { variants = { "debug" } },
        },
      },
    },
    read = function()
      read_calls = read_calls + 1
      return { "plugins", "com.android.application" }
    end,
  })

  assert.eq(read_calls, 0, "snapshot skips build scan")
  assert_android_config(list, { module = ":androidApp" })
end

local function fast_mode_uses_snapshot_without_gradle_fetch()
  local fetch_calls = 0
  local stubs = {
    ["android.actions.build_helpers"] = {
      fetch_task_lines = function()
        fetch_calls = fetch_calls + 1
        return {}
      end,
    },
    ["android.gradle.cache"] = {
      persistent = function()
        return {
          modules = function(_, loader)
            return loader()
          end,
          android_modules = function(_, _, loader)
            return loader()
          end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.providers.android"] = nil
    local fast_provider = require("android.run.providers.android")
    local list = fast_provider.detect(default_workspace("/workspace/fast-snapshot"), default_state(), {
      modules = { ":androidApp" },
      snapshot = {
        android = {
          modules = { ":androidApp" },
          by_module = {
            [":androidApp"] = { variants = { "debug" } },
          },
        },
      },
      read = function()
        error("build scan should not run when snapshot is available")
      end,
      fast = true,
    })

    assert_android_config(list, { module = ":androidApp", variant = "debug" })
  end)

  assert.eq(fetch_calls, 0, "fast snapshot should not fetch gradle task list")
end

local function caches_android_module_build_scan_results()
  local read_calls = 0
  local stubs = {
    ["android.gradle.cache"] = {
      persistent = function()
        local cached = nil
        return {
          modules = function(_, loader)
            return loader()
          end,
          android_modules = function(_, _, loader)
            if cached then
              return cached
            end
            cached = loader()
            return cached
          end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.providers.android"] = nil
    local cached_provider = require("android.run.providers.android")
    local opts = {
      root = "/workspace/cache-test",
      modules = { ":app" },
      read = function()
        read_calls = read_calls + 1
        return { "plugins", "com.android.application" }
      end,
    }

    cached_provider.detect(default_workspace(), default_state(), opts)
    cached_provider.detect(default_workspace(), default_state(), opts)
    assert.eq(read_calls, 1, "build scan cached")
  end)
end

local function snapshot_detection_bypasses_stale_build_scan_cache()
  local stubs = {
    ["android.gradle.cache"] = {
      persistent = function()
        local cached = nil
        return {
          modules = function(_, loader)
            return loader()
          end,
          android_modules = function(_, _, loader)
            if cached then
              return cached
            end
            cached = loader()
            return cached
          end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.providers.android"] = nil
    local cached_provider = require("android.run.providers.android")
    local root = "/workspace/stale-cache-snapshot"

    local first = cached_provider.detect(default_workspace(root), default_state(), {
      modules = { ":build-logic:convention", ":app" },
      read = function(path)
        if path:match("build%-logic/convention") then
          return { "plugins", "com.android.application" }
        end
        return nil
      end,
    })
    assert_android_config(first, { module = ":build-logic:convention" })

    local second = cached_provider.detect(default_workspace(root), default_state(), {
      modules = { ":build-logic:convention", ":app" },
      snapshot = {
        android = {
          modules = { ":app" },
          by_module = {
            [":app"] = { variants = { "debug" } },
          },
        },
      },
      read = function()
        error("snapshot discovery should bypass cached build scan")
      end,
    })

    assert_android_config(second, { module = ":app" })
  end)
end

local function task_detection_bypasses_stale_build_scan_cache()
  local stubs = {
    ["android.gradle.cache"] = {
      persistent = function()
        local cached = nil
        return {
          modules = function(_, loader)
            return loader()
          end,
          android_modules = function(_, _, loader)
            if cached then
              return cached
            end
            cached = loader()
            return cached
          end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.providers.android"] = nil
    local cached_provider = require("android.run.providers.android")
    local root = "/workspace/stale-cache-tasks"

    local first = cached_provider.detect(default_workspace(root), default_state(), {
      modules = { ":build-logic:convention", ":app" },
      read = function(path)
        if path:match("build%-logic/convention") then
          return { "plugins", "com.android.application" }
        end
        return nil
      end,
    })
    assert_android_config(first, { module = ":build-logic:convention" })

    local second = cached_provider.detect(default_workspace(root), default_state(), {
      modules = { ":build-logic:convention", ":app" },
      tasks = { ":app:assembleDebug - Assembles" },
      read = function()
        error("task discovery should bypass cached build scan")
      end,
    })

    assert_android_config(second, { module = ":app" })
  end)
end

function M.run()
  detects_android_modules_from_build_files()
  detects_android_modules_from_dotted_alias()
  ignores_android_modules_with_namespace_only()
  ignores_modules_with_application_id_only()
  detects_android_modules_from_gradle_tasks_when_build_scan_empty()
  detects_android_modules_from_gradle_tasks_when_forced()
  skips_build_file_scan_when_use_gradle_tasks_enabled()
  fast_mode_skips_gradle_task_fallback()
  detects_android_modules_from_snapshot_before_build_scan()
  fast_mode_uses_snapshot_without_gradle_fetch()
  caches_android_module_build_scan_results()
  snapshot_detection_bypasses_stale_build_scan_cache()
  task_detection_bypasses_stale_build_scan_cache()
  scans_large_workspaces_using_plugin_detection()
end

return M
