local M = {}

local assert = require("tests.helpers.assert")

local function returns_no_match_when_cached_snapshot_misses_requested_module()
  local build_variants = require("android.actions.build_variants")
  local variants = build_variants.from_task_lines({
    ":app:assembleDebug - Assembles a debug build",
    ":app:assembleRelease - Assembles a release build",
  }, ":mesh_service_example", {
    android = {
      modules = { ":app" },
      by_module = {
        [":app"] = { variants = { "debug", "release" } },
      },
    },
  })

  assert.eq(#variants, 0, "missing module does not reuse workspace-wide variants")
end

function M.run()
  returns_no_match_when_cached_snapshot_misses_requested_module()
end

return M
