local M = {}

local assert = require("tests.helpers.assert")
local highlight = require("android.logcat.highlight")

local GROUPS = {
  "AndroidLogcatError",
  "AndroidLogcatWarn",
  "AndroidLogcatInfo",
  "AndroidLogcatDebug",
}

local function clear_groups()
  for _, group in ipairs(GROUPS) do
    vim.api.nvim_set_hl(0, group, {})
  end
end

local function assert_link(group, expected)
  local definition = vim.api.nvim_get_hl(0, { name = group, link = true })

  assert.eq(definition.link, expected, group .. " link")
end

local function links_log_levels_to_diagnostic_groups()
  clear_groups()

  highlight.setup()

  assert_link("AndroidLogcatError", "DiagnosticError")
  assert_link("AndroidLogcatWarn", "DiagnosticWarn")
  assert_link("AndroidLogcatInfo", "DiagnosticInfo")
  assert_link("AndroidLogcatDebug", "DiagnosticHint")
end

local function preserves_user_highlight_overrides()
  clear_groups()
  vim.api.nvim_set_hl(0, "AndroidLogcatError", { fg = "#123456" })

  highlight.setup()

  local definition = vim.api.nvim_get_hl(0, { name = "AndroidLogcatError", link = true })

  assert.eq(definition.link, nil, "override link")
  assert.eq(definition.fg, tonumber("123456", 16), "override fg")
end

function M.run()
  links_log_levels_to_diagnostic_groups()
  preserves_user_highlight_overrides()
end

return M
