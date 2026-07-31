local utils = require("worktree.utils")

local M = {}

--- Force-remove a worktree and delete its branch.
--- @param path string worktree directory to remove
--- @param branch string|nil branch to delete (skipped when nil/empty, e.g. detached)
--- @return boolean ok  true if the worktree was removed
--- @return string|nil message  warning/error text (set even when ok=true on branch failure)
function M.delete(path, branch)
  local output, ok = utils.git_cmd({ "worktree", "remove", "--force", path })
  if not ok then
    return false, "Failed to remove worktree:\n" .. output
  end

  if branch and branch ~= "" then
    local bout, bok = utils.git_cmd({ "branch", "-D", branch })
    if not bok then
      return true, "Worktree removed, but failed to delete branch '" .. branch .. "':\n" .. bout
    end
  end

  return true, nil
end

return M
