local M = {}

local runner_module = require("android.command.runner")

local function is_file(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

local function ensure_tool(path, name)
  if not path or path == "" then
    return nil, name .. " path required"
  end
  if not is_file(path) then
    return nil, name .. " not found at " .. path
  end
  return path
end

local function normalize_component(app_id, activity)
  if not app_id or app_id == "" or not activity or activity == "" then
    return nil
  end
  if activity:find("/", 1, true) then
    return activity
  end
  return app_id .. "/" .. activity
end

function M.build_install_command(adb_path, device, apk_path)
  local tool, err = ensure_tool(adb_path, "adb")
  if not tool then
    return { ok = false, error = err }
  end
  if not device or device == "" then
    return { ok = false, error = "device required" }
  end
  if not apk_path or apk_path == "" then
    return { ok = false, error = "apk path required" }
  end

  return {
    ok = true,
    cmd = {
      tool,
      "-s",
      device,
      "install",
      "-r",
      "-d",
      "-t",
      apk_path,
    },
  }
end

function M.build_launch_command(adb_path, device, app_id, activity)
  local tool, err = ensure_tool(adb_path, "adb")
  if not tool then
    return { ok = false, error = err }
  end
  if not device or device == "" then
    return { ok = false, error = "device required" }
  end

  -- When a specific activity is provided, launch it directly.
  local component = normalize_component(app_id, activity)
  if component then
    return {
      ok = true,
      cmd = {
        tool,
        "-s",
        device,
        "shell",
        "am",
        "start",
        "-n",
        component,
      },
    }
  end

  -- Launch via monkey which lets the system resolve the correct launcher
  -- activity. This avoids picking the wrong activity when libraries
  -- (LeakCanary, Flipper, etc.) register their own launchable entries
  -- in the merged manifest, and also handles activity-alias launchers
  -- that aapt2 does not report.
  if app_id and app_id ~= "" then
    return {
      ok = true,
      cmd = {
        tool,
        "-s",
        device,
        "shell",
        "monkey",
        "-p",
        app_id,
        "-c",
        "android.intent.category.LAUNCHER",
        "1",
      },
    }
  end

  return {
    ok = true,
    warning = "launch skipped: app id required",
  }
end

function M.resolve_app_id(apk_path, aapt2_path, runner)
  local tool, err = ensure_tool(aapt2_path, "aapt2")
  if not tool then
    return { ok = false, error = err }
  end
  if not apk_path or apk_path == "" then
    return { ok = false, error = "apk path required" }
  end

  local exec_runner = runner or runner_module.new()
  local result = exec_runner.run({ tool, "dump", "badging", apk_path })
  if not result.ok then
    return { ok = false, error = "aapt2 failed", result = result }
  end

  local stdout = result.stdout or ""
  local app_id = stdout:match("package: name='([^']+)'")
  if not app_id then
    return { ok = false, error = "app id not found" }
  end

  return { ok = true, app_id = app_id }
end

function M.deploy(opts)
  local options = opts or {}
  local exec_runner = options.runner or runner_module.new()

  local install = M.build_install_command(options.adb_path, options.device, options.apk_path)
  if not install.ok then
    return install
  end

  local install_result = exec_runner.run(install.cmd)
  if not install_result.ok then
    return { ok = false, error = "install failed", result = install_result }
  end

  local app_id = options.app_id
  if (not app_id or app_id == "") and options.aapt2_path then
    local resolved = M.resolve_app_id(options.apk_path, options.aapt2_path, exec_runner)
    if not resolved.ok then
      return {
        ok = true,
        warning = "launch skipped: " .. resolved.error,
        install = install_result,
      }
    end
    app_id = resolved.app_id
  end

  local launch = M.build_launch_command(options.adb_path, options.device, app_id)
  if not launch.ok then
    return launch
  end

  if not launch.cmd then
    return {
      ok = true,
      warning = launch.warning or "launch skipped",
      install = install_result,
      app_id = app_id,
    }
  end

  local launch_result = exec_runner.run(launch.cmd)
  if not launch_result.ok then
    return { ok = false, error = "launch failed", result = launch_result }
  end

  return {
    ok = true,
    install = install_result,
    launch = launch_result,
    app_id = app_id,
  }
end

return M
