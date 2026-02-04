local M = {}

local assert = require("tests.helpers.assert")
local gradle = require("android.build.gradle")

local function builds_assemble_task_with_module_and_variant()
  local task = gradle.assemble_task(":app", "freeRelease")
  assert.eq(task, ":app:assembleFreeRelease", "assemble task with module")
end

local function builds_assemble_task_with_module_without_colon()
  local task = gradle.assemble_task("app", "debug")
  assert.eq(task, ":app:assembleDebug", "assemble task without colon")
end

local function builds_assemble_task_without_module()
  local task = gradle.assemble_task(nil, "debug")
  assert.eq(task, "assembleDebug", "assemble task without module")
end

local function builds_assemble_command_with_wrapper()
  local cmd = gradle.assemble_command("./gradlew", ":app", "debug")
  assert.table_eq(cmd, { "./gradlew", ":app:assembleDebug" }, "assemble command")
end

local function builds_assemble_command_from_table()
  local cmd = gradle.assemble_command({ "./gradlew", "--quiet" }, "app", "debug")
  assert.table_eq(
    cmd,
    { "./gradlew", "--quiet", ":app:assembleDebug" },
    "assemble command table"
  )
end

function M.run()
  builds_assemble_task_with_module_and_variant()
  builds_assemble_task_with_module_without_colon()
  builds_assemble_task_without_module()
  builds_assemble_command_with_wrapper()
  builds_assemble_command_from_table()
end

return M
