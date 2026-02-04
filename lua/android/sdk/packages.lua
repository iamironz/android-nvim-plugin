local M = {}

local strings = require("android.utils.strings")

local function is_installed_header(line)
  return line:match("^%s*Installed packages:%s*$") ~= nil
end

local function is_section_header(line)
  return line:match("^%s*Available Packages:%s*$")
    or line:match("^%s*Available packages:%s*$")
    or line:match("^%s*Available Updates:%s*$")
end

local function parse_package_path(line)
  local path = line:match("^([^|]+)|") or line:match("^(%S+)")
  path = strings.trim(path)
  if path == "" then
    return nil
  end
  return path
end

function M.parse_installed(lines)
  local installed = {}
  local in_section = false

  for _, line in ipairs(lines or {}) do
    local trimmed = strings.trim(line)
    if is_installed_header(trimmed) then
      in_section = true
      goto continue
    end

    if in_section and is_section_header(trimmed) then
      break
    end

    if not in_section then
      goto continue
    end

    if trimmed == "" or trimmed:match("^Path%s*|") or trimmed:match("^%-+") then
      goto continue
    end

    local path = parse_package_path(trimmed)
    if path then
      installed[path] = true
    end

    ::continue::
  end

  local result = {}
  for path in pairs(installed) do
    table.insert(result, path)
  end
  table.sort(result)
  return result
end

function M.list_build_tools(packages)
  local versions = {}
  for _, entry in ipairs(packages or {}) do
    local version = entry:match("^build%-tools;(.+)$")
    if version then
      versions[version] = true
    end
  end

  local result = {}
  for version in pairs(versions) do
    table.insert(result, version)
  end
  table.sort(result)
  return result
end

function M.list_platform_tools(packages)
  local platforms = {}
  for _, entry in ipairs(packages or {}) do
    if entry == "platform-tools" then
      platforms[entry] = true
    end
  end

  local result = {}
  for entry in pairs(platforms) do
    table.insert(result, entry)
  end
  table.sort(result)
  return result
end

function M.list_system_images(packages)
  local images = {}
  for _, entry in ipairs(packages or {}) do
    if entry:match("^system%-images;") then
      images[entry] = true
    end
  end

  local result = {}
  for entry in pairs(images) do
    table.insert(result, entry)
  end
  table.sort(result)
  return result
end

return M
