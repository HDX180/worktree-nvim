local M = {}

--- Execute a git command and return stdout, trimming trailing newline.
--- @param args string[] git subcommand arguments
--- @return string output
--- @return boolean ok
function M.git_cmd(args)
  local cmd = vim.list_extend({ "git" }, args)
  local output = vim.fn.system(cmd)
  local ok = vim.v.shell_error == 0
  if ok then
    output = output:gsub("%s+$", "")
  end
  return output, ok
end

--- Check if the current directory is inside a git repo.
--- @return boolean
function M.is_git_repo()
  local _, ok = M.git_cmd({ "rev-parse", "--is-inside-work-tree" })
  return ok
end

--- Get the project root directory (toplevel).
--- @return string|nil
function M.get_toplevel()
  local output, ok = M.git_cmd({ "rev-parse", "--show-toplevel" })
  if ok then
    return output
  end
  return nil
end

--- Get the project name from the toplevel path.
--- @return string|nil
function M.get_project_name()
  local toplevel = M.get_toplevel()
  if toplevel then
    return vim.fn.fnamemodify(toplevel, ":t")
  end
  return nil
end

--- Get all local and remote branches.
--- @return string[]
function M.get_branches()
  local output, ok = M.git_cmd({
    "branch", "-a", "--format=%(refname:short)", "--sort=-committerdate",
  })
  if not ok then
    return {}
  end
  local branches = {}
  for line in output:gmatch("[^\r\n]+") do
    -- deduplicate origin/HEAD -> origin/main style entries
    if not line:match("^origin/HEAD") then
      table.insert(branches, line)
    end
  end
  return branches
end

--- Get all worktrees via `git worktree list --porcelain`.
--- Runs from the git common dir to ensure all worktrees are found.
--- @return table[] list of { path = string, branch = string, bare = boolean }
function M.get_worktrees()
  -- Use the common git dir so we always see all worktrees,
  -- regardless of which worktree CWD is currently in.
  local common_dir, dir_ok = M.git_cmd({ "rev-parse", "--git-common-dir" })
  local cmd_args = { "worktree", "list", "--porcelain" }
  if dir_ok and common_dir ~= "" then
    -- Resolve to absolute path (git may return relative)
    common_dir = vim.fn.fnamemodify(common_dir, ":p")
    -- The common dir is the .git dir; its parent is the main worktree root
    local main_root = vim.fn.fnamemodify(common_dir, ":h:h")
    cmd_args = { "-C", main_root, "worktree", "list", "--porcelain" }
  end

  local output, ok = M.git_cmd(cmd_args)
  if not ok then
    return {}
  end

  local worktrees = {}
  local current = {}

  -- Split by newline, preserving empty lines for block boundaries
  local lines = vim.split(output, "\n", { plain = true })
  for _, line in ipairs(lines) do
    if line:match("^worktree ") then
      -- Start of a new entry; flush previous if any
      if current.path then
        table.insert(worktrees, current)
      end
      current = { path = line:sub(#"worktree " + 1) }
    elseif line:match("^branch ") then
      local ref = line:sub(#"branch " + 1)
      current.branch = ref:gsub("^refs/heads/", "")
    elseif line:match("^HEAD ") then
      current.head = line:sub(#"HEAD " + 1)
    elseif line:match("^bare$") then
      current.bare = true
    elseif line:match("^detached$") then
      current.detached = true
    end
  end
  -- Flush last entry
  if current.path then
    table.insert(worktrees, current)
  end
  return worktrees
end

--- Expand and normalize a path (resolve ~, etc.).
--- @param path string
--- @return string
function M.expand_path(path)
  return vim.fn.expand(path)
end

return M
