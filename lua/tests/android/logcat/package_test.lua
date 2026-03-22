local M = {}

local assert = require("tests.helpers.assert")
local logcat_package = require("android.logcat.package")

local function make_temp_dir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

local function write_config(root, payload)
  local path = root .. "/.android.nvim.json"
  vim.fn.writefile(vim.split(payload, "\n", { plain = true }), path)
  return path
end

local function returns_saved_package_and_skips_manifest()
  local called = { exists = false, readfile = false }
  local result = logcat_package.resolve_default_package({
    saved_package = "com.saved.app",
    workspace = { root = "/root", modules = { ":app" } },
    exists = function()
      called.exists = true
      return true
    end,
    readfile = function()
      called.readfile = true
      return { "<manifest package=\"com.example.app\" />" }
    end,
  })

  assert.eq(result, "com.saved.app", "saved package")
  assert.eq(called.exists, false, "does not check manifest")
  assert.eq(called.readfile, false, "does not read manifest")
end

local function resolves_app_id_from_apk_and_skips_manifest()
  local called = { exists = false, readfile = false }
  local list_called = { root = nil, modules = nil }
  local resolve_called = { apk_path = nil, aapt2_path = nil, runner = nil }
  local runner = {}
  local result = logcat_package.resolve_default_package({
    workspace = { root = "/root", modules = { ":app" } },
    aapt2_path = "/tools/aapt2",
    runner = runner,
    list_apks = function(root, modules)
      list_called.root = root
      list_called.modules = modules
      return { ok = true, apks = { { path = "/apks/app-debug.apk" } } }
    end,
    resolve_app_id = function(apk_path, aapt2_path, runner_arg)
      resolve_called.apk_path = apk_path
      resolve_called.aapt2_path = aapt2_path
      resolve_called.runner = runner_arg
      return { ok = true, app_id = "com.example.app" }
    end,
    exists = function()
      called.exists = true
      return true
    end,
    readfile = function()
      called.readfile = true
      return { "<manifest package=\"com.example.manifest\" />" }
    end,
  })

  assert.eq(result, "com.example.app", "apk app id")
  assert.eq(called.exists, false, "does not check manifest")
  assert.eq(called.readfile, false, "does not read manifest")
  assert.eq(list_called.root, "/root", "list apks root")
  assert.table_eq(list_called.modules, { ":app" }, "list apks modules")
  assert.eq(resolve_called.apk_path, "/apks/app-debug.apk", "resolve app id path")
  assert.eq(resolve_called.aapt2_path, "/tools/aapt2", "resolve app id aapt2")
  assert.eq(resolve_called.runner, runner, "resolve app id runner")
end

local function falls_back_to_manifest_when_apk_resolution_fails()
  local called = { resolve = false, exists = false, readfile = false }
  local result = logcat_package.resolve_default_package({
    workspace = { root = "/root", modules = { ":app" } },
    list_apks = function()
      return { ok = true, apks = { { path = "/apks/app-debug.apk" } } }
    end,
    resolve_app_id = function()
      called.resolve = true
      return { ok = false, error = "not found" }
    end,
    exists = function()
      called.exists = true
      return true
    end,
    readfile = function()
      called.readfile = true
      return { "<manifest package=\"com.example.fallback\" />" }
    end,
  })

  assert.eq(result, "com.example.fallback", "manifest package")
  assert.eq(called.resolve, true, "attempts apk resolve")
  assert.eq(called.exists, true, "checks manifest")
  assert.eq(called.readfile, true, "reads manifest")
end

local function prefers_shared_project_package_before_apk_or_manifest()
  local root = make_temp_dir()
  write_config(root, [[{"app":{"package":"com.example.configured"}}]])

  local called = { list_apks = false, exists = false, readfile = false }
  local result = logcat_package.resolve_default_package({
    workspace = { root = root, modules = { ":app" } },
    list_apks = function()
      called.list_apks = true
      return { ok = true, apks = { { path = "/apks/app-debug.apk" } } }
    end,
    exists = function()
      called.exists = true
      return true
    end,
    readfile = function()
      called.readfile = true
      return { "<manifest package=\"com.example.manifest\" />" }
    end,
  })

  assert.eq(result, "com.example.configured", "shared project package")
  assert.eq(called.list_apks, false, "does not inspect apk")
  assert.eq(called.exists, false, "does not inspect manifest")
  assert.eq(called.readfile, false, "does not read manifest")
end

local function resolves_manifest_package_for_default_module()
  local observed = { exists_path = nil, read_path = nil }
  local result = logcat_package.resolve_default_package({
    saved_package = nil,
    workspace = { root = "/root", modules = { ":lib", ":androidApp" } },
    exists = function(path)
      observed.exists_path = path
      return true
    end,
    readfile = function(path)
      observed.read_path = path
      return {
        "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\"",
        "    package=\"com.example.app\">",
      }
    end,
  })

  assert.eq(result, "com.example.app", "manifest package")
  assert.eq(
    observed.exists_path,
    "/root/androidApp/src/main/AndroidManifest.xml",
    "manifest path"
  )
  assert.eq(observed.read_path, observed.exists_path, "readfile path")
end

local function returns_nil_when_manifest_missing()
  local result = logcat_package.resolve_default_package({
    saved_package = nil,
    workspace = { root = "/root", modules = { ":app" } },
    exists = function()
      return false
    end,
    readfile = function()
      return nil
    end,
  })

  assert.eq(result, nil, "missing manifest")
end

local function falls_back_to_namespace_when_manifest_missing()
  local observed = { exists_paths = {}, read_paths = {} }
  local result = logcat_package.resolve_default_package({
    saved_package = nil,
    workspace = { root = "/root", modules = { ":app" } },
    exists = function(path)
      table.insert(observed.exists_paths, path)
      return path == "/root/app/build.gradle.kts"
    end,
    readfile = function(path)
      table.insert(observed.read_paths, path)
      if path == "/root/app/build.gradle.kts" then
        return {
          "android {",
          "namespace = \"com.example.ns\"",
          "}",
        }
      end
      return nil
    end,
  })

  assert.eq(result, "com.example.ns", "namespace package")
  assert.eq(
    observed.read_paths[1],
    "/root/app/build.gradle.kts",
    "reads build gradle"
  )
end

local function falls_back_to_application_id_before_namespace()
  local result = logcat_package.resolve_default_package({
    saved_package = nil,
    workspace = { root = "/root", modules = { ":app" } },
    exists = function(path)
      return path == "/root/app/src/main/AndroidManifest.xml"
        or path == "/root/app/build.gradle.kts"
    end,
    readfile = function(path)
      if path == "/root/app/src/main/AndroidManifest.xml" then
        return { "<manifest>", "</manifest>" }
      end
      return {
        "android {",
        "defaultConfig {",
        "applicationId = \"com.example.app\"",
        "}",
        "namespace = \"com.example.ns\"",
        "}",
      }
    end,
  })

  assert.eq(result, "com.example.app", "application id wins")
end

local function falls_back_to_groovy_application_id()
  local observed = { exists_paths = {}, read_paths = {} }
  local result = logcat_package.resolve_default_package({
    saved_package = nil,
    workspace = { root = "/root", modules = { ":app" } },
    exists = function(path)
      table.insert(observed.exists_paths, path)
      return path == "/root/app/build.gradle"
    end,
    readfile = function(path)
      table.insert(observed.read_paths, path)
      return {
        "android {",
        "defaultConfig {",
        "applicationId 'com.example.groovy'",
        "}",
        "}",
      }
    end,
  })

  assert.eq(result, "com.example.groovy", "groovy application id")
  assert.eq(observed.read_paths[1], "/root/app/build.gradle", "reads build gradle")
end

local function falls_back_to_kotlin_application_id_call()
  local result = logcat_package.resolve_default_package({
    saved_package = nil,
    workspace = { root = "/root", modules = { ":app" } },
    exists = function(path)
      return path == "/root/app/build.gradle.kts"
    end,
    readfile = function()
      return {
        "android {",
        "defaultConfig {",
        "applicationId(\"com.example.kotlin\")",
        "}",
        "}",
      }
    end,
  })

  assert.eq(result, "com.example.kotlin", "kotlin application id")
end

function M.run()
  returns_saved_package_and_skips_manifest()
  resolves_app_id_from_apk_and_skips_manifest()
  falls_back_to_manifest_when_apk_resolution_fails()
  prefers_shared_project_package_before_apk_or_manifest()
  resolves_manifest_package_for_default_module()
  returns_nil_when_manifest_missing()
  falls_back_to_namespace_when_manifest_missing()
  falls_back_to_application_id_before_namespace()
  falls_back_to_groovy_application_id()
  falls_back_to_kotlin_application_id_call()
end

return M
