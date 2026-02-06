local M = {}
local function panel()
  return require("android.ui.panel")
end
local panel_header = require("android.ui.panel_header")
local highlight = require("android.logcat.highlight")

local function resolve_build_context(session)
  local state = session and session.state or nil
  local build = state and state.build or nil
  return {
    module = build and build.module or nil,
    variant = build and build.variant or nil,
  }
end

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
  local build_context = resolve_build_context(session)
  if panel().set_names then
    panel().set_names(panel_header.logcat_panel_names({
      module = build_context.module,
      variant = build_context.variant,
      package = session.package,
      filter = session.filter,
      level = session.level,
    }))
  end
  panel().set_header_lines(build_header_lines(session))
end

local function render_session(session)
  if not session.active then
    return
  end
  render_header(session)
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
