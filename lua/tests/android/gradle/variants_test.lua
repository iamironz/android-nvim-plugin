local M = {}

local assert = require("tests.helpers.assert")

local function parses_variants_from_gradle_tasks()
  local variants = require("android.gradle.variants").parse({
    "assembleDebug - Assembles a debug build",
    "assembleFreeRelease - Assembles a release build",
    "bundleRelease - Builds a bundle for release",
    "assemble - Assembles all variants",
    ":app:assembleBetaDebug - Assemble beta debug",
  })

  assert.table_eq(
    variants,
    { "betaDebug", "debug", "freeRelease", "release" },
    "parsed variants"
  )
end

local function returns_empty_when_no_variants()
  local variants = require("android.gradle.variants").parse({
    "clean - Deletes build directory",
  })

  assert.eq(#variants, 0, "empty variants")
end

function M.run()
  parses_variants_from_gradle_tasks()
  returns_empty_when_no_variants()
end

return M
