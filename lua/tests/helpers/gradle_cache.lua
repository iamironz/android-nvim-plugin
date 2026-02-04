local M = {}

local gradle_cache = require("android.gradle.cache")

function M.build_stat(mtimes)
  return function(path)
    local value = mtimes[path]
    if value == nil then
      return nil
    end
    return { mtime = { sec = value, nsec = 0 } }
  end
end

function M.build_modules(count)
  local modules = {}
  for i = 1, count do
    modules[#modules + 1] = string.format(":module%03d", i)
  end
  return modules
end

function M.in_memory_cache()
  local bucket = {}
  return {
    fetch = function(_, key, stamp, loader)
      local entry = bucket[key]
      if entry and entry.stamp == stamp then
        return entry.value
      end
      local value = loader()
      bucket[key] = { stamp = stamp, value = value }
      return value
    end,
  }
end

function M.capture_cache()
  local captured = {}
  local cache = {}
  function cache.fetch(_, key, stamp, loader)
    captured[key] = stamp
    return loader()
  end
  return cache, captured
end

function M.new_cache(mtimes, cache)
  return gradle_cache.new({ stat = M.build_stat(mtimes), cache = cache })
end

function M.new_memory_cache(mtimes)
  return M.new_cache(mtimes, M.in_memory_cache())
end

function M.track_loader(result)
  local calls = 0
  local loader = function()
    calls = calls + 1
    return result
  end
  local get_calls = function()
    return calls
  end
  return loader, get_calls
end

return M
