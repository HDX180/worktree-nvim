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
  local previewers = require("telescope.previewers")

  local branches = utils.get_branches()
  if #branches == 0 then
    vim.notify("No branches found", vim.log.levels.WARN)
    return
  end

  local wt_config = require("worktree").config
  local project_name = utils.get_project_name() or "project"

  -- State: step 1 = select branch, step 2 = name worktree, step 3 = result
  local state = { step = 1, base_branch = nil }

  local status_previewer = previewers.new_buffer_previewer({
    title = "Worktree Info",
    define_preview = function(self, entry)
      local lines = {}
      table.insert(lines, "╭─── Create Worktree ───╮")
      table.insert(lines, "│")
      if state.step == 1 then
        table.insert(lines, "│  Step 1/2: Select base branch")
        table.insert(lines, "│  Step 2/2: Name your worktree")
      else
        table.insert(lines, "│  Step 1/2: ✓ Base branch: " .. state.base_branch)
        table.insert(lines, "│  Step 2/2: Name your worktree")
      end
      table.insert(lines, "│")
      table.insert(lines, "╰─────────────────────────╯")
      table.insert(lines, "")
      table.insert(lines, "  Project: " .. project_name)
      table.insert(lines, "  Path:    " .. wt_config.base_path .. "/" .. project_name .. "_<name>")
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })

  local picker = pickers.new({}, {
    prompt_title = "Step 1/2: Select Base Branch",
    finder = finders.new_table({ results = branches }),
    sorter = conf.generic_sorter({}),
    previewer = status_previewer,
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        if state.step == 1 then
          local selection = action_state.get_selected_entry()
          if not selection then
            return
          end
          state.base_branch = selection[1]
          state.step = 2

          local current_picker = action_state.get_current_picker(prompt_bufnr)
          current_picker:refresh(
            finders.new_table({
              results = {
                "✓ Base branch: " .. state.base_branch,
                "",
                "Type your worktree name above, then press <Enter>",
              },
            }),
            { reset_prompt = true }
          )
          current_picker.prompt_border:change_title("Step 2/2: Enter Worktree Name")

        elseif state.step == 2 then
          local current_picker = action_state.get_current_picker(prompt_bufnr)
          local name = current_picker:_get_prompt():gsub("^%s+", ""):gsub("%s+$", "")

          if name == "" then
            -- Refresh with a hint instead of vim.notify
            current_picker:refresh(
              finders.new_table({ results = { "⚠ Worktree name cannot be empty" } }),
              { reset_prompt = true }
            )
            return
          end

          -- Execute creation and show result in the same window
          local result_lines = M._create_worktree(state.base_branch, name, project_name)
          state.step = 3

          current_picker:refresh(
            finders.new_table({ results = result_lines }),
            { reset_prompt = true }
          )
          current_picker.prompt_border:change_title("Done — press <Esc> to close")
        end
        -- step 3: any Enter also just closes
        if state.step == 3 then
          actions.close(prompt_bufnr)
        end
      end)
      return true
    end,
  })

  picker:find()
end

--- Execute git worktree add. Returns result lines for display.
--- @param base_branch string
--- @param name string
--- @param project_name string
--- @return string[]
function M._create_worktree(base_branch, name, project_name)
  local wt_config = require("worktree").config
  local worktree_dir = wt_config.base_path .. "/" .. project_name .. "_" .. name
  local expanded_dir = utils.expand_path(worktree_dir)

  if vim.fn.isdirectory(expanded_dir) == 1 then
    return {
      "✗ Failed: directory already exists",
      "",
      "  " .. expanded_dir,
    }
  end

  local output, cmd_ok = utils.git_cmd({
    "worktree", "add", "-b", name, expanded_dir, base_branch,
  })

  if cmd_ok then
    return {
      "✓ Worktree created successfully",
      "",
      "  Branch: " .. name,
      "  Base:   " .. base_branch,
      "  Path:   " .. expanded_dir,
    }
  else
    return {
      "✗ Failed to create worktree",
      "",
      "  " .. output,
    }
  end
end

return M
