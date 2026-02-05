# Esc Back Navigation for Android Modals Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan
> task-by-task.

**Goal:** Ensure all Android modal pickers opened from Actions support Esc to return to the
parent screen.

**Architecture:** The Actions picker provides a reopen callback through the actions registry.
Action modules forward opts.on_cancel into picker modals and nested pickers provide step back
callbacks. The Gradle tasks picker maps Esc to on_cancel.

**Tech Stack:** Lua, Neovim API, Telescope pickers

---

### Task 1: Actions picker back handler

**Files:**
- Modify: `lua/tests/android/ui/actions_picker_test.lua`
- Modify: `lua/android/ui/actions.lua`
- Modify: `lua/android/actions/registry.lua`

**Step 1: Write the failing test**

```lua
local function action_picker_passes_back_handler_to_registry()
  local received_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return {
          {
            title = "Targets",
            items = {
              { id = "build_default", label = "Build default" },
            },
          },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        if opts.on_select then
          opts.on_select("build_default")
        end
      end,
    },
    ["android.actions.registry"] = {
      run = function(_, opts)
        received_opts = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.actions"] = nil
    local actions = require("android.ui.actions")
    actions.open()
  end)

  assert.is_true(type(received_opts and received_opts.on_cancel) == "function", "back handler")
end
```

Add the new test to `M.run()`.

**Step 2: Run test to verify it fails**

Run: `./scripts/run-tests.sh tests.android.ui.actions_picker_test`
Expected: FAIL with missing back handler

**Step 3: Write minimal implementation**

```lua
local function reopen_actions(options)
  return function()
    M.open(options)
  end
end

function M.open(opts)
  local options = opts or {}
  -- existing code
  local reopen = reopen_actions(options)
  picker.select_from_list({
    -- existing fields
    on_select = function(action_id)
      if action_id then
        actions.run(action_id, { on_cancel = reopen })
      end
    end,
  })
end
```

In `android.actions.registry`, accept a second argument and call `action(opts)`.

**Step 4: Run test to verify it passes**

Run: `./scripts/run-tests.sh tests.android.ui.actions_picker_test`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/tests/android/ui/actions_picker_test.lua \
  lua/android/ui/actions.lua \
  lua/android/actions/registry.lua
git commit -m "fix: pass back handler into actions"
```

### Task 2: Build modal step back and on_cancel propagation

**Files:**
- Modify: `lua/tests/android/actions/build_prompt_test.lua`
- Modify: `lua/tests/android/actions/list_apks_test.lua`
- Modify: `lua/android/actions/build.lua`

**Step 1: Write the failing tests**

Add a build prompt test that cancels the variant picker and reopens the module picker.

```lua
local function build_prompt_reopens_module_on_variant_cancel()
  local picker_calls = {}
  local back_called = false

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
    },
    ["android.actions.build_helpers"] = {
      module_entries = function() return { { label = "app", value = ":app" } } end,
      fetch_variants = function() return { "debug" } end,
    },
    ["android.command.runner"] = {
      new = function() return { run = function() return { ok = true } end } end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_calls[#picker_calls + 1] = opts
        if #picker_calls == 1 then
          opts.on_select(":app")
          return
        end
        if #picker_calls == 2 then
          if opts.on_cancel then opts.on_cancel() end
          return
        end
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    local build = require("android.actions.build")
    build.build_prompt({ on_cancel = function() back_called = true end })
  end)

  assert.eq(picker_calls[1].title, "Gradle modules", "module picker")
  assert.eq(picker_calls[2].title, "Build variants", "variant picker")
  assert.eq(picker_calls[3].title, "Gradle modules", "module reopened")
  picker_calls[1].on_cancel()
  assert.eq(back_called, true, "module cancel")
end
```

Add a list APKs test that verifies on_cancel is forwarded.

```lua
local function list_apks_passes_on_cancel()
  local canceled = false
  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return { build = { module = ":app", variant = "debug" } }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        if opts.on_cancel then opts.on_cancel() end
      end,
    },
    ["android.build.apk"] = {
      list_apk_paths = function()
        return { ok = true, apks = { "/workspace/app.apk" } }
      end,
      list_workspace_apks = function()
        return { ok = false, error = "no apks" }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    local build = require("android.actions.build")
    build.list_apks({ on_cancel = function() canceled = true end })
  end)

  assert.eq(canceled, true, "list apks cancel")
end
```

Add both tests to `M.run()`.

**Step 2: Run test to verify it fails**

Run: `./scripts/run-tests.sh tests.android.actions.build_prompt_test`
Expected: FAIL with missing reopen or cancel handler

**Step 3: Write minimal implementation**

- Update `prompt_for_module` and `prompt_for_variant` to accept `opts` and pass `opts.on_cancel`
  into `picker.select_from_list`.
- In `build_prompt`, pass `opts` into the module picker, and set the variant picker on_cancel to
  reopen the module picker.
- Update `select_module`, `select_variant`, and `list_apks` to pass `opts.on_cancel` through.

**Step 4: Run test to verify it passes**

Run: `./scripts/run-tests.sh tests.android.actions.build_prompt_test`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/tests/android/actions/build_prompt_test.lua \
  lua/tests/android/actions/list_apks_test.lua \
  lua/android/actions/build.lua
git commit -m "fix: add back navigation to build modals"
```

### Task 3: Devices modal step back and on_cancel propagation

**Files:**
- Create: `lua/tests/android/actions/devices_test.lua`
- Modify: `lua/android/actions/devices.lua`

**Step 1: Write the failing tests**

```lua
local function select_device_passes_on_cancel()
  local canceled = false
  local stubs = {
    ["android.actions.context"] = {
      workspace = function() return { root = "/root" } end,
    },
    ["android.sdk.discovery"] = {
      new = function() return { tools = function() return { adb = "/bin/adb" } end } end,
    },
    ["android.command.runner"] = { new = function() return {} end },
    ["android.devices.adb"] = { list = function() return { { serial = "device-1", state = "device" } } end },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        if opts.on_cancel then opts.on_cancel() end
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.devices"] = nil
    local devices = require("android.actions.devices")
    devices.select_device({ on_cancel = function() canceled = true end })
  end)

  assert.eq(canceled, true, "select device cancel")
end

local function create_avd_step_back_to_device_picker()
  local calls = {}
  local stubs = {
    ["android.actions.context"] = {
      workspace = function() return { root = "/root" } end,
    },
    ["android.sdk.discovery"] = {
      new = function()
        return {
          tools = function() return { avdmanager = "/bin/avdmanager" } end,
          packages = function() return {} end,
        }
      end,
    },
    ["android.command.runner"] = { new = function() return { run = function() return { ok = true } end } end },
    ["android.devices.avd"] = { list_devices = function() return { { id = "pixel", name = "Pixel" } } end },
    ["android.sdk.packages"] = { list_system_images = function() return { "system-1" } end },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        calls[#calls + 1] = opts
        if #calls == 1 then
          opts.on_select("pixel")
          return
        end
        if #calls == 2 then
          if opts.on_cancel then opts.on_cancel() end
        end
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.devices"] = nil
    local devices = require("android.actions.devices")
    devices.create_avd({ on_cancel = function() end })
  end)

  assert.eq(calls[1].title, "AVD device profiles", "device picker")
  assert.eq(calls[2].title, "System images", "system picker")
  assert.eq(calls[3].title, "AVD device profiles", "device reopened")
end
```

Add both tests to `M.run()`.

**Step 2: Run test to verify it fails**

Run: `./scripts/run-tests.sh tests.android.actions.devices_test`
Expected: FAIL with missing on_cancel or reopen

**Step 3: Write minimal implementation**

- Allow `select_device`, `select_avd`, `stop_emulator`, and `create_avd` to accept `opts`
- Pass `opts.on_cancel` into `picker.select_from_list`
- In `create_avd`, set system images picker on_cancel to reopen the device picker

**Step 4: Run test to verify it passes**

Run: `./scripts/run-tests.sh tests.android.actions.devices_test`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/tests/android/actions/devices_test.lua \
  lua/android/actions/devices.lua
git commit -m "fix: add back navigation to device modals"
```

### Task 4: Run config modal on_cancel propagation

**Files:**
- Modify: `lua/tests/android/run/ui_test.lua`
- Modify: `lua/android/run/ui.lua`

**Step 1: Write the failing test**

```lua
local function select_passes_on_cancel()
  local canceled = false
  local stubs = {
    ["android.actions.context"] = {
      workspace = function() return registry_helper.build_workspace() end,
    },
    ["android.run.registry"] = {
      list = function() return { { id = "android", label = "Android" } } end,
      select = function() return "android" end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        if opts.on_cancel then opts.on_cancel() end
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.ui"] = nil
    local ui = require("android.run.ui")
    ui.select({ on_cancel = function() canceled = true end })
  end)

  assert.eq(canceled, true, "run select cancel")
end
```

Add the test to `M.run()`.

**Step 2: Run test to verify it fails**

Run: `./scripts/run-tests.sh tests.android.run.ui_test`
Expected: FAIL with missing on_cancel

**Step 3: Write minimal implementation**

- Update `run.ui.select` to accept `opts` as a table
- Pass `opts.on_cancel` into `picker.select_from_list`

**Step 4: Run test to verify it passes**

Run: `./scripts/run-tests.sh tests.android.run.ui_test`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/tests/android/run/ui_test.lua \
  lua/android/run/ui.lua
git commit -m "fix: add back navigation to run config modal"
```

### Task 5: Gradle tasks modal on_cancel

**Files:**
- Modify: `lua/tests/android/actions/gradle_tasks_test.lua`
- Modify: `lua/android/actions/gradle_tasks.lua`

**Step 1: Write the failing test**

```lua
local function open_calls_on_cancel_on_escape()
  local canceled = false
  local captured = { opts = nil }
  local stubs = {
    ["android.actions.context"] = {
      workspace = function() return { root = "/root" } end,
    },
    ["android.actions.build_helpers"] = {
      run_gradle = function() return { ok = true, stdout = "assemble - Desc" } end,
    },
    ["android.gradle.tasks"] = {
      parse = function() return { { name = "assemble", description = "Desc" } } end,
    },
    ["android.gradle.cache"] = {
      persistent = function()
        return {
          modules = function(_, loader) return loader() end,
          tasks = function(_, _, loader) return loader() end,
        }
      end,
    },
    ["android.gradle.workspace"] = { load_modules = function() return { ":app" } end },
    ["telescope.pickers"] = {
      new = function(_, opts)
        captured.opts = opts
        return { find = function() end }
      end,
    },
    ["telescope.finders"] = { new_table = function() return {} end },
    ["telescope.config"] = { values = { generic_sorter = function() return {} end } },
    ["telescope.actions"] = { close = function() end, select_default = { replace = function() end } },
    ["telescope.actions.state"] = { get_selected_entry = function() return { value = "assemble" } end },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.gradle_tasks"] = nil
    local gradle_tasks = require("android.actions.gradle_tasks")
    gradle_tasks.open({ on_cancel = function() canceled = true end })
  end)

  captured.opts.attach_mappings(1, function(mode, lhs, rhs)
    if mode == "i" and lhs == "<esc>" then
      rhs()
    end
  end)

  assert.eq(canceled, true, "gradle tasks cancel")
end
```

Add the test to `M.run()`.

**Step 2: Run test to verify it fails**

Run: `./scripts/run-tests.sh tests.android.actions.gradle_tasks_test`
Expected: FAIL with missing on_cancel

**Step 3: Write minimal implementation**

- Update `gradle_tasks.open` to accept `opts` and pass `opts.on_cancel` into `build_picker`
- In `build_picker`, map `<esc>` in insert and normal mode to close and call on_cancel

**Step 4: Run test to verify it passes**

Run: `./scripts/run-tests.sh tests.android.actions.gradle_tasks_test`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/tests/android/actions/gradle_tasks_test.lua \
  lua/android/actions/gradle_tasks.lua
git commit -m "fix: add back navigation to gradle tasks modal"
```

### Task 6: Final verification

**Files:**
- None

**Step 1: Run the full test suite**

Run: `./scripts/run-tests.sh`
Expected: PASS

**Step 2: Commit remaining changes**

```bash
git add docs/plans/2026-02-05-esc-modal-back-design.md \
  docs/plans/2026-02-05-esc-modal-back.md
git commit -m "docs: add esc modal back plan"
```
