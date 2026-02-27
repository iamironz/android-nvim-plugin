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

local function reset_gradle_caches()
  package.loaded["android.state.cache"] = nil
  package.loaded["android.gradle.cache"] = nil
  package.loaded["android.actions.gradle_tasks"] = nil
end

local function load_gradle_tasks()
  reset_gradle_caches()
  return require("android.actions.gradle_tasks")
end

local function apply_stub_overrides(stubs, overrides)
  if not overrides then
    return stubs
  end

  for key, value in pairs(overrides) do
    stubs[key] = value
  end

  return stubs
end

local function gradle_fetch_task_stubs(overrides)
  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      fetch_task_lines = function()
        return { ok = true, lines = { "assemble - Desc" } }
      end,
      run_gradle = function()
        return { ok = true, stdout = "" }
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function()
        return { { name = "assemble", description = "Desc" } }
      end,
    },
    ["android.gradle.workspace"] = {
      load_modules = function()
        return {}
      end,
      load_included_builds = function()
        return {}
      end,
    },
    ["android.gradle.cache"] = {
      persistent = function()
        return {
          modules = function(_, loader)
            return loader()
          end,
          tasks = function(_, _, loader)
            return loader()
          end,
        }
      end,
    },
  }

  return apply_stub_overrides(stubs, overrides)
end

local function gradle_run_task_stubs(overrides)
  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.build_helpers"] = {
      build_command = function(_, args)
        return { "./gradlew", args[1] }
      end,
    },
    ["android.build.stream"] = {
      start_build_job = function()
        return { ok = true }
      end,
    },
  }

  return apply_stub_overrides(stubs, overrides)
end

local function gradle_open_stubs(overrides)
  local stubs = {
    ["android.state.selection_store"] = build_selection_store(),
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/root" }
      end,
    },
    ["android.actions.build_helpers"] = {
      fetch_task_lines = function()
        return { ok = true, lines = { "assemble - Desc" } }
      end,
      run_gradle = function()
        return { ok = true, stdout = "" }
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function()
        return { { name = "assemble", description = "Desc" } }
      end,
    },
    ["android.gradle.workspace"] = {
      load_modules = function()
        return {}
      end,
      load_included_builds = function()
        return {}
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return {}
      end,
    },
    ["android.gradle.cache"] = {
      persistent = function()
        return {
          modules = function(_, loader)
            return loader()
          end,
          tasks = function(_, _, loader)
            return loader()
          end,
        }
      end,
    },
    ["telescope.pickers"] = {
      new = function()
        return { find = function() end }
      end,
    },
    ["telescope.finders"] = { new_table = function() return {} end },
    ["telescope.config"] = { values = { generic_sorter = function() return {} end } },
    ["telescope.actions"] = {
      close = function() end,
      select_default = { replace = function() end },
    },
    ["telescope.actions.state"] = {
      get_selected_entry = function()
        return { value = "assemble" }
      end,
    },
  }

  return apply_stub_overrides(stubs, overrides)
end

local function with_gradle_tasks(stubs, fn)
  stubs_helper.with_stubs(stubs, function()
    local gradle_tasks = load_gradle_tasks()
    fn(gradle_tasks)
  end)
end

local function fetches_gradle_tasks_builds_gradle_args_sets_root()
  local received_root = nil

  local stubs = gradle_fetch_task_stubs({
    ["android.actions.build_helpers"] = {
      fetch_task_lines = function(root)
        received_root = root
        return { ok = true, lines = { "assemble - Desc" } }
      end,
      run_gradle = function()
        return { ok = true, stdout = "" }
      end,
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.fetch_tasks("/root")
    assert.eq(received_root, "/root", "root")
  end)
end

local function fetches_gradle_tasks_queries_included_build_tasks()
  local received_args = nil

  local stubs = gradle_fetch_task_stubs({
    ["android.gradle.workspace"] = {
      load_modules = function()
        return {}
      end,
      load_included_builds = function()
        return { { name = "client", root = "/root/client", path = "client" } }
      end,
    },
    ["android.actions.build_helpers"] = {
      fetch_task_lines = function()
        return { ok = true, lines = { "assemble - Desc" } }
      end,
      run_gradle = function(_, args)
        received_args = args
        return { ok = true, stdout = "app:assembleDebug - Desc" }
      end,
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.fetch_tasks("/root")
    assert.eq(received_args[1], ":client:tasks", "included tasks arg 1")
    assert.eq(received_args[2], "--all", "arg 2")
  end)
end

local function fetches_gradle_tasks_discovers_included_builds_from_projects_output()
  local projects_called = 0
  local included_called = 0

  local stubs = gradle_fetch_task_stubs({
    ["android.actions.build_helpers"] = {
      fetch_task_lines = function()
        return { ok = true, lines = { "assemble - Desc" } }
      end,
      run_gradle = function(_, args)
        if args[1] == "projects" then
          projects_called = projects_called + 1
          return { ok = true, stdout = "+--- Included build ':client'" }
        end
        if args[1] == ":client:tasks" then
          included_called = included_called + 1
          return { ok = true, stdout = "app:assembleDebug - Desc" }
        end
        return { ok = true, stdout = "" }
      end,
    },
    ["android.gradle.workspace"] = {
      load_modules = function()
        return {}
      end,
      load_included_builds = function()
        return {}
      end,
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.fetch_tasks("/root")
    assert.eq(projects_called, 1, "projects command called")
    assert.eq(included_called, 1, "included build tasks command called")
  end)
end

local function fetches_gradle_tasks_passes_lines_to_parser()
  local received_lines = nil

  local stubs = gradle_fetch_task_stubs({
    ["android.gradle.workspace"] = {
      load_modules = function()
        return {}
      end,
      load_included_builds = function()
        return { { name = "client", root = "/root/client", path = "client" } }
      end,
    },
    ["android.actions.build_helpers"] = {
      fetch_task_lines = function()
        return { ok = true, lines = { "assemble - Desc" } }
      end,
      run_gradle = function()
        return { ok = true, stdout = "app:assembleDebug - Desc" }
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function(lines)
        received_lines = lines
        return { { name = "assemble", description = "Desc" } }
      end,
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.fetch_tasks("/root")
    assert.eq(received_lines[1], "assemble - Desc", "parsed lines")
    local has_qualified = false
    for _, line in ipairs(received_lines or {}) do
      if line == ":client:app:assembleDebug - Desc" then
        has_qualified = true
        break
      end
    end
    assert.eq(has_qualified, true, "included build task line qualified")
  end)
end

local function fetches_gradle_tasks_returns_parsed_tasks()
  local stubs = gradle_fetch_task_stubs()

  with_gradle_tasks(stubs, function(gradle_tasks)
    local result = gradle_tasks.fetch_tasks("/root")
    assert.eq(result[1].name, "assemble", "task name")
  end)
end

local function run_task_builds_command_args_sets_root()
  local received_root = nil

  local stubs = gradle_run_task_stubs({
    ["android.actions.build_helpers"] = {
      build_command = function(root)
        received_root = root
        return { "./gradlew", "clean" }
      end,
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.run_task("/root", "clean")
    assert.eq(received_root, "/root", "root")
  end)
end

local function run_task_builds_command_args_sets_task_args()
  local received_task_args = nil

  local stubs = gradle_run_task_stubs({
    ["android.actions.build_helpers"] = {
      build_command = function(_, args)
        received_task_args = args
        return { "./gradlew", args[1] }
      end,
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.run_task("/root", "clean")
    assert.eq(received_task_args[1], "clean", "task arg")
  end)
end

local function run_task_passes_command_to_job_sets_command()
  local received_job_args = nil

  local stubs = gradle_run_task_stubs({
    ["android.build.stream"] = {
      start_build_job = function(_, args)
        received_job_args = args
        return { ok = true }
      end,
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.run_task("/root", "clean")
    assert.eq(received_job_args[1], "./gradlew", "gradle command")
  end)
end

local function run_task_passes_command_to_job_sets_task_arg()
  local received_job_args = nil

  local stubs = gradle_run_task_stubs({
    ["android.build.stream"] = {
      start_build_job = function(_, args)
        received_job_args = args
        return { ok = true }
      end,
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.run_task("/root", "clean")
    assert.eq(received_job_args[2], "clean", "job task arg")
  end)
end

local function run_task_invokes_job()
  local job_called = false

  local stubs = gradle_run_task_stubs({
    ["android.build.stream"] = {
      start_build_job = function()
        job_called = true
        return { ok = true }
      end,
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.run_task("/root", "clean")
    assert.is_true(job_called, "job called")
  end)
end

local function run_task_notifies_on_success()
  local stubs = gradle_run_task_stubs({
    ["android.build.stream"] = {
      start_build_job = function(_, _, on_complete)
        if on_complete then
          on_complete({ ok = true, code = 0 })
        end
        return { ok = true }
      end,
    },
  })

  with_vim_notify_stubs(function(state)
    with_gradle_tasks(stubs, function(gradle_tasks)
      gradle_tasks.run_task("/root", "clean")
      assert.eq(state.message, "Gradle task completed", "notify message")
    end)
  end)
end

local function open_forwards_on_cancel_and_escape_calls_it()
  local canceled = 0
  local closed = 0
  local mapped = { i = false, n = false }
  local captured = { opts = nil }

  local stubs = gradle_open_stubs({
    ["telescope.pickers"] = {
      new = function(_, opts)
        captured.opts = opts
        return { find = function() end }
      end,
    },
    ["telescope.actions"] = {
      close = function()
        closed = closed + 1
      end,
      select_default = { replace = function() end },
    },
  })

  with_gradle_tasks(stubs, function(gradle_tasks)
    gradle_tasks.open({
      on_cancel = function()
        canceled = canceled + 1
      end,
    })
  end)

  captured.opts.attach_mappings(1, function(mode, lhs, rhs)
    if lhs == "<esc>" then
      mapped[mode] = true
      rhs()
    end
  end)

  assert.eq(mapped.i, true, "mapped insert")
  assert.eq(mapped.n, true, "mapped normal")
  assert.eq(canceled, 2, "on_cancel called")
  assert.eq(closed, 2, "picker closed")
end

function M.run()
  fetches_gradle_tasks_builds_gradle_args_sets_root()
  fetches_gradle_tasks_queries_included_build_tasks()
  fetches_gradle_tasks_discovers_included_builds_from_projects_output()
  fetches_gradle_tasks_passes_lines_to_parser()
  fetches_gradle_tasks_returns_parsed_tasks()
  run_task_builds_command_args_sets_root()
  run_task_builds_command_args_sets_task_args()
  run_task_passes_command_to_job_sets_command()
  run_task_passes_command_to_job_sets_task_arg()
  run_task_invokes_job()
  run_task_notifies_on_success()
  open_forwards_on_cancel_and_escape_calls_it()
end

return M
