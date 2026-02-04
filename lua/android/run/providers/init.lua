local android = require("android.run.providers.android")
local gradle_task = require("android.run.providers.gradle_task")
local ios = require("android.run.providers.ios")
local jvm = require("android.run.providers.jvm")
local shell = require("android.run.providers.shell")

local M = {}

function M.defaults()
  return {
    { id = "android", priority = 10, detect = android.detect },
    { id = "ios", priority = 20, detect = ios.detect },
    { id = "jvm", priority = 30, detect = jvm.detect },
    { id = "gradle_task", priority = 40, detect = gradle_task.detect },
    { id = "shell", priority = 50, detect = shell.detect },
  }
end

return M
