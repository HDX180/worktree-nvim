local M = {}

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
