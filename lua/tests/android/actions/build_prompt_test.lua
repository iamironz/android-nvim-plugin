local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function build_prompt_runs_deploy_flow()
  local deploy_called = false
  local state = { build = { module = ":app", variant = "release" } }
  local picker_calls = 0
  local assemble_variant = nil

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_calls = picker_calls + 1
        if picker_calls == 1 then
          opts.on_select(":app")
          return
        end
        opts.on_select("debug")
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
    ["android.command.job"] = {
      spawn = function(_, opts)
        if opts.on_stdout then
          opts.on_stdout({ "build line" })
        end
        if opts.on_exit then
          opts.on_exit(0)
        end
        return { ok = true, stop = function() end }
      end,
    },
    ["android.build.gradle"] = {
      assemble_command = function(_, _, variant)
        assemble_variant = variant
        return { "./gradlew", ":app:assembleDebug" }
      end,
    },
    ["android.build.quickfix"] = {
      parse = function()
        return {}
      end,
    },
    ["android.gradle.variants"] = {
      parse = function()
        return { "debug" }
      end,
    },
    ["android.build.apk"] = {
      resolve_apk_path = function()
        return { ok = true, path = "/tmp/app-debug.apk" }
      end,
      list_workspace_apks = function()
        return { ok = false, error = "no apk" }
      end,
    },
    ["android.build.deploy"] = {
      deploy = function()
        deploy_called = true
        return { ok = true }
      end,
    },
    ["android.devices.adb"] = {
      list = function()
        return { { serial = "device-1", state = "device" } }
      end,
    },
    ["android.sdk.discovery"] = {
      new = function()
        return {
          tools = function()
            return { adb = "/bin/adb", emulator = "/bin/emulator" }
          end,
          aapt2 = function()
            return nil
          end,
        }
      end,
    },
    ["android.actions.wait"] = {
      wait_for_device = function()
        return { ok = true, devices = { { state = "device" } } }
      end,
      wait_for_boot = function()
        return { ok = true, booted = true, value = "1" }
      end,
    },
    ["android.ui.panel"] = {
      open = function() end,
      clear = function() end,
      set_header_lines = function() end,
      replace_body = function() end,
      append = function() end,
      trim_body = function() end,
      close = function() end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.build.stream"] = nil
    package.loaded["android.actions.build_helpers"] = nil
    package.loaded["android.command.jobs"] = nil
    package.loaded["android.actions.build"] = nil
    local build = require("android.actions.build")
    build.build_prompt()
    assert.is_true(deploy_called, "deploy called")
    assert.eq(assemble_variant, "debug", "uses prompted variant")
    assert.eq(state.build.variant, "release", "defaults not overwritten")
  end)
end

local function build_prompt_variant_cancel_reopens_module_picker()
  local picker_titles = {}

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return { build = {} }
      end,
      save_state = function()
        return true
      end,
    },
    ["android.actions.build_helpers"] = {
      module_entries = function(modules)
        return modules
      end,
      fetch_variants = function()
        return { "debug" }
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return {}
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        table.insert(picker_titles, opts.title)
        if #picker_titles == 1 then
          opts.on_select(":app")
          return
        end
        if #picker_titles == 2 and opts.on_cancel then
          opts.on_cancel()
        end
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    local build = require("android.actions.build")
    build.build_prompt()

    assert.eq(picker_titles[1], "Gradle modules", "module picker first")
    assert.eq(picker_titles[2], "Build Variants", "variant picker next")
    assert.eq(picker_titles[3], "Gradle modules", "module picker reopened")
  end)
end

local function build_prompt_module_cancel_calls_on_cancel()
  local canceled = false

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return { build = {} }
      end,
      save_state = function()
        return true
      end,
    },
    ["android.actions.build_helpers"] = {
      module_entries = function(modules)
        return modules
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return {}
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        if opts.on_cancel then
          opts.on_cancel()
        end
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    local build = require("android.actions.build")
    build.build_prompt({
      on_cancel = function()
        canceled = true
      end,
    })

    assert.eq(canceled, true, "on_cancel called")
  end)
end

function M.run()
  build_prompt_runs_deploy_flow()
  build_prompt_variant_cancel_reopens_module_picker()
  build_prompt_module_cancel_calls_on_cancel()
end

return M
