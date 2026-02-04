local M = {}

local modules = require("tests.android.gradle.cache_modules_test")
local tasks = require("tests.android.gradle.cache_tasks_test")
local variants = require("tests.android.gradle.cache_variants_test")
local stamps = require("tests.android.gradle.cache_stamp_test")
local persistent = require("tests.android.gradle.cache_persistent_test")

function M.run()
  modules.run()
  tasks.run()
  variants.run()
  stamps.run()
  persistent.run()
end

return M
