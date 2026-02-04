local M = {}

local function build_message(message, suffix)
  if message == nil or message == "" then
    return suffix
  end
  return message .. ": " .. suffix
end

function M.eq(actual, expected, message)
  if actual ~= expected then
    error(build_message(message, "expected " .. tostring(expected) .. ", got " .. tostring(actual)))
  end
end

function M.is_true(value, message)
  if not value then
    error(build_message(message, "expected true, got " .. tostring(value)))
  end
end

function M.table_eq(actual, expected, message)
  if #actual ~= #expected then
    error(build_message(message, "expected size " .. #expected .. ", got " .. #actual))
  end

  for index, value in ipairs(expected) do
    if actual[index] ~= value then
      error(build_message(message, "mismatch at " .. index))
    end
  end
end

function M.contains(haystack, needle, message)
  if type(haystack) ~= "string" or not string.find(haystack, needle, 1, true) then
    error(build_message(message, "expected " .. tostring(needle) .. " in " .. tostring(haystack)))
  end
end

return M
