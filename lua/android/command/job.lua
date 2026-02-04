local M = {}

local function clean_lines(data)
  if not data or #data == 0 then return data end

  -- Check if last line is empty
  if data[#data] == "" then
    local lines = {}
    for i = 1, #data - 1 do
      lines[i] = data[i]
    end
    return lines
  end
  
  return data
end

function M.spawn(cmd, opts)
  opts = opts or {}

  local job_opts = {
    on_stdout = function(_, data, _)
      if opts.on_stdout then
        local lines = clean_lines(data)
        if lines and #lines > 0 then
          opts.on_stdout(lines)
        end
      end
    end,
    on_stderr = function(_, data, _)
      if opts.on_stderr then
        local lines = clean_lines(data)
        if lines and #lines > 0 then
          opts.on_stderr(lines)
        end
      end
    end,
    on_exit = function(_, code, _)
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
