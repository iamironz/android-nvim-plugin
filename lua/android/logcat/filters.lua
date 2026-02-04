local M = {}

local strings = require("android.utils.strings")

local LEVEL_MAP = {
  V = "V",
  VERBOSE = "V",
  D = "D",
  DEBUG = "D",
  I = "I",
  INFO = "I",
  W = "W",
  WARN = "W",
  WARNING = "W",
  E = "E",
  ERROR = "E",
}

local function normalize_text(value)
  local trimmed = strings.trim(value)
  if trimmed == "" then
    return nil
  end
  return trimmed
end

local function is_regex_term(term)
  return type(term) == "string" and term:match("^/.+/$") ~= nil
end

local function matches_regex(line, term)
  local pattern = term:sub(2, -2)
  if pattern == "" then
    return true
  end
  local ok, found = pcall(string.find, line, pattern)
  if ok then
    return found ~= nil
  end
  return string.find(line, pattern, 1, true) ~= nil
end

function M.parse_terms(text)
  if text == nil then
    return {}
  end

  local terms = {}
  for term in string.gmatch(text, "%S+") do
    local lowered = string.lower(term)
    if lowered ~= "" then
      table.insert(terms, lowered)
    end
  end
  return terms
end

function M.matches_terms(line, terms)
  if terms == nil or #terms == 0 then
    return true
  end
  if type(line) ~= "string" then
    return false
  end

  local lower_line = string.lower(line)
  for _, term in ipairs(terms) do
    local lowered = string.lower(term)
    if lowered ~= "" then
      if is_regex_term(lowered) then
        if not matches_regex(lower_line, lowered) then
          return false
        end
      elseif not string.find(lower_line, lowered, 1, true) then
        return false
      end
    end
  end
  return true
end

function M.filter_lines(lines, text)
  local terms = M.parse_terms(text)
  local filtered = {}
  if lines == nil then
    return filtered
  end

  for _, line in ipairs(lines) do
    if M.matches_terms(line, terms) then
      table.insert(filtered, line)
    end
  end
  return filtered
end

function M.normalize_level(value, fallback)
  local trimmed = strings.trim(value)
  if trimmed == "" then
    return fallback
  end

  local key = trimmed:upper()
  return LEVEL_MAP[key] or fallback
end

function M.build(opts)
  local options = opts or {}
  local level = M.normalize_level(options.level, options.default_level)

  return {
    level = level,
    package = normalize_text(options.package),
    tag = normalize_text(options.tag),
  }
end

return M
