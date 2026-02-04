local M = {}

local function base_name(path, suffix)
  if not path or path == "" then
    return nil
  end
  local name = path:match("([^/]+)$")
  if not name then
    return nil
  end
  if suffix and name:sub(-#suffix) == suffix then
    return name:sub(1, #name - #suffix)
  end
  return name
end

local function preferred_scheme(ios, schemes)
  local base = base_name(ios and ios.workspace, ".xcworkspace")
    or base_name(ios and ios.project, ".xcodeproj")
  if base then
    for _, scheme in ipairs(schemes or {}) do
      if scheme == base then
        return scheme
      end
    end
  end
  for _, scheme in ipairs(schemes or {}) do
    if type(scheme) == "string" and scheme:lower() == "ios" then
      return scheme
    end
  end
  return (schemes or {})[1]
end

function M.detect(workspace, _, opts)
  if not workspace or not workspace.ios then
    return {}
  end
  local schemes = opts and opts.schemes or nil
  local scheme = preferred_scheme(workspace.ios, schemes)
  return {
    {
      id = "ios",
      label = "iOS",
      target = "ios",
      type = "ios",
      meta = {
        root = workspace.ios.root,
        workspace = workspace.ios.workspace,
        project = workspace.ios.project,
        package = workspace.ios.package,
        scheme = scheme,
      },
    },
  }
end

return M
