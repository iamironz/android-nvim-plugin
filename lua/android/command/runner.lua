local M = {}

local function normalize_command(cmd)
  if type(cmd) == "string" or type(cmd) == "table" then
    return cmd
  end
  return nil
end

local function default_exec(cmd, opts)
  local options = opts or {}

  if vim.system then
    local result = vim.system(cmd, { cwd = options.cwd, env = options.env }):wait()
    return {
      code = result and result.code or 0,
      stdout = result and result.stdout or "",
      stderr = result and result.stderr or "",
    }
  end

  local output = ""
  local code = 0
  if options.cwd then
    local previous = vim.loop.cwd()
    if previous then
      vim.loop.chdir(options.cwd)
    end
    output = vim.fn.system(cmd)
    code = vim.v.shell_error or 0
    if previous then
      vim.loop.chdir(previous)
    end
  else
    output = vim.fn.system(cmd)
    code = vim.v.shell_error or 0
  end
  return { code = code, stdout = output or "", stderr = "" }
end

local function normalize_result(result)
  local code = result and tonumber(result.code) or 0
  local stdout = result and result.stdout or ""
  local stderr = result and result.stderr or ""
  return {
    ok = code == 0,
    code = code,
    stdout = stdout,
    stderr = stderr,
  }
end

function M.new(exec)
  local run_exec = exec or default_exec
  local runner = {}

  function runner.run(cmd, opts)
    local normalized = normalize_command(cmd)
    if not normalized then
      return {
        ok = false,
        code = 1,
        stdout = "",
        stderr = "invalid command",
        cmd = cmd,
      }
    end

    local result = normalize_result(run_exec(normalized, opts) or {})
    result.cmd = normalized
    return result
  end

  return runner
end

function M.run(cmd, exec, opts)
  return M.new(exec).run(cmd, opts)
end

return M
