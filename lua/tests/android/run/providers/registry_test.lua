local M = {}

local assert = require("tests.helpers.assert")

local function builds_ordered_list()
  local registry = require("android.run.providers.registry")
  local list = registry.list({}, {}, {
    providers = {
      {
        id = "ios",
        priority = 20,
        detect = function()
          return { { id = "ios:app", label = "iOS", target = "ios" } }
        end,
      },
      {
        id = "android",
        priority = 10,
        detect = function()
          return { { id = "android:app", label = "Android", target = "android" } }
        end,
      },
    },
  })

  assert.eq(list[1].id, "android:app", "android first")
  assert.eq(list[2].id, "ios:app", "ios second")
end

local function skips_empty_providers()
  local registry = require("android.run.providers.registry")
  local list = registry.list({}, {}, {
    providers = {
      {
        id = "empty",
        priority = 10,
        detect = function()
          return nil
        end,
      },
    },
  })

  assert.eq(#list, 0, "empty list")
end

function M.run()
  builds_ordered_list()
  skips_empty_providers()
end

return M
