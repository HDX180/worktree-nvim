# worktree-nvim

A Neovim plugin for quickly creating and switching git worktrees, powered by Telescope.

## Features

### Create Worktree

A guided two-step flow in a single Telescope window:

1. **Step 1** — Select a base branch (with fuzzy search)
2. **Step 2** — Type the worktree name, press Enter

The worktree is created at `{base_path}/{project_name}_{worktree_name}`. By default it will **automatically switch** to the new worktree after creation (configurable via `switch_after_create`).

### Switch Worktree

Pick a worktree from the Telescope list and switch instantly. On switch:

- All modified files are **auto-saved**
- All buffers are closed
- CWD is changed to the target worktree
- **Jumplist** is cleared (`Ctrl-o` / `Ctrl-i` won't jump back to stale positions)
- **Quickfix** and **loclist** are cleared
- All **toggleterm.nvim** terminals are synced to the new worktree directory
- If the same file exists in the new worktree, it is **automatically opened**
- A `User WorktreeSwitched` event is fired for other plugins to hook into

The current worktree is marked with `*` in the list, and the cursor defaults to it.

## Requirements

- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (required)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (required, telescope dependency)
- [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) (optional, for terminal CWD sync)

## Install

### lazy.nvim

```lua
{
  "your-username/worktree-nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
}
```

## Setup

```lua
require("worktree").setup({
  base_path = "~/.worktrees",       -- where worktrees are stored (default: "~/.worktrees")
  switch_after_create = true,        -- auto-switch to new worktree after creation (default: true)
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:WorktreeCreate` | Create a new worktree |
| `:WorktreeSwitch` | Switch to another worktree |

## Keymap example

```lua
vim.keymap.set("n", "<leader>wa", "<cmd>WorktreeCreate<cr>")
vim.keymap.set("n", "<leader>ww", "<cmd>WorktreeSwitch<cr>")
```

## API

```lua
local worktree = require("worktree")

worktree.create()  -- open the create worktree flow
worktree.switch()  -- open the switch worktree picker
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `base_path` | `string` | `"~/.worktrees"` | Directory where worktrees are stored |
| `switch_after_create` | `boolean` | `true` | Automatically switch to the new worktree after creation |

## Worktree path convention

Worktrees are stored under `base_path` with the naming pattern:

```
{base_path}/{project_name}_{worktree_name}
```

For example, if your project is `my-app` and you name the worktree `feature-login`:

```
~/.worktrees/my-app_feature-login
```

## License

MIT
