# Auto generate tag files by ctags

This plugin autogenerates tags by filetype. Inspired by [jsfaint/gen_tags.vim](https://github.com/jsfaint/gen_tags.vim)

## Install

```lua
{
    "JMarkin/gentags.lua",
    cond = vim.fn.executable("ctags") == 1,
    event = "VeryLazy",
    opts = {}
}
```

Ctags -- [universal-ctags](https://github.com/universal-ctags/ctags)

Requires Neovim 0.12+.

Docs: `:help gentags` (run `:helptags doc` after install if your plugin manager does not).

## Configuration

default config: 

```lua
{
  autostart = true, -- register autocmds on setup
  -- nil: auto detect per buffer, "path": fixed root, false: cwd, function(bufnr): custom root
  root_dir = nil,
  generate = {
    on_open = true, -- generate on FileType when the tag file is missing
    on_write = true, -- regenerate on BufWritePost, debounced by 300ms
  },
  cache = {
    path = vim.fs.joinpath(vim.fn.stdpath("cache"), "tags"), -- path where generated tags store
  },
  async = true, -- run ctags asynchronous
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
    ["Rust"] = { "rust" },
  }
}
```

Notes:

- Root resolution order: `vim.g.gentags_root_dir` -> `root_dir` -> auto detect (`.git`, `pyproject.toml`,
  `package.json`, `go.mod`, `Cargo.toml`) -> `vim.uv.cwd()`.
- Generation is always a full `ctags -R <root>` run. Runs are serialized per tag file: rapid saves collapse
  into one follow-up run. `append_on_save` from older versions did nothing and has been removed.
- `:GenTagsDisable` removes the autocmds and drops queued runs. Tag files already added to the `'tags'`
  of an open buffer stay there.

## Development

```sh
nvim --clean --headless -l test/gentags_spec.lua   # spec, non-zero exit on failure
stylua --check lua/ test/
```
