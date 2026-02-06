local build = require("android.actions.build")
local context = require("android.actions.context")
local gradle_tasks = require("android.actions.gradle_tasks")
local ios_build = require("android.actions.ios.build")
local build_helpers = require("android.actions.build_helpers")
local stream = require("android.build.stream")
local selection_defaults = require("android.state.selection_defaults")

local M = {}

local function split_command(command)
  if type(command) == "table" then
    return command
  end
  if not command or command == "" then
    return {}
  end
  return vim.split(command, "%s+", { trimempty = true })
end

local function run_android(workspace, config, state)
  if workspace and config and config.meta and config.meta.module then
    local next_state = selection_defaults.apply_build_defaults(
      state,
      config.meta.module,
      config.meta.variant
    )
    context.save_state(workspace.root, next_state)
  end
  build.build_default()
end

local function run_ios()
  ios_build.deploy()
end

local function run_jvm(workspace, config)
  if not workspace or not config or not config.meta then
    return nil
  end
  local task = config.meta.task
  if not task or task == "" then
    return nil
  end
  local args = build_helpers.build_command(workspace.root, { task })
  return stream.start_build_job(workspace.root, args, nil, {
    panel = {
      task = task,
    },
  })
end

local function run_gradle_task()
  gradle_tasks.open()
end

local function run_shell(workspace, config)
  if not workspace or not config or not config.meta then
    return nil
  end
  local command = config.meta.command
  local args = split_command(config.meta.args or command)
  if #args == 0 then
    return nil
  end
  return stream.start_build_job(workspace.root, args, nil, {
    panel = {
      task = args[1],
    },
  })
end

function M.run(workspace, config, state)
  local config_type = config and (config.type or config.target) or nil
  if config_type == "android" then
    run_android(workspace, config, state)
    return nil
  end
  if config_type == "ios" then
    run_ios()
    return nil
  end
  if config_type == "jvm" then
    return run_jvm(workspace, config)
  end
  if config_type == "gradle_task" then
    run_gradle_task()
    return nil
  end
  if config_type == "shell" then
    return run_shell(workspace, config)
  end
  return nil
end

return M
