local M = {}

local assert = require("tests.helpers.assert")
local support = require("tests.android.actions.apps_test_support")

local function run_install_and_capture(state)
  local apk_resolver = support.make_apk_resolver_capture("/tmp/app-debug.apk")

  support.with_default_apps(state, {
    extra = {
      ["android.build.apk"] = apk_resolver.stub,
      ["android.build.deploy"] = support.build_install_command_stub(),
    },
  }, function(apps)
    apps.install()
  end)

  return apk_resolver
end

local function with_input_override(override, fn)
  local original_input = vim.fn.input
  vim.fn.input = override

  local ok, err = pcall(fn)

  vim.fn.input = original_input

  if not ok then
    error(err, 0)
  end
end

local function with_input_value(value, fn)
  with_input_override(function()
    return value
  end, fn)
end

local function with_input_error(fn)
  with_input_override(function()
    error("unexpected input")
  end, fn)
end

local function input_value_restores_input_after_error()
  local original_input = vim.fn.input
  local sentinel = function()
    return "sentinel"
  end

  vim.fn.input = sentinel

  pcall(function()
    with_input_value("value", function()
      error("boom")
    end)
  end)

  local restored = vim.fn.input == sentinel
  vim.fn.input = original_input

  assert.eq(restored, true, "input restored")
end

local function input_value_bubbles_error()
  local ok = pcall(function()
    with_input_value("value", function()
      error("boom")
    end)
  end)

  assert.eq(ok, false, "error bubbles")
end

local function input_error_restores_input_after_error()
  local original_input = vim.fn.input
  local sentinel = function()
    return "sentinel"
  end

  vim.fn.input = sentinel

  pcall(function()
    with_input_error(function()
      error("boom")
    end)
  end)

  local restored = vim.fn.input == sentinel
  vim.fn.input = original_input

  assert.eq(restored, true, "input restored")
end

local function input_error_bubbles_error()
  local ok = pcall(function()
    with_input_error(function()
      error("boom")
    end)
  end)

  assert.eq(ok, false, "error bubbles")
end

local function install_uses_build_module()
  local state = {
    build = { module = ":app", variant = "debug" },
    device = { serial = "device-1" },
  }

  local apk_resolver = run_install_and_capture(state)

  assert.eq(apk_resolver.module(), ":app", "module")
end

local function install_uses_build_variant()
  local state = {
    build = { module = ":app", variant = "debug" },
    device = { serial = "device-1" },
  }

  local apk_resolver = run_install_and_capture(state)

  assert.eq(apk_resolver.variant(), "debug", "variant")
end

local function install_runs_adb_install_command()
  local runner = support.make_runner_capture()
  local state = {
    build = { module = ":app", variant = "debug" },
    device = { serial = "device-1" },
  }
  local apk_resolver = support.make_apk_resolver_capture("/tmp/app-debug.apk")

  support.with_default_apps(state, {
    runner_run = runner.run,
    extra = {
      ["android.build.apk"] = apk_resolver.stub,
      ["android.build.deploy"] = support.build_install_command_stub(),
    },
  }, function(apps)
    apps.install()
  end)

  assert.table_eq(
    runner.command(),
    {
      "/sdk/adb",
      "-s",
      "device-1",
      "install",
      "-r",
      "-d",
      "-t",
      "/tmp/app-debug.apk",
    },
    "install cmd"
  )
end

local function install_reuses_prefetch_cache_for_variant_lookup()
  local fetch_variant_opts = nil
  local state = {
    build = { module = ":app" },
    device = { serial = "device-1" },
  }
  local apk_resolver = support.make_apk_resolver_capture("/tmp/app-debug.apk")

  support.with_default_apps(state, {
    extra = {
      ["android.actions.build_helpers"] = {
        fetch_variants = function(_, _, opts)
          fetch_variant_opts = opts
          return { "debug" }
        end,
      },
      ["android.build.apk"] = apk_resolver.stub,
      ["android.build.deploy"] = support.build_install_command_stub(),
      ["android.state.menu_prefetch"] = {
        cached_variant_fetch_opts = function(_, module)
          return {
            module = module,
            tasks = { ":app:assembleDebug - Assembles" },
            snapshot = {
              android = {
                modules = { ":app" },
                by_module = {
                  [":app"] = { module = ":app", variants = { "debug" } },
                },
              },
            },
          }
        end,
      },
    },
  }, function(apps)
    apps.install()
  end)

  assert.eq(fetch_variant_opts.tasks[1], ":app:assembleDebug - Assembles", "cached task lines reused")
  assert.eq(fetch_variant_opts.snapshot.android.modules[1], ":app", "cached snapshot reused")
end

local function install_without_prefetch_cache_keeps_variant_lookup_compatible()
  local fetch_variant_opts = nil
  local state = {
    build = { module = ":app" },
    device = { serial = "device-1" },
  }
  local apk_resolver = support.make_apk_resolver_capture("/tmp/app-debug.apk")

  support.with_default_apps(state, {
    extra = {
      ["android.actions.build_helpers"] = {
        fetch_variants = function(_, _, opts)
          fetch_variant_opts = opts
          return { "debug" }
        end,
      },
      ["android.build.apk"] = apk_resolver.stub,
      ["android.build.deploy"] = support.build_install_command_stub(),
    },
  }, function(apps)
    apps.install()
  end)

  assert.eq(fetch_variant_opts.module, ":app", "module still passed")
  assert.eq(fetch_variant_opts.tasks, nil, "no cached task lines when unavailable")
  assert.eq(fetch_variant_opts.snapshot, nil, "no cached snapshot when unavailable")
end

local function clear_data_runs_pm_clear_command()
  local runner = support.make_runner_capture()
  local state = { device = { serial = "device-1" } }

  with_input_value("com.example.app", function()
    support.with_default_apps(state, {
      runner_run = runner.run,
      extra = {
        ["android.logcat.package"] = {
          resolve_default_package = function()
            return nil
          end,
        },
      },
    }, function(apps)
      apps.clear_data()
    end)
  end)

  assert.table_eq(
    runner.command(),
    {
      "/sdk/adb",
      "-s",
      "device-1",
      "shell",
      "pm",
      "clear",
      "com.example.app",
    },
    "clear cmd"
  )
end

local function clear_data_persists_package()
  local state_saver = support.make_state_saver()
  local state = { device = { serial = "device-1" } }

  with_input_value("com.example.app", function()
    support.with_default_apps(state, {
      save_state = state_saver.save,
      extra = {
        ["android.logcat.package"] = {
          resolve_default_package = function()
            return nil
          end,
        },
      },
    }, function(apps)
      apps.clear_data()
    end)
  end)

  assert.eq(state_saver.state().app.package, "com.example.app", "saved package")
end

local function uninstall_runs_adb_uninstall_command()
  local runner = support.make_runner_capture()
  local state = {
    device = { serial = "device-1" },
    app = { package = "com.saved" },
  }

  with_input_error(function()
    support.with_default_apps(state, {
      runner_run = runner.run,
      extra = {
        ["android.logcat.package"] = {
          resolve_default_package = function()
            return "com.example.app"
          end,
        },
      },
    }, function(apps)
      apps.uninstall()
    end)
  end)

  assert.table_eq(
    runner.command(),
    { "/sdk/adb", "-s", "device-1", "uninstall", "com.example.app" },
    "uninstall cmd"
  )
end

local function uninstall_persists_package()
  local state_saver = support.make_state_saver()
  local state = {
    device = { serial = "device-1" },
    app = { package = "com.saved" },
  }

  with_input_error(function()
    support.with_default_apps(state, {
      save_state = state_saver.save,
      extra = {
        ["android.logcat.package"] = {
          resolve_default_package = function()
            return "com.example.app"
          end,
        },
      },
    }, function(apps)
      apps.uninstall()
    end)
  end)

  assert.eq(state_saver.state().app.package, "com.example.app", "saved package")
end

function M.run()
  input_value_restores_input_after_error()
  input_value_bubbles_error()
  input_error_restores_input_after_error()
  input_error_bubbles_error()
  install_uses_build_module()
  install_uses_build_variant()
  install_runs_adb_install_command()
  install_reuses_prefetch_cache_for_variant_lookup()
  install_without_prefetch_cache_keeps_variant_lookup_compatible()
  clear_data_runs_pm_clear_command()
  clear_data_persists_package()
  uninstall_runs_adb_uninstall_command()
  uninstall_persists_package()
end

return M
