local M = {}

local function task_name(line)
  if type(line) ~= "string" then
    return nil
  end
  return line:match("^%s*([^%s]+)")
end

local function last_segment(task)
  if not task then
    return nil
  end
  return task:match("([^:]+)$")
end

local function variant_from_task(task)
  if not task then
    return nil
  end

  local raw = task:match("^assemble(%u[%w]+)$")
    or task:match("^bundle(%u[%w]+)$")
  if not raw then
    return nil
  end

  return raw:sub(1, 1):lower() .. raw:sub(2)
end

function M.parse(lines)
  local variants = {}

  for _, line in ipairs(lines or {}) do
    local task = last_segment(task_name(line))
    local variant = variant_from_task(task)
    if variant then
      variants[variant] = true
    end
  end

  local result = {}
  for variant in pairs(variants) do
    table.insert(result, variant)
  end
  table.sort(result)
  return result
end

-- detect isDefault markers from build.gradle content
-- returns { default_build_type = "debug", default_flavors = { "prelive", "googlePlay", "bolt" } }

local function is_default_line(line)
  if not line or type(line) ~= "string" then
    return false
  end
  -- Groovy: isDefault true / isDefault = true
  -- Kotlin DSL: isDefault = true / isDefault.set(true)
  return line:match("%f[%w]isDefault%s+true")
    or line:match("%f[%w]isDefault%s*=%s*true")
    or line:match("%f[%w]isDefault%.set%s*%(true%)")
end

local function read_file(path)
  local stat = vim.loop.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil
  end
  local fd = vim.loop.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local data = vim.loop.fs_read(fd, stat.size, 0)
  vim.loop.fs_close(fd)
  return data
end

local function resolve_apply_paths(root, lines)
  local paths = {}
  for _, line in ipairs(lines) do
    -- apply from: rootProject.file("gradle/scripts/foo.gradle")
    local rel = line:match('apply%s+from:%s*rootProject%.file%s*%(%s*["\']([^"\']+)["\']')
    if rel then
      paths[#paths + 1] = root .. "/" .. rel
    end
    -- apply(from = rootProject.file("..."))
    rel = line:match('apply%s*%(%s*from%s*=%s*rootProject%.file%s*%(%s*["\']([^"\']+)["\']')
    if rel then
      paths[#paths + 1] = root .. "/" .. rel
    end
  end
  return paths
end

local function parse_defaults_from_lines(lines)
  local default_build_type = nil
  local default_flavors = {}
  local in_build_types = false
  local in_product_flavors = false
  local current_name = nil
  local brace_depth = 0

  for _, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$") or ""

    -- track buildTypes { ... } and productFlavors { ... } blocks
    if not in_build_types and not in_product_flavors then
      if trimmed:match("^buildTypes%s*{") or trimmed:match("^buildTypes%s*$") then
        in_build_types = true
        brace_depth = 0
        current_name = nil
        if trimmed:match("{") then
          brace_depth = 1
        end
        goto continue
      end
      if
        trimmed:match("^productFlavors%s*{")
        or trimmed:match("^productFlavors%s*$")
      then
        in_product_flavors = true
        brace_depth = 0
        current_name = nil
        if trimmed:match("{") then
          brace_depth = 1
        end
        goto continue
      end
    end

    if in_build_types or in_product_flavors then
      -- count braces
      for _ in trimmed:gmatch("{") do
        brace_depth = brace_depth + 1
      end

      -- detect block entry: name { or name(...)  { at depth 2
      -- depth 1 = inside buildTypes/productFlavors, depth 2 = inside a specific type/flavor
      if brace_depth == 2 then
        local name = trimmed:match("^(%w+)%s*{")
          or trimmed:match("^(%w+)%s*$")
        if name and name ~= "if" and name ~= "create" and name ~= "register" then
          current_name = name
        end
      end

      if current_name and is_default_line(trimmed) then
        if in_build_types then
          default_build_type = current_name
        elseif in_product_flavors then
          default_flavors[#default_flavors + 1] = current_name
        end
      end

      for _ in trimmed:gmatch("}") do
        brace_depth = brace_depth - 1
      end

      if brace_depth == 1 then
        current_name = nil
      end

      if brace_depth <= 0 then
        in_build_types = false
        in_product_flavors = false
        current_name = nil
        brace_depth = 0
      end
    end

    ::continue::
  end

  return default_build_type, default_flavors
end

local function capitalize_first(s)
  if not s or s == "" then
    return s
  end
  return s:sub(1, 1):upper() .. s:sub(2)
end

local function compose_variant_name(flavors, build_type)
  if #flavors == 0 and not build_type then
    return nil
  end
  if #flavors == 0 then
    return build_type
  end

  local parts = { flavors[1] }
  for i = 2, #flavors do
    parts[#parts + 1] = capitalize_first(flavors[i])
  end
  if build_type then
    parts[#parts + 1] = capitalize_first(build_type)
  end
  return table.concat(parts, "")
end

local function normalize_module_path(module)
  if not module or module == "" then
    return ""
  end
  local normalized = module
  if normalized:sub(1, 1) == ":" then
    normalized = normalized:sub(2)
  end
  return normalized:gsub(":", "/")
end

local function build_file_paths(root, module)
  local base = root
  local mod_path = normalize_module_path(module)
  if mod_path ~= "" then
    base = root .. "/" .. mod_path
  end
  return {
    base .. "/build.gradle.kts",
    base .. "/build.gradle",
  }
end

function M.detect_default_variant(root, module)
  if not root or root == "" then
    return nil
  end

  local all_lines = {}
  local paths = build_file_paths(root, module)
  for _, path in ipairs(paths) do
    local content = read_file(path)
    if content then
      local lines = vim.split(content, "\n", { plain = true })
      -- collect applied script paths before merging
      local applied = resolve_apply_paths(root, lines)
      for _, line in ipairs(lines) do
        all_lines[#all_lines + 1] = line
      end
      -- read applied scripts
      for _, applied_path in ipairs(applied) do
        local applied_content = read_file(applied_path)
        if applied_content then
          for _, line in ipairs(vim.split(applied_content, "\n", { plain = true })) do
            all_lines[#all_lines + 1] = line
          end
        end
      end
      break -- only use the first build file found (kts preferred)
    end
  end

  if #all_lines == 0 then
    return nil
  end

  local default_build_type, default_flavors =
    parse_defaults_from_lines(all_lines)
  return compose_variant_name(default_flavors, default_build_type)
end

-- exposed for testing
M._parse_defaults_from_lines = parse_defaults_from_lines
M._compose_variant_name = compose_variant_name

return M
