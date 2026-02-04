local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function with_vim_notify_stubs(fn)
  local original_notify = vim.notify
  local state = { message = nil, level = nil }

  vim.notify = function(message, level)
    state.message = message
    state.level = level
  end

  local ok, err = pcall(function()
    fn(state)
  end)

  vim.notify = original_notify

  if not ok then
    error(err)
  end
end

local function build_default_state(options)
  local opts = options or {}
  local saved_state = opts.state
    or { build = { module = ":app", variant = "debug" }, logcat = { package = "com.old" } }
  local logcat_opened = 0
  local panel_closed = 0
  local deploy_result = opts.deploy_result or { ok = true, app_id = "com.new" }

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return saved_state
      end,
      save_state = function(_, next_state)
        saved_state = next_state
        return true
      end,
    },
    ["android.actions.build_helpers"] = {
      run_build = function(_, _, _, on_complete)
        if on_complete then
          on_complete({ ok = true })
        end
        return { ok = true }
      end,
      fetch_variants = function()
        return { "debug" }
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return {
          run = function()
            return { ok = true, stdout = "", stderr = "" }
          end,
        }
      end,
    },
    ["android.build.apk"] = {
      resolve_apk_path = function()
        return { ok = true, path = "/tmp/app.apk" }
      end,
    },
    ["android.build.deploy"] = {
      deploy = function()
        return deploy_result
      end,
    },
    ["android.devices.adb"] = {
      list = function()
        return { { serial = "device-1", state = "device" } }
      end,
    },
    ["android.actions.defaults"] = {
      select_device_serial = function()
        return "device-1"
      end,
      select_avd_name = function()
        return nil
      end,
      select_module = function()
        return ":app"
      end,
      select_variant = function()
        return "debug"
      end,
    },
    ["android.sdk.discovery"] = {
      new = function()
        return {
          tools = function()
            return { adb = "/bin/adb", emulator = "/bin/emulator" }
          end,
          aapt2 = function()
            return "/bin/aapt2"
          end,
        }
      end,
    },
    ["android.actions.wait"] = {
      wait_for_boot = function()
        return { ok = true, booted = true }
      end,
    },
    ["android.actions.logcat"] = {
      open = function()
        logcat_opened = logcat_opened + 1
      end,
    },
    ["android.ui.panel"] = {
      close = function()
        panel_closed = panel_closed + 1
        return true
      end,
    },
  }

  local output = nil
  with_vim_notify_stubs(function()
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.actions.build"] = nil
      local build = require("android.actions.build")
      build.build_default()
    end)
    output = {
      logcat_opened = logcat_opened,
      panel_closed = panel_closed,
      saved_state = saved_state,
    }
  end)

  return output
end

local function pure_build_runs_assemble_only()
  local build_root = nil
  local build_module = nil
  local build_variant = nil
  local deploy_called = false

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return { build = { module = ":app", variant = "debug" } }
      end,
      save_state = function()
        return true
      end,
    },
    ["android.actions.build_helpers"] = {
      run_build = function(root, module, variant)
        build_root = root
        build_module = module
        build_variant = variant
        return { ok = true }
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return { run = function() return { ok = true, stdout = "", stderr = "" } end }
      end,
    },
    ["android.build.deploy"] = {
      deploy = function()
        deploy_called = true
        return { ok = true }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    local build = require("android.actions.build")
    build.build_pure()
    assert.eq(build_root, "/workspace", "build root")
    assert.eq(build_module, ":app", "build module")
    assert.eq(build_variant, "debug", "build variant")
    assert.is_true(not deploy_called, "deploy not called")
  end)
end

local function clean_runs_gradle_clean()
  local received_root = nil
  local received_args = nil
  local job_called = false

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
    },
    ["android.actions.build_helpers"] = {
      build_command = function(root, args)
        received_root = root
        received_args = args
        return { "./gradlew", args[1] }
      end,
    },
    ["android.build.stream"] = {
      start_build_job = function(_, args, on_complete)
        job_called = true
        received_args = args
        if on_complete then
          on_complete({ ok = true, code = 0 })
        end
        return { ok = true }
      end,
    },
  }

  with_vim_notify_stubs(function(state)
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.actions.build"] = nil
      local build = require("android.actions.build")
      build.clean()
      assert.eq(received_root, "/workspace", "root")
      assert.eq(received_args[1], "./gradlew", "gradle command")
      assert.eq(received_args[2], "clean", "clean arg")
      assert.is_true(job_called, "job called")
      assert.eq(state.message, "Gradle clean completed", "notify message")
    end)
  end)
end

local function deploy_success_opens_logcat_and_updates_package()
  local result = build_default_state()
  local logcat_package = (result.saved_state.logcat or {}).package or ""
  local summary = string.format(
    "%d|%s|%d",
    result.logcat_opened,
    logcat_package,
    result.panel_closed
  )
  assert.eq(summary, "1|com.new|1", "logcat opened on deploy")
end

local function deploy_failure_does_not_open_logcat()
  local result = build_default_state({ deploy_result = { ok = false, error = "failed" } })
  local logcat_package = (result.saved_state.logcat or {}).package or ""
  local summary = string.format(
    "%d|%s|%d",
    result.logcat_opened,
    logcat_package,
    result.panel_closed
  )
  assert.eq(summary, "0|com.old|0", "logcat skipped on failure")
end

function M.run()
  pure_build_runs_assemble_only()
  clean_runs_gradle_clean()
  deploy_success_opens_logcat_and_updates_package()
  deploy_failure_does_not_open_logcat()
end

return M
