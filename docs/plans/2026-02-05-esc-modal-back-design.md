# Esc Back Navigation for Android Modals Design

## Goal
Ensure all Android modal pickers opened from Android Actions support Esc to return to the
parent screen.

## Scope
- Action modals opened from Android Actions
- Nested pickers within those actions
- Gradle tasks picker, build module and variant pickers, devices and AVD pickers,
  run config picker, APK list picker
- Excludes non modal panels like the build output panel and logcat panel

## Behavior
- Esc from an action modal returns to the Actions picker
- Esc from a nested modal returns to its immediate parent modal
- If no parent callback is provided, Esc only closes the current picker

## Architecture
- The Actions picker builds a reopen callback that reopens itself with the same options
- `android.actions.registry.run` accepts optional opts and forwards them to action functions
- Action modules pass `opts.on_cancel` into `picker.select_from_list` or `picker.filter_input`
- Nested flows define local reopen callbacks and pass those to nested pickers

## Data Flow
- ui.actions calls `actions.registry.run(action_id, { on_cancel = reopen_actions })`
- Action module calls `picker.select_from_list({ on_cancel = opts.on_cancel })`
- Nested picker on_cancel calls the parent reopen callback

## Error Handling
- Keep existing warnings for missing tools and empty lists
- Treat on_cancel as optional and no op when absent

## Testing
- Actions picker passes on_cancel into actions registry
- Build prompt step back from variant picker to module picker
- Gradle tasks picker Esc triggers on_cancel
