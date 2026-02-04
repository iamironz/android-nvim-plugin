local M = {}

local assert = require("tests.helpers.assert")
local tasks = require("android.gradle.tasks")

local function parses_gradle_tasks_output()
  local lines = {
    "Build tasks",
    "-----------",
    "assemble - Assembles the outputs of this project.",
    ":app:assembleDebug - Assembles debug builds.",
    ":app:check",
    "clean - Deletes the build directory.",
    "help",
    "tasks - Displays the tasks runnable from root project.",
    "publish -",
    "",
    "Other tasks",
    "------------",
    ":app:lintDebug - Runs lint on debug builds.",
  }

  local result = tasks.parse(lines)

  assert.eq(#result, 8, "task count")
  assert.eq(result[1].name, ":app:assembleDebug", "task 1 name")
  assert.eq(result[1].description, "Assembles debug builds.", "task 1 desc")
  assert.eq(result[2].name, ":app:check", "task 2 name")
  assert.eq(result[2].description, "", "task 2 desc")
  assert.eq(result[3].name, ":app:lintDebug", "task 3 name")
  assert.eq(result[3].description, "Runs lint on debug builds.", "task 3 desc")
  assert.eq(result[4].name, "assemble", "task 4 name")
  assert.eq(result[4].description, "Assembles the outputs of this project.", "task 4 desc")
  assert.eq(result[5].name, "clean", "task 5 name")
  assert.eq(result[5].description, "Deletes the build directory.", "task 5 desc")
  assert.eq(result[6].name, "help", "task 6 name")
  assert.eq(result[6].description, "", "task 6 desc")
  assert.eq(result[7].name, "publish", "task 7 name")
  assert.eq(result[7].description, "", "task 7 desc")
  assert.eq(result[8].name, "tasks", "task 8 name")
  assert.eq(result[8].description, "Displays the tasks runnable from root project.", "task 8 desc")
end

function M.run()
  parses_gradle_tasks_output()
end

return M
