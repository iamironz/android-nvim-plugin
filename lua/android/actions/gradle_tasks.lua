local M = {}

local context = require("android.actions.context")
local build_helpers = require("android.actions.build_helpers")
local gradle_cache = require("android.gradle.cache")
local runner_module = require("android.command.runner")
local tasks_parser = require("android.gradle.tasks")
local gradle_workspace = require("android.gradle.workspace")
local stream = require("android.build.stream")

local cache = gradle_cache.persistent()

local function format_task(entry)
  if entry.description and entry.description ~= "" then
    return string.format("%s - %s", entry.name, entry.description)
  end
  return entry.name
end

local function notify_result(result)
  if result and result.ok then
    vim.notify("Gradle task completed", vim.log.levels.INFO)
    return
  end
  local message = "Gradle task failed"
  if result and result.stderr and result.stderr ~= "" then
    message = message .. ": " .. result.stderr
  end
  vim.notify(message, vim.log.levels.ERROR)
end

local function build_picker(tasks, on_select, on_cancel)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return nil, "telescope not available"
  end

  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  return pickers.new({}, {
    prompt_title = "Gradle tasks",
    finder = finders.new_table({
      results = tasks,
      entry_maker = function(entry)
        local label = format_task(entry)
        return {
          value = entry.name,
          display = label,
          ordinal = label,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and on_select then
          on_select(selection.value)
        end
      end)
      if on_cancel then
        local map_fn = map or function() end
        local handle_cancel = function()
          actions.close(prompt_bufnr)
          on_cancel()
        end
        map_fn("i", "<esc>", handle_cancel)
        map_fn("n", "<esc>", handle_cancel)
      end
      return true
    end,
  })
end

function M.fetch_tasks(root, runner)
  local exec_runner = runner or runner_module.new()
  local modules = cache.modules(root, function()
    return gradle_workspace.load_modules(root)
  end)
  return cache.tasks(root, modules, function()
    local result = build_helpers.run_gradle(root, { "tasks", "--all" }, exec_runner)
    if not result or not result.ok then
      return {}, false
    end
    local lines = vim.split(result.stdout or "", "\n", { plain = true })
    return tasks_parser.parse(lines)
  end)
end

function M.run_task(root, task, on_complete)
  if not task or task == "" then
    vim.notify("Gradle task required", vim.log.levels.WARN)
    return nil
  end

  local args = build_helpers.build_command(root, { task })
  return stream.start_build_job(root, args, function(result)
    notify_result(result)
    if on_complete then
      on_complete(result)
    end
  end, {
    panel = {
      task = task,
    },
  })
end

function M.open(opts)
  local options = opts or {}
  local workspace = context.workspace()
  if not workspace then
    return
  end

  local runner = runner_module.new()
  local tasks = M.fetch_tasks(workspace.root, runner)
  if #tasks == 0 then
    vim.notify("No Gradle tasks found", vim.log.levels.WARN)
    return
  end

  local picker, err = build_picker(tasks, function(task)
    M.run_task(workspace.root, task)
  end, options.on_cancel)
  if not picker then
    vim.notify(err or "telescope not available", vim.log.levels.WARN)
    return
  end
  picker:find()
end

return M
