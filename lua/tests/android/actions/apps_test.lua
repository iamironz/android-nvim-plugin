local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function merge_stubs(base, extra)
  for key, value in pairs(extra or {}) do
    base[key] = value
  end
  return base
end

local function with_apps_stubs(stubs, fn)
  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.apps"] = nil
    fn(require("android.actions.apps"))
  end)
end

local function build_context_stubs(state, save_state)
  return {
    workspace = function()
      return { root = "/workspace", modules = { ":app" } }
    end,
    load_state = function()
      return state
    end,
    save_state = function(_, next_state)
      state = next_state
      if save_state then
        save_state(next_state)
      end
      return true
    end,
  }
end

local function build_sdk_stubs(adb_path)
  return {
    new = function()
      return {
        tools = function()
          return { adb = adb_path or "/sdk/adb" }
        end,
        aapt2 = function()
          return nil
        end,
      }
    end,
  }
end

local function build_runner_stubs(run)
  return {
    new = function()
      return {
        run = function(cmd)
          if run then
            return run(cmd)
          end
          return { ok = true, stdout = "", stderr = "" }
        end,
      }
    end,
  }
end

local function build_adb_stubs(serial)
  return {
    list = function()
      return { { serial = serial or "device-1", state = "device" } }
    end,
  }
end

local function build_default_stubs(state, opts)
  local options = opts or {}
  local stubs = {
    ["android.actions.context"] = build_context_stubs(state, options.save_state),
    ["android.sdk.discovery"] = build_sdk_stubs(options.adb_path),
    ["android.command.runner"] = build_runner_stubs(options.runner_run),
    ["android.devices.adb"] = build_adb_stubs(options.device_serial),
  }
  return merge_stubs(stubs, options.extra)
end

local function with_default_apps(state, opts, fn)
  local stubs = build_default_stubs(state, opts)
  with_apps_stubs(stubs, fn)
end

local function make_runner_capture()
  local command = nil
  local called = false
  return {
    run = function(cmd)
      command = cmd
      called = true
      return { ok = true, stdout = "", stderr = "" }
    end,
    command = function()
      return command
    end,
    called = function()
      return called
    end,
  }
end

local function make_state_saver()
  local saved_state = nil
  return {
    save = function(next_state)
      saved_state = next_state
    end,
    state = function()
      return saved_state
    end,
  }
end

local function make_apk_resolver_capture(path)
  local received_module = nil
  local received_variant = nil
  return {
    stub = {
      resolve_apk_path = function(_, module, variant)
        received_module = module
        received_variant = variant
        return { ok = true, path = path or "/tmp/app-debug.apk" }
      end,
    },
    module = function()
      return received_module
    end,
    variant = function()
      return received_variant
    end,
  }
end

local function run_install_and_capture(state)
  local apk_resolver = make_apk_resolver_capture("/tmp/app-debug.apk")

  with_default_apps(state, {
    extra = {
      ["android.build.apk"] = apk_resolver.stub,
      ["android.build.deploy"] = {
        build_install_command = function(adb_path, device, apk_path)
          return {
            ok = true,
            cmd = {
              adb_path,
              "-s",
              device,
              "install",
              "-r",
              "-d",
              "-t",
              apk_path,
            },
          }
        end,
      },
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
  local runner = make_runner_capture()
  local state = {
    build = { module = ":app", variant = "debug" },
    device = { serial = "device-1" },
  }
  local apk_resolver = make_apk_resolver_capture("/tmp/app-debug.apk")

  with_default_apps(state, {
    runner_run = runner.run,
    extra = {
      ["android.build.apk"] = apk_resolver.stub,
      ["android.build.deploy"] = {
        build_install_command = function(adb_path, device, apk_path)
          return {
            ok = true,
            cmd = {
              adb_path,
              "-s",
              device,
              "install",
              "-r",
              "-d",
              "-t",
              apk_path,
            },
          }
        end,
      },
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

local function clear_data_runs_pm_clear_command()
  local runner = make_runner_capture()
  local state = { device = { serial = "device-1" } }

  with_input_value("com.example.app", function()
    with_default_apps(state, {
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
  local state_saver = make_state_saver()
  local state = { device = { serial = "device-1" } }

  with_input_value("com.example.app", function()
    with_default_apps(state, {
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
  local runner = make_runner_capture()
  local state = {
    device = { serial = "device-1" },
    app = { package = "com.saved" },
  }

  with_input_error(function()
    with_default_apps(state, {
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
  local state_saver = make_state_saver()
  local state = {
    device = { serial = "device-1" },
    app = { package = "com.saved" },
  }

  with_input_error(function()
    with_default_apps(state, {
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
  clear_data_runs_pm_clear_command()
  clear_data_persists_package()
  uninstall_runs_adb_uninstall_command()
  uninstall_persists_package()
end

return M
