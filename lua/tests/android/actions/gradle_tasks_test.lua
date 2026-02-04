local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function build_selection_store()
  local storage = {}
  return {
    load = function(opts)
      local key = opts and opts.workspace_root or ""
      return storage[key] or {}
    end,
    save = function(opts, state)
      local key = opts and opts.workspace_root or ""
      storage[key] = state
      return true
    end,
  }
end

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

local function fetches_gradle_tasks_builds_gradle_args_sets_root()
  local received_root = nil

  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      run_gradle = function(root)
        received_root = root
        return { ok = true, stdout = "assemble - Desc" }
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function()
        return { { name = "assemble", description = "Desc" } }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.cache"] = nil
    package.loaded["android.gradle.cache"] = nil
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    gradle_tasks.fetch_tasks("/root")
    assert.eq(received_root, "/root", "root")
  end)
end

local function fetches_gradle_tasks_builds_gradle_args_sets_args()
  local received_args = nil

  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      run_gradle = function(_, args)
        received_args = args
        return { ok = true, stdout = "assemble - Desc" }
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function()
        return { { name = "assemble", description = "Desc" } }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.cache"] = nil
    package.loaded["android.gradle.cache"] = nil
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    gradle_tasks.fetch_tasks("/root")
    assert.eq(received_args[1], "tasks", "arg 1")
    assert.eq(received_args[2], "--all", "arg 2")
  end)
end

local function fetches_gradle_tasks_passes_lines_to_parser()
  local received_lines = nil

  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      run_gradle = function()
        return { ok = true, stdout = "assemble - Desc" }
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function(lines)
        received_lines = lines
        return { { name = "assemble", description = "Desc" } }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.cache"] = nil
    package.loaded["android.gradle.cache"] = nil
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    gradle_tasks.fetch_tasks("/root")
    assert.eq(received_lines[1], "assemble - Desc", "parsed lines")
  end)
end

local function fetches_gradle_tasks_returns_parsed_tasks()
  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      run_gradle = function()
        return { ok = true, stdout = "assemble - Desc" }
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function()
        return { { name = "assemble", description = "Desc" } }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.cache"] = nil
    package.loaded["android.gradle.cache"] = nil
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    local result = gradle_tasks.fetch_tasks("/root")
    assert.eq(result[1].name, "assemble", "task name")
  end)
end

local function run_task_builds_command_args_sets_root()
  local received_root = nil

  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      build_command = function(root)
        received_root = root
        return { "./gradlew", "clean" }
      end,
    },
    ["android.build.stream"] = {
      start_build_job = function()
        return { ok = true }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.cache"] = nil
    package.loaded["android.gradle.cache"] = nil
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    gradle_tasks.run_task("/root", "clean")
    assert.eq(received_root, "/root", "root")
  end)
end

local function run_task_builds_command_args_sets_task_args()
  local received_task_args = nil

  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      build_command = function(_, args)
        received_task_args = args
        return { "./gradlew", args[1] }
      end,
    },
    ["android.build.stream"] = {
      start_build_job = function()
        return { ok = true }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.cache"] = nil
    package.loaded["android.gradle.cache"] = nil
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    gradle_tasks.run_task("/root", "clean")
    assert.eq(received_task_args[1], "clean", "task arg")
  end)
end

local function run_task_passes_command_to_job_sets_command()
  local received_job_args = nil

  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      build_command = function(_, args)
        return { "./gradlew", args[1] }
      end,
    },
    ["android.build.stream"] = {
      start_build_job = function(_, args)
        received_job_args = args
        return { ok = true }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.cache"] = nil
    package.loaded["android.gradle.cache"] = nil
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    gradle_tasks.run_task("/root", "clean")
    assert.eq(received_job_args[1], "./gradlew", "gradle command")
  end)
end

local function run_task_passes_command_to_job_sets_task_arg()
  local received_job_args = nil

  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      build_command = function(_, args)
        return { "./gradlew", args[1] }
      end,
    },
    ["android.build.stream"] = {
      start_build_job = function(_, args)
        received_job_args = args
        return { ok = true }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.cache"] = nil
    package.loaded["android.gradle.cache"] = nil
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    gradle_tasks.run_task("/root", "clean")
    assert.eq(received_job_args[2], "clean", "job task arg")
  end)
end

local function run_task_invokes_job()
  local job_called = false

  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      build_command = function(_, args)
        return { "./gradlew", args[1] }
      end,
    },
    ["android.build.stream"] = {
      start_build_job = function()
        job_called = true
        return { ok = true }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.cache"] = nil
    package.loaded["android.gradle.cache"] = nil
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    gradle_tasks.run_task("/root", "clean")
    assert.is_true(job_called, "job called")
  end)
end

local function run_task_notifies_on_success()
  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      build_command = function(_, args)
        return { "./gradlew", args[1] }
      end,
    },
    ["android.build.stream"] = {
      start_build_job = function(_, _, on_complete)
        if on_complete then
          on_complete({ ok = true, code = 0 })
        end
        return { ok = true }
      end,
    },
  }

  with_vim_notify_stubs(function(state)
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.state.cache"] = nil
      package.loaded["android.gradle.cache"] = nil
      package.loaded["android.actions.gradle_tasks"] = nil
      local gradle_tasks = require("android.actions.gradle_tasks")
      gradle_tasks.run_task("/root", "clean")
      assert.eq(state.message, "Gradle task completed", "notify message")
    end)
  end)
end

function M.run()
  fetches_gradle_tasks_builds_gradle_args_sets_root()
  fetches_gradle_tasks_builds_gradle_args_sets_args()
  fetches_gradle_tasks_passes_lines_to_parser()
  fetches_gradle_tasks_returns_parsed_tasks()
  run_task_builds_command_args_sets_root()
  run_task_builds_command_args_sets_task_args()
  run_task_passes_command_to_job_sets_command()
  run_task_passes_command_to_job_sets_task_arg()
  run_task_invokes_job()
  run_task_notifies_on_success()
end

return M
