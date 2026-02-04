local M = {}
local function panel()
  return require("android.ui.panel")
end
local panel_header = require("android.ui.panel_header")
local highlight = require("android.logcat.highlight")

local function build_header_lines(session)
  return panel_header.logcat_lines({
    package = session.package,
    filter = session.filter,
    level = session.level,
  })
end

local function render_header(session)
  if not session.active then
    return
  end
  panel().set_header_lines(build_header_lines(session))
end

local function render_session(session)
  if not session.active then
    return
  end
  panel().set_header_lines(build_header_lines(session))
  highlight.clear(session.buf)
  if session.status_message then
    panel().replace_body({ session.status_message })
    return
  end
  panel().replace_body(session.body_lines)
  highlight.apply(session.buf, session.header_count, session.body_lines)
end

M.build_header_lines = build_header_lines
M.render_header = render_header
M.render_session = render_session

return M
