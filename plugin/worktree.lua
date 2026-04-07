if vim.g.loaded_worktree then
  return
end
vim.g.loaded_worktree = true

vim.api.nvim_create_user_command("WorktreeCreate", function()
  require("worktree").create()
end, { desc = "Create a new git worktree" })

vim.api.nvim_create_user_command("WorktreeSwitch", function()
  require("worktree").switch()
end, { desc = "Switch to another git worktree" })
