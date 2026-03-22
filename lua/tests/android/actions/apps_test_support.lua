local stubs_helper = require("tests.helpers.stubs")

local M = {}

local function merge_stubs(base, extra)
  for key, value in pairs(extra or {}) do
    base[key] = value
  end
  return base
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

function M.build_install_command_stub()
  return {
    build_install_command = function(adb_path, device, apk_path)
      return {
        ok = true,
        cmd = { adb_path, "-s", device, "install", "-r", "-d", "-t", apk_path },
      }
    end,
  }
end

function M.with_apps_stubs(stubs, fn)
  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.apps"] = nil
    fn(require("android.actions.apps"))
  end)
end

function M.build_default_stubs(state, opts)
  local options = opts or {}
  local stubs = {
    ["android.actions.context"] = build_context_stubs(state, options.save_state),
    ["android.sdk.discovery"] = build_sdk_stubs(options.adb_path),
    ["android.command.runner"] = build_runner_stubs(options.runner_run),
    ["android.devices.adb"] = build_adb_stubs(options.device_serial),
    ["android.state.menu_prefetch"] = {
      cached_variant_fetch_opts = function(_, module)
        return { module = module }
      end,
    },
  }
  return merge_stubs(stubs, options.extra)
end

function M.with_default_apps(state, opts, fn)
  M.with_apps_stubs(M.build_default_stubs(state, opts), fn)
end

function M.make_runner_capture()
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

function M.make_state_saver()
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

function M.make_apk_resolver_capture(path)
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

return M
