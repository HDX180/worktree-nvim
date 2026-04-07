local M = {}

M.config = {
  base_path = "~/.worktrees",
}

--- Setup the worktree plugin with user options.
--- @param opts? table
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  -- Ensure base_path is expanded
  M.config.base_path = vim.fn.expand(M.config.base_path)
  -- Create base_path if it doesn't exist
  vim.fn.mkdir(M.config.base_path, "p")
end

--- Create a new worktree (opens Telescope branch picker).
function M.create()
  require("worktree.create").run()
end

--- Switch to another worktree (opens Telescope worktree picker).
function M.switch()
  require("worktree.switch").run()
end

return M
