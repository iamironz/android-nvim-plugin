local M = {}

local assert = require("tests.helpers.assert")

local function parses_included_builds_from_gradle_projects_output()
  local projects = require("android.gradle.projects")
  local names = projects.parse_included_builds({
    "Included builds:",
    "",
    "+--- Included build ':client'",
    "+--- Included build ':driver'",
    "\\--- Included build ':common'",
  })

  assert.table_eq(names, { "client", "common", "driver" }, "included build names")
end

local function de_duplicates_included_build_names()
  local projects = require("android.gradle.projects")
  local names = projects.parse_included_builds({
    "+--- Included build ':client'",
    "\\--- Included build ':client'",
  })

  assert.table_eq(names, { "client" }, "dedup included build names")
end

function M.run()
  parses_included_builds_from_gradle_projects_output()
  de_duplicates_included_build_names()
end

return M
