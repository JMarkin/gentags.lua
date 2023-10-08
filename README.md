# Auto generate tag files by ctags

This plugin autogenerate tags by filetype. Inspired by [jsfaint/gen_tags.vim](https://github.com/jsfaint/gen_tags.vim)


## Install
```lua
{
    "JMarkin/gentags.lua",
    cond = vim.fn.executable("ctags") == 1,
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("gentags").setup({})
    end,
    event = "VeryLazy",
}
```

## Configurations
```lua
{
  root_dir = vim.g.gentags_root_dir or vim.loop.cwd(),
  cache = {
    path = Path:new(vim.fn.stdpath("cache")):joinpath("tags"), -- path where store generated tags, currently required plenary Path object
  },
  bin = "ctags",
  args = { -- extra args
    "--extras=+r+q",
    "--exclude=.git",
    "--exclude=node_modules*",
    "--exclude=.mypy*",
    "--exclude=.pytest*",
    "--exclude=.ruff*",
    "--exclude=BUILD",
    "--exclude=vendor*",
    "--exclude=*.min.*",
  },
  -- mapping ctags --languages <-> neovim filetypes
  lang_ft_map = {
    ["Python"] = { "python" },
    ["Lua"] = { "lua" },
    ["Vim"] = { "vim" },
    ["C,C++,CUDA"] = { "c", "cpp", "h", "cuda" },
    ["JavaScript"] = { "javascript" },
    ["Go"] = { "go" },
  }
}
```
