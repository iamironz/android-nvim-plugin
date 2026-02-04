local M = {}

function M.detect(workspace)
  if not workspace or not workspace.gradle then
    return {}
  end
  return {
    {
      id = "gradle_tasks",
      label = "Gradle tasks",
      target = "gradle",
      type = "gradle_task",
    },
  }
end

return M
