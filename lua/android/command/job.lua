local M = {}

local function normalize_chunk(data, pending)
  local remainder = pending or ""
  if not data or #data == 0 then
    return nil, remainder
  end

  local has_trailing_newline = data[#data] == ""
  local chunks = {}
  local last_index = #data
  if has_trailing_newline then
    last_index = last_index - 1
  end

  for i = 1, last_index do
    chunks[#chunks + 1] = data[i]
  end

  local lines = {}
  if #chunks > 0 then
    chunks[1] = remainder .. chunks[1]
    remainder = ""
    if has_trailing_newline then
      lines = chunks
    else
      for i = 1, #chunks - 1 do
        lines[#lines + 1] = chunks[i]
      end
      remainder = chunks[#chunks]
    end
  elseif has_trailing_newline and remainder ~= "" then
    lines[1] = remainder
    remainder = ""
  end

  if #lines == 0 then
    return nil, remainder
  end
  return lines, remainder
end

function M.spawn(cmd, opts)
  opts = opts or {}
  local stdout_pending = ""
  local stderr_pending = ""

  local job_opts = {
    on_stdout = function(_, data, _)
      if opts.on_stdout then
        local lines
        lines, stdout_pending = normalize_chunk(data, stdout_pending)
        if lines and #lines > 0 then
          opts.on_stdout(lines)
        end
      end
    end,
    on_stderr = function(_, data, _)
      if opts.on_stderr then
        local lines
        lines, stderr_pending = normalize_chunk(data, stderr_pending)
        if lines and #lines > 0 then
          opts.on_stderr(lines)
        end
      end
    end,
    on_exit = function(_, code, _)
      if opts.on_stdout and stdout_pending ~= "" then
        opts.on_stdout({ stdout_pending })
        stdout_pending = ""
      end
      if opts.on_stderr and stderr_pending ~= "" then
        opts.on_stderr({ stderr_pending })
        stderr_pending = ""
      end
      if opts.on_exit then
        opts.on_exit(code)
      end
    end,
  }

  if opts.cwd then
    job_opts.cwd = opts.cwd
  end
  if opts.env then
    job_opts.env = opts.env
  end

  local job_id = vim.fn.jobstart(cmd, job_opts)
  local is_valid = job_id and job_id > 0

  if not is_valid then
    return {
      id = job_id,
      ok = false,
      error = "jobstart_failed",
      stop = function()
        return false
      end,
    }
  end

  return {
    id = job_id,
    ok = true,
    error = nil,
    stop = function()
      vim.fn.jobstop(job_id)
    end
  }
end

return M
