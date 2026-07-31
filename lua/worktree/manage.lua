local utils = require("worktree.utils")

local M = {}

--- Build the display entries for all non-bare worktrees.
--- @return table[] entries
local function build_entries()
  local worktrees = utils.get_worktrees()
  local entries = {}
  local resolved_cwd = vim.fn.resolve(vim.fn.getcwd()):gsub("/$", "")

  for _, wt in ipairs(worktrees) do
    if not wt.bare then
      local branch_label = wt.branch or (wt.detached and "detached" or "unknown")
      local resolved_wt = vim.fn.resolve(wt.path):gsub("/$", "")
      local is_current = resolved_cwd == resolved_wt
      local marker = is_current and "*" or " "
      local display = string.format("%s [%s] %s", marker, branch_label, wt.path)
      table.insert(entries, {
        display = display,
        path = wt.path,
        branch = wt.branch,
        head = wt.head,
        detached = wt.detached,
        is_current = is_current,
        is_main = wt.is_main,
      })
    end
  end

  return entries
end

--- Open the unified worktree manager panel.
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
  local previewers = require("telescope.previewers")

  local entries = build_entries()
  if #entries == 0 then
    vim.notify("No worktrees found", vim.log.levels.WARN)
    return
  end

  -- Default cursor on the current worktree.
  local current_index = 1
  for i, e in ipairs(entries) do
    if e.is_current then
      current_index = i
      break
    end
  end

  local previewer = previewers.new_buffer_previewer({
    title = "Worktree Info",
    define_preview = function(self, entry)
      local wt = entry.value
      local status = wt.is_current and "current" or (wt.is_main and "main" or "normal")
      local branch = wt.branch or (wt.detached and "detached" or "unknown")
      local head = wt.head and wt.head:sub(1, 7) or "-"
      local lines = {
        "╭─ Worktree ──────────────────────╮",
        "│ Branch : " .. branch,
        "│ Path   : " .. wt.path,
        "│ HEAD   : " .. head,
        "│ Status : " .. status,
        "╰─────────────────────────────────╯",
        "",
        "  快捷键",
        "  <CR>   切换到该 worktree",
        "  <C-n>  新建 worktree",
        "  <C-d>  删除 worktree (--force + 删分支)",
        "  <Esc>  关闭面板",
      }
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })

  pickers.new({}, {
    prompt_title = "Worktree Manager",
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
    previewer = previewer,
    attach_mappings = function(prompt_bufnr, map)
      -- Switch (default <CR>)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if not selection then
          return
        end
        local wt = selection.value
        if wt.is_current then
          return
        end
        require("worktree.switch")._switch_to(wt.path, wt.branch)
      end)

      -- Create (<C-n>)
      local function create()
        actions.close(prompt_bufnr)
        require("worktree.create").run()
      end
      map("i", "<C-n>", create)
      map("n", "<C-n>", create)

      -- Delete (<C-d>)
      local function delete()
        local selection = action_state.get_selected_entry()
        if not selection then
          return
        end
        local wt = selection.value
        if wt.is_current then
          vim.notify("Cannot delete the current worktree", vim.log.levels.WARN)
          return
        end
        if wt.is_main then
          vim.notify("Cannot delete the main worktree", vim.log.levels.WARN)
          return
        end
        actions.close(prompt_bufnr)
        M._confirm_delete(wt)
      end
      map("i", "<C-d>", delete)
      map("n", "<C-d>", delete)

      return true
    end,
  }):find()
end

--- Confirm and perform deletion, then reopen the manager.
--- @param wt table selected worktree entry
function M._confirm_delete(wt)
  local branch = wt.branch or "(detached)"
  local prompt = string.format(
    "删除 worktree '%s' (分支 %s)?此操作会 --force 删目录并删除该分支。",
    wt.path,
    branch
  )

  vim.ui.select({ "No", "Yes" }, { prompt = prompt }, function(choice)
    if choice ~= "Yes" then
      M.run()
      return
    end

    local ok, err = require("worktree.delete").delete(wt.path, wt.branch)
    if ok then
      if err then
        vim.notify(err, vim.log.levels.WARN)
      else
        vim.notify("Deleted worktree: " .. (wt.branch or wt.path), vim.log.levels.INFO)
      end
    else
      vim.notify(err or "Failed to delete worktree", vim.log.levels.ERROR)
    end

    -- Reopen the manager to show the updated list.
    M.run()
  end)
end

return M
