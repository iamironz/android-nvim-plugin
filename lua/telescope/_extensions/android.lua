local gradle_tasks = require("android.actions.gradle_tasks")

return require("telescope").register_extension({
  exports = {
    tasks = gradle_tasks.open,
  },
})
