local M = {}

M.android_app_tokens = {
  "com.android.application",
  "alias(libs.plugins.android.application)",
  "libs.plugins.android.application",
  "libs.plugins.androidApplication",
  "androidApplication",
}

M.android_tokens = {
  "com.android.application",
  "com.android.library",
  "alias(libs.plugins.android.application)",
  "alias(libs.plugins.android.library)",
  "libs.plugins.android.application",
  "libs.plugins.android.library",
  "libs.plugins.androidApplication",
  "libs.plugins.androidLibrary",
  "androidApplication",
  "androidLibrary",
  "namespace",
}

M.kmp_tokens = {
  "kotlin(\"multiplatform\")",
  "kotlin-multiplatform",
  "org.jetbrains.kotlin.multiplatform",
  "alias(libs.plugins.kotlin.multiplatform)",
  "libs.plugins.kotlin.multiplatform",
  "libs.plugins.kotlinMultiplatform",
  "kotlinMultiplatform",
}

local function trim(value)
  return value:match("^%s*(.-)%s*$") or ""
end

local function is_comment(line)
  return line:match("^//") or line:match("^#")
end

function M.contains_tokens(lines, tokens)
  for _, line in ipairs(lines or {}) do
    local inspected = trim(line)
    if inspected ~= "" and not is_comment(inspected) then
      for _, token in ipairs(tokens or {}) do
        if inspected:find(token, 1, true) then
          return true
        end
      end
    end
  end
  return false
end

function M.has_android_app(lines)
  return M.contains_tokens(lines, M.android_app_tokens)
end

function M.has_android(lines)
  return M.contains_tokens(lines, M.android_tokens)
end

function M.has_kmp(lines)
  return M.contains_tokens(lines, M.kmp_tokens)
end

return M
