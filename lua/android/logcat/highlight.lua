local M = {}

local LOGCAT_NS = vim.api.nvim_create_namespace("android_logcat")
local LEVEL_GROUPS = {
  E = "AndroidLogcatError",
  W = "AndroidLogcatWarn",
  I = "AndroidLogcatInfo",
  D = "AndroidLogcatDebug",
}

local function detect_level(line)
  if type(line) ~= "string" then
    return nil
  end
  return line:match("%s([VDIWE])/") or line:match("%s([VDIWE])%s")
end

function M.setup()
  vim.api.nvim_set_hl(0, "AndroidLogcatError", { fg = "Red" })
  vim.api.nvim_set_hl(0, "AndroidLogcatWarn", { fg = "Yellow" })
  vim.api.nvim_set_hl(0, "AndroidLogcatInfo", { fg = "Blue" })
  vim.api.nvim_set_hl(0, "AndroidLogcatDebug", { fg = "Green" })
end

function M.clear(buf)
  vim.api.nvim_buf_clear_namespace(buf, LOGCAT_NS, 0, -1)
end

function M.apply(buf, start_line, lines)
  for index, line in ipairs(lines or {}) do
    local level = detect_level(line)
    local group = LEVEL_GROUPS[level]
    if group then
      local line_index = start_line + index - 1
      vim.api.nvim_buf_add_highlight(buf, LOGCAT_NS, group, line_index, 0, -1)
    end
  end
end

return M
