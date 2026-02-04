local M = {}
local assert = require("tests.helpers.assert")
local logcat_helpers = require("tests.helpers.logcat_controls")

local function state_with(package, filter)
  return logcat_helpers.build_state({
    logcat = { package = package, filter = filter },
  })
end

local function with_stack_trace_context(callback)
  local state = state_with("com.saved", "Old")
  local parser_calls = { count = 0 }
  local stubs = {
    ["android.logcat.parser"] = {
      parse_stack_line = function()
        parser_calls.count = parser_calls.count + 1
        return nil
      end,
    },
  }

  logcat_helpers.with_logcat_and_enter({ state = state, stubs = stubs }, 4, function(ctx)
    callback(ctx, parser_calls)
  end)
end

local function enter_on_body_line_calls_stack_trace_parser()
  with_stack_trace_context(function(_, parser_calls)
    assert.eq(parser_calls.count, 1, "stack trace parser invoked")
  end)
end

local function enter_on_body_line_does_not_prompt_input()
  with_stack_trace_context(function(ctx, _)
    assert.eq(#ctx.vim_state.input_calls, 0, "no input prompt")
  end)
end

local function stack_trace_module_exports_open()
  local stack_trace = require("android.logcat.stack_trace")
  assert.eq(type(stack_trace.open_stack_trace), "function", "stack trace open")
end

function M.run()
  enter_on_body_line_calls_stack_trace_parser()
  enter_on_body_line_does_not_prompt_input()
  stack_trace_module_exports_open()
end

return M
