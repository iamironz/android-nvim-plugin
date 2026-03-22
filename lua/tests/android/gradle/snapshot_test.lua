local M = {}

local assert = require("tests.helpers.assert")
local snapshot = require("android.gradle.snapshot")

local function parses_android_modules_and_variants_from_qualified_tasks()
  local result = snapshot.parse({
    ":androidApp:assembleDebug - Assembles debug builds.",
    ":androidApp:installDebug - Installs debug builds.",
    ":app:bundleRelease - Bundles release builds.",
    ":feature:demo:assembleBenchmark - Assembles benchmark builds.",
    ":feature:demo:assembleBenchmarkAndroidTest - Assembles android tests.",
    ":feature:demo:testBenchmarkUnitTest - Runs unit tests.",
  })

  assert.table_eq(
    result.android.modules,
    { ":androidApp", ":app", ":feature:demo" },
    "android modules"
  )
  assert.table_eq(
    result.android.by_module[":androidApp"].variants,
    { "debug" },
    "androidApp variants"
  )
  assert.table_eq(
    result.android.by_module[":app"].variants,
    { "release" },
    "app variants"
  )
  assert.table_eq(
    result.android.by_module[":feature:demo"].variants,
    { "benchmark" },
    "nested module variants"
  )
end

local function returns_empty_android_snapshot_for_unqualified_tasks()
  local result = snapshot.parse({
    "assembleDebug - Assembles debug builds.",
    "installDebug - Installs debug builds.",
    "bundleRelease - Bundles release builds.",
  })

  assert.eq(#result.android.modules, 0, "no qualified android modules")
end

function M.run()
  parses_android_modules_and_variants_from_qualified_tasks()
  returns_empty_android_snapshot_for_unqualified_tasks()
end

return M
