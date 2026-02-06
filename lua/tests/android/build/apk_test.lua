local M = {}

local assert = require("tests.helpers.assert")
local apk = require("android.build.apk")
local config = require("android.config")

local function module_name(module)
  return module:gsub("^:", "")
end

local function make_temp_dir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

local function make_apk_dir(root, module, variant, subdir)
  local dir = root
    .. "/"
    .. module_name(module)
    .. "/build/outputs/apk/"
    .. variant

  if subdir then
    dir = dir .. "/" .. subdir
  end

  vim.fn.mkdir(dir, "p")
  return dir
end

local function touch(path, mtime)
  vim.fn.writefile({ "apk" }, path)
  local timestamp = mtime or os.time()
  vim.loop.fs_utime(path, timestamp, timestamp)
end

local function make_apk(dir, filename, mtime)
  local path = dir .. "/" .. filename
  touch(path, mtime)
  return path
end

local function resolves_newest_apk_in_variant_dir()
  local root = make_temp_dir()
  local dir = make_apk_dir(root, ":app", "debug")

  local older = make_apk(dir, "app-debug.apk", os.time() - 60)
  local newer = make_apk(dir, "app-debug-2.apk", os.time())

  local result = apk.resolve_apk_path(root, ":app", "debug")
  assert.is_true(result.ok, "resolve ok")
  assert.eq(result.path, newer, "resolve newest")
end

local function resolves_flavor_build_type_variant()
  local root = make_temp_dir()
  local dir = make_apk_dir(root, "app", "free/debug")
  local target = make_apk(dir, "app-free-debug.apk", os.time())

  local result = apk.resolve_apk_path(root, "app", "freeDebug")
  assert.is_true(result.ok, "resolve ok")
  assert.eq(result.path, target, "resolve flavor build type")
end

local function returns_error_when_no_apk()
  local root = make_temp_dir()
  make_apk_dir(root, ":app", "debug")

  local result = apk.resolve_apk_path(root, ":app", "debug")
  assert.eq(result.ok, false, "resolve missing ok")
  assert.contains(result.error, "apk", "resolve missing error")
end

local function lists_apks_in_variant_dir()
  local root = make_temp_dir()
  local dir = make_apk_dir(root, ":app", "debug")
  local older = make_apk(dir, "app-debug.apk", os.time() - 60)
  local newer = make_apk(dir, "app-debug-2.apk", os.time())

  local result = apk.list_apk_paths(root, ":app", "debug")
  assert.is_true(result.ok, "list ok")
  assert.table_eq(result.apks, { newer, older }, "list order")
end

local function lists_flavor_build_type_apks()
  local root = make_temp_dir()
  local dir = make_apk_dir(root, "app", "free/debug")
  local target = make_apk(dir, "app-free-debug.apk", os.time())

  local result = apk.list_apk_paths(root, "app", "freeDebug")
  assert.is_true(result.ok, "list flavor ok")
  assert.table_eq(result.apks, { target }, "list flavor")
end

local function returns_error_when_list_empty()
  local root = make_temp_dir()
  make_apk_dir(root, ":app", "debug")

  local result = apk.list_apk_paths(root, ":app", "debug")
  assert.eq(result.ok, false, "list missing ok")
  assert.contains(result.error, "apk", "list missing error")
end

local function returns_error_when_variant_missing_without_fallback()
  local root = make_temp_dir()
  local dir = make_apk_dir(root, ":app", "release")
  make_apk(dir, "app-release.apk", os.time())

  local result = apk.list_apk_paths(root, ":app", "debug")
  assert.eq(result.ok, false, "list missing ok")
  assert.contains(result.error, "variant", "list missing error")
end

local function falls_back_to_module_scan_when_enabled()
  local root = make_temp_dir()
  local dir = make_apk_dir(root, ":app", "release")
  local target = make_apk(dir, "app-release.apk", os.time())

  local result = apk.list_apk_paths(root, ":app", "debug", {
    scan_all_apk_outputs = true,
  })

  assert.is_true(result.ok, "list ok")
  assert.table_eq(result.apks, { target }, "fallback list")
end

local function falls_back_to_module_scan_when_config_enabled()
  local root = make_temp_dir()
  local dir = make_apk_dir(root, ":app", "release")
  local target = make_apk(dir, "app-release.apk", os.time())

  config.setup({
    build = {
      scan_all_apk_outputs = true,
    },
  })

  local result = apk.list_apk_paths(root, ":app", "debug")
  config.reset()

  assert.is_true(result.ok, "list ok")
  assert.table_eq(result.apks, { target }, "fallback list")
end

local function prefers_override_path_for_variant()
  local root = make_temp_dir()
  local default_dir = make_apk_dir(root, ":app", "debug")
  local override_dir = root .. "/custom"
  vim.fn.mkdir(override_dir, "p")

  local default_apk = make_apk(default_dir, "app-debug.apk", os.time() - 60)
  local override_apk = make_apk(override_dir, "app-debug-override.apk", os.time())

  local result = apk.resolve_apk_path(root, ":app", "debug", {
    overrides = {
      { module = ":app", variant = "debug", path = override_apk },
    },
  })

  assert.is_true(result.ok, "override ok")
  assert.eq(result.path, override_apk, "override path")
end

local function resolves_relative_override_path()
  local root = make_temp_dir()
  local override_dir = root .. "/artifacts"
  vim.fn.mkdir(override_dir, "p")

  local relative = "artifacts/app-debug.apk"
  local override_apk = root .. "/" .. relative
  touch(override_apk, os.time())

  local result = apk.resolve_apk_path(root, "app", "debug", {
    overrides = {
      { module = "app", variant = "debug", path = relative },
    },
  })

  assert.is_true(result.ok, "override ok")
  assert.eq(result.path, override_apk, "override path")
end

local function returns_error_when_override_missing()
  local root = make_temp_dir()
  make_apk_dir(root, ":app", "debug")

  local result = apk.list_apk_paths(root, ":app", "debug", {
    overrides = {
      { module = ":app", variant = "debug", path = "missing.apk" },
    },
  })

  assert.eq(result.ok, false, "override missing ok")
  assert.contains(result.error, "override", "override missing error")
end

local function lists_module_apks_recursively()
  local root = make_temp_dir()
  local dir = make_apk_dir(root, ":app", "debug", "nested")
  local older = make_apk(dir, "app-debug.apk", os.time() - 60)
  local newer = make_apk(dir, "app-debug-2.apk", os.time())

  local result = apk.list_module_apks(root, ":app")
  assert.is_true(result.ok, "module ok")
  assert.table_eq(result.apks, { newer, older }, "module apks")
end

local function resolves_bare_build_type_with_flavors()
  local root = make_temp_dir()
  local internal_dir = make_apk_dir(root, ":app", "internal/debug")
  local external_dir = make_apk_dir(root, ":app", "external/debug")
  local internal_apk = make_apk(internal_dir, "app-internal-debug.apk", os.time())
  local external_apk = make_apk(external_dir, "app-external-debug.apk", os.time() - 30)

  local result = apk.list_apk_paths(root, ":app", "debug")
  assert.is_true(result.ok, "bare debug with flavors ok")
  assert.eq(#result.apks, 2, "bare debug with flavors count")
end

local function resolves_single_flavor_for_bare_build_type()
  local root = make_temp_dir()
  local dir = make_apk_dir(root, ":app", "internal/debug")
  local target = make_apk(dir, "app-internal-debug.apk", os.time())

  local result = apk.resolve_apk_path(root, ":app", "debug")
  assert.is_true(result.ok, "single flavor resolve ok")
  assert.eq(result.path, target, "single flavor resolve path")
end

local function bare_build_type_ignores_non_matching_dirs()
  local root = make_temp_dir()
  local release_dir = make_apk_dir(root, ":app", "internal/release")
  make_apk(release_dir, "app-internal-release.apk", os.time())

  local result = apk.list_apk_paths(root, ":app", "debug")
  assert.eq(result.ok, false, "no debug apks in release dirs")
end

local function bare_build_type_ignores_android_test_outputs()
  local root = make_temp_dir()
  local app_dir = make_apk_dir(root, ":app", "debug")
  local android_test_dir = make_apk_dir(root, ":app", "androidTest/debug")
  local deployable = make_apk(app_dir, "app-debug.apk", os.time() - 60)
  make_apk(android_test_dir, "app-debug-androidTest.apk", os.time())

  local result = apk.resolve_apk_path(root, ":app", "debug")
  assert.is_true(result.ok, "resolve debug with androidTest outputs")
  assert.eq(result.path, deployable, "resolve ignores androidTest apk")
end

local function lists_workspace_apks_across_modules()
  local root = make_temp_dir()
  local app_dir = make_apk_dir(root, ":app", "debug")
  local other_dir = make_apk_dir(root, ":other", "release")

  local app_apk = make_apk(app_dir, "app-debug.apk", os.time() - 60)
  local other_apk = make_apk(other_dir, "other-release.apk", os.time())

  local result = apk.list_workspace_apks(root, { ":app", ":other" })
  assert.is_true(result.ok, "workspace ok")
  assert.eq(#result.apks, 2, "workspace count")
  assert.eq(result.apks[1].module, ":other", "workspace module 1")
  assert.eq(result.apks[1].path, other_apk, "workspace path 1")
  assert.eq(result.apks[2].module, ":app", "workspace module 2")
  assert.eq(result.apks[2].path, app_apk, "workspace path 2")
end

function M.run()
  resolves_newest_apk_in_variant_dir()
  resolves_flavor_build_type_variant()
  returns_error_when_no_apk()
  lists_apks_in_variant_dir()
  lists_flavor_build_type_apks()
  returns_error_when_list_empty()
  returns_error_when_variant_missing_without_fallback()
  falls_back_to_module_scan_when_enabled()
  falls_back_to_module_scan_when_config_enabled()
  prefers_override_path_for_variant()
  resolves_relative_override_path()
  returns_error_when_override_missing()
  lists_module_apks_recursively()
  resolves_bare_build_type_with_flavors()
  resolves_single_flavor_for_bare_build_type()
  bare_build_type_ignores_non_matching_dirs()
  bare_build_type_ignores_android_test_outputs()
  lists_workspace_apks_across_modules()
end

return M
