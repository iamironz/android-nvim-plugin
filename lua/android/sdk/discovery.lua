local M = {}

local strings = require("android.utils.strings")

local function default_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil
end

local function select_first(candidates, exists)
  for _, path in ipairs(candidates or {}) do
    if exists(path) then
      return path
    end
  end
  return nil
end

local function default_read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if ok then
    return lines
  end
  return nil
end

local function is_windows(os_name)
  return os_name == "Windows_NT"
end

local function is_absolute_path(path)
  if not path or path == "" then
    return false
  end
  if string.sub(path, 1, 1) == "/" then
    return true
  end
  if string.match(path, "^%a:[\\/]") then
    return true
  end
  return false
end

local function expand_home(path, home)
  if not path or path == "" then
    return path
  end
  if string.sub(path, 1, 2) == "~/" then
    return (home or "") .. string.sub(path, 2)
  end
  return path
end

local function parse_local_properties(lines)
  for _, line in ipairs(lines or {}) do
    local trimmed = strings.trim(line)
    if trimmed ~= "" and not string.match(trimmed, "^#") then
      local key, value = string.match(trimmed, "^([^=]+)%s*=%s*(.+)$")
      if key and value then
        local cleaned_key = strings.trim(key)
        if cleaned_key == "sdk.dir" then
          local cleaned_value = strings.trim(value)
          cleaned_value = cleaned_value:gsub("\\:", ":")
          cleaned_value = cleaned_value:gsub("\\\\", "\\")
          return cleaned_value
        end
      end
    end
  end
  return nil
end

local function resolve_local_properties(root, paths, read_file)
  if not root or root == "" then
    return nil
  end
  local files = paths or { "local.properties" }
  for _, entry in ipairs(files) do
    local path = entry
    if not is_absolute_path(entry) then
      path = root .. "/" .. entry
    end
    local lines = read_file(path)
    if lines then
      local sdk_dir = parse_local_properties(lines)
      if sdk_dir and sdk_dir ~= "" then
        return sdk_dir
      end
    end
  end
  return nil
end

local function default_home(env)
  local data = env or vim.env
  return data.HOME or data.USERPROFILE
end

local function default_sdk_candidates(os_name, home)
  if not home or home == "" then
    return {}
  end
  if os_name == "Darwin" then
    return { home .. "/Library/Android/sdk" }
  end
  if os_name == "Windows_NT" then
    return { home .. "/AppData/Local/Android/Sdk" }
  end
  return { home .. "/Android/Sdk" }
end

local function create_root_getter(store, env, exists, options)
  return function()
    local cached = store.get("sdk_root")
    if cached ~= nil then
      return cached
    end

    local root, source = M.detect_root(env, exists, options)
    store.set("sdk_root", root)
    store.set("sdk_root_source", source)
    return root
  end
end

local function create_tools_getter(store, root_fn, exists, os_name)
  return function()
    local cached = store.get("sdk_tools")
    if cached ~= nil then
      return cached
    end

    local root = root_fn()
    local tools = M.locate_tools(root, exists, os_name)
    store.set("sdk_tools", tools)
    return tools
  end
end

local function create_packages_getter(store, tools_fn, runner)
  return function()
    local cached = store.get("sdk_packages")
    if cached ~= nil then
      return cached
    end

    local tools = tools_fn()
    if not tools.sdkmanager then
      store.set("sdk_packages", {})
      return {}
    end

    local result = runner.run({ tools.sdkmanager, "--list" })
    local output = result and result.stdout or ""
    local lines = vim.split(output, "\n", { plain = true })
    local packages = require("android.sdk.packages").parse_installed(lines)
    store.set("sdk_packages", packages)
    return packages
  end
end

local function create_aapt2_getter(store, root_fn, build_tools_fn, exists, os_name)
  return function()
    local cached = store.get("sdk_aapt2")
    if cached ~= nil then
      return cached
    end

    local root = root_fn()
    local build_tools = build_tools_fn()
    local aapt2 = M.locate_aapt2(root, build_tools, exists, os_name)
    store.set("sdk_aapt2", aapt2)
    return aapt2
  end
end

function M.locate_aapt2(root, build_tools, exists, os_name)
  if not root or root == "" then
    return nil
  end
  if not build_tools or #build_tools == 0 then
    return nil
  end
  local check = exists or default_exists
  local filename = is_windows(os_name) and "aapt2.exe" or "aapt2"
  for index = #build_tools, 1, -1 do
    local version = build_tools[index]
    local path = root .. "/build-tools/" .. version .. "/" .. filename
    if check(path) then
      return path
    end
  end
  return nil
end

function M.detect_root(env, exists, opts)
  local check = exists or default_exists
  local data = env or vim.env
  local options = opts or {}
  local config = options.config or require("android.config").get()
  local sdk_config = config and config.sdk or {}
  local read_file = options.read_file or default_read_file
  local project_root = options.root or options.cwd
  local os_name = options.os_name or vim.loop.os_uname().sysname
  local home = options.home or default_home(data)

  local configured_root = sdk_config.root
  if configured_root and check(configured_root) then
    return configured_root, "config"
  end

  local use_local_properties = sdk_config.local_properties ~= false
  if use_local_properties then
    local paths = sdk_config.local_properties_paths
    local sdk_dir = resolve_local_properties(project_root, paths, read_file)
    if sdk_dir then
      local expanded = expand_home(sdk_dir, home)
      if check(expanded) then
        return expanded, "local.properties"
      end
    end
  end

  local env_keys = sdk_config.root_env_keys or { "ANDROID_SDK_ROOT", "ANDROID_HOME" }
  for _, key in ipairs(env_keys) do
    local root = data[key]
    if root and check(root) then
      return root, key
    end
  end

  local candidates = sdk_config.root_candidates
  if not candidates or #candidates == 0 then
    candidates = default_sdk_candidates(os_name, home)
  end
  local expanded_candidates = {}
  for _, candidate in ipairs(candidates or {}) do
    table.insert(expanded_candidates, expand_home(candidate, home))
  end
  local default_root = select_first(expanded_candidates, check)
  if default_root then
    return default_root, "default"
  end

  return nil, nil
end

function M.locate_tools(root, exists, os_name)
  if not root then
    return {}
  end

  local check = exists or default_exists
  local windows = is_windows(os_name)
  local sdkmanager_name = windows and "sdkmanager.bat" or "sdkmanager"
  local avdmanager_name = windows and "avdmanager.bat" or "avdmanager"
  local emulator_name = windows and "emulator.exe" or "emulator"
  local adb_name = windows and "adb.exe" or "adb"
  local sdkmanager = select_first({
    root .. "/cmdline-tools/latest/bin/" .. sdkmanager_name,
    root .. "/cmdline-tools/bin/" .. sdkmanager_name,
    root .. "/tools/bin/" .. sdkmanager_name,
  }, check)

  local avdmanager = select_first({
    root .. "/cmdline-tools/latest/bin/" .. avdmanager_name,
    root .. "/cmdline-tools/bin/" .. avdmanager_name,
    root .. "/tools/bin/" .. avdmanager_name,
  }, check)

  local emulator = select_first({ root .. "/emulator/" .. emulator_name }, check)
  local adb = select_first({ root .. "/platform-tools/" .. adb_name }, check)

  return {
    sdkmanager = sdkmanager,
    avdmanager = avdmanager,
    emulator = emulator,
    adb = adb,
  }
end

function M.new(opts)
  local store = opts and opts.store or require("android.state.store").new()
  local runner = opts and opts.runner or require("android.command.runner").new()
  local env = opts and opts.env or vim.env
  local exists = opts and opts.exists or default_exists
  local read_file = opts and opts.read_file or default_read_file
  local config = opts and opts.config or nil
  local root = opts and opts.root or nil
  local cwd = opts and opts.cwd or nil
  local os_name = opts and opts.os_name or nil
  local home = opts and opts.home or nil
  local discovery = {}

  local root_fn = create_root_getter(store, env, exists, {
    config = config,
    read_file = read_file,
    root = root,
    cwd = cwd,
    os_name = os_name,
    home = home,
  })
  local tools_fn = create_tools_getter(store, root_fn, exists, os_name)
  local packages_fn = create_packages_getter(store, tools_fn, runner)
  local build_tools_fn = function()
    return require("android.sdk.packages").list_build_tools(packages_fn())
  end

  discovery.root = root_fn
  discovery.tools = tools_fn
  discovery.packages = packages_fn
  discovery.build_tools = build_tools_fn
  discovery.platform_tools = function()
    return require("android.sdk.packages").list_platform_tools(packages_fn())
  end
  discovery.aapt2 = create_aapt2_getter(store, root_fn, build_tools_fn, exists, os_name)
  discovery.detect = function()
    return {
      root = root_fn(),
      tools = tools_fn(),
      aapt2 = discovery.aapt2(),
    }
  end

  return discovery
end

return M
