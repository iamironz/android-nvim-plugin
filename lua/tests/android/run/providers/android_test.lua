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

local function detects_android_modules_from_application_id()
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

  assert_android_config(list, { module = ":app" })
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

local function prefers_tasks_for_large_workspaces()
  local read_calls = 0
  local modules = {}
  for i = 1, 201 do
    modules[#modules + 1] = string.format(":module%03d", i)
  end

  local list = detect_with({
    modules = modules,
    read = function()
      read_calls = read_calls + 1
      return { "plugins", "com.android.application" }
    end,
    tasks = { ":app:assembleDebug - Assembles" },
  })

  assert.eq(read_calls, 0, "build files not read")
  assert_android_config(list, { module = ":app" })
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

function M.run()
  detects_android_modules_from_build_files()
  detects_android_modules_from_dotted_alias()
  ignores_android_modules_with_namespace_only()
  detects_android_modules_from_application_id()
  detects_android_modules_from_gradle_tasks_when_build_scan_empty()
  detects_android_modules_from_gradle_tasks_when_forced()
  skips_build_file_scan_when_use_gradle_tasks_enabled()
  caches_android_module_build_scan_results()
  prefers_tasks_for_large_workspaces()
end

return M
