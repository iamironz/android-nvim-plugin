local M = {}

function M.with_stubs(stubs, fn)
  local saved = {}
  for name, mod in pairs(stubs or {}) do
    saved[name] = package.loaded[name]
    package.loaded[name] = mod
  end

  local ok, err = pcall(fn)

  for name, _ in pairs(stubs or {}) do
    package.loaded[name] = saved[name]
  end

  if not ok then
    error(err)
  end
end

function M.merge_stubs(...)
  local merged = {}
  for _, group in ipairs({ ... }) do
    for key, value in pairs(group or {}) do
      merged[key] = value
    end
  end
  return merged
end

return M
