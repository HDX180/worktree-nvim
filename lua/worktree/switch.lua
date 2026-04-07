local utils = require("worktree.utils")

local M = {}

function M.run()
  if not utils.is_git_repo() then
    vim.notify("Not inside a git repository", vim.log.levels.ERROR)
    return
  end

  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("telescope.nvim is required for worktree.nvim", vim.log.levels.ERROR)
    return
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local worktrees = utils.get_worktrees()
  if #worktrees == 0 then
    vim.notify("No worktrees found", vim.log.levels.WARN)
    return
  end

  -- Filter out bare worktrees and format entries
  local entries = {}
  local current_dir = vim.fn.getcwd()
  for _, wt in ipairs(worktrees) do
    if not wt.bare then
      local branch_label = wt.branch or (wt.detached and "detached" or "unknown")
      -- Exact path match only (resolve to handle symlinks/trailing slashes)
      local resolved_cwd = vim.fn.resolve(current_dir):gsub("/$", "")
      local resolved_wt = vim.fn.resolve(wt.path):gsub("/$", "")
      local is_current = resolved_cwd == resolved_wt
      local marker = is_current and " * " or "   "
      local display = string.format("%s[%s] %s", marker, branch_label, wt.path)
      table.insert(entries, {
        display = display,
        path = wt.path,
        branch = wt.branch,
        is_current = is_current,
      })
    end
  end

  -- Find current worktree index and branch for title
  local current_branch = nil
  local current_index = 1
  for i, e in ipairs(entries) do
    if e.is_current then
      current_branch = e.branch
      current_index = i
      break
    end
  end
  local title = "Switch Worktree"
  if current_branch then
    title = title .. "  (current: " .. current_branch .. ")"
  end

  pickers.new({}, {
    prompt_title = title,
    default_selection_index = current_index,
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.display,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        -- Don't switch if already in target
        if selection.value.is_current then
          return
        end
        M._switch_to(selection.value.path, selection.value.branch)
      end)
      return true
    end,
  }):find()
end

--- Perform the actual worktree switch.
--- @param target_path string
--- @param branch string|nil
function M._switch_to(target_path, branch)
  -- 0. Remember current file's relative path before switching
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir = vim.fn.getcwd()
  local relative_file = nil
  if current_file ~= "" then
    -- Strip the current worktree root to get a relative path
    local resolved_file = vim.fn.resolve(current_file)
    local resolved_dir = vim.fn.resolve(current_dir)
    if vim.startswith(resolved_file, resolved_dir .. "/") then
      relative_file = resolved_file:sub(#resolved_dir + 2)
    end
  end

  -- 1. Save all modified files
  vim.cmd("silent! wall")

  -- 2. Close all buffers
  vim.cmd("%bdelete!")

  -- 3. Change CWD
  vim.cmd.cd(target_path)

  -- 4. Clear jumplist
  vim.cmd("clearjumps")

  -- 5. Clear quickfix list
  vim.fn.setqflist({}, "r")

  -- 6. Clear loclist for all windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    vim.fn.setloclist(win, {}, "r")
  end

  -- 7. Sync toggleterm terminals
  M._sync_toggleterm(target_path)

  -- 8. Try to open the same file in the new worktree
  if relative_file then
    local new_file = target_path .. "/" .. relative_file
    if vim.fn.filereadable(new_file) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(new_file))
    end
  end

  -- 9. Fire user event for other plugins to hook into
  vim.api.nvim_exec_autocmds("User", { pattern = "WorktreeSwitched" })

  -- 10. Notify
  local label = branch or target_path
  vim.notify("Switched to worktree: " .. label, vim.log.levels.INFO)
end

--- Sync all toggleterm terminals to the new worktree directory.
--- @param target_path string
function M._sync_toggleterm(target_path)
  local term_ok, terminals = pcall(require, "toggleterm.terminal")
  if not term_ok then
    return
  end

  local all = terminals.get_all(true)
  if not all or #all == 0 then
    return
  end

  for _, term in ipairs(all) do
    if term:is_open() then
      -- Send cd command to the running shell
      term:send("cd " .. vim.fn.shellescape(target_path))
    end
    -- Update the terminal's dir field so future toggles use the new path
    term.dir = target_path
  end
end

return M
