local ctags = require("gentags.ctags")

local M = {}

-- Nested list: markers in one list have equal priority, so the nearest ancestor wins.
-- A flat list would instead prioritize the first marker that matches anywhere above.
local ROOT_MARKERS = { { ".git", "pyproject.toml", "package.json", "go.mod", "Cargo.toml" } }

local defaults = {
  autostart = true,
  -- nil: auto detect per buffer, "path": fixed root, false: cwd, function(bufnr): custom
  root_dir = nil,
  generate = {
    on_open = true, -- generate on FileType when the tag file is missing
    on_write = true, -- regenerate on BufWritePost (debounced)
  },
  cache = {
    path = vim.fs.joinpath(vim.fn.stdpath("cache"), "tags"), -- path where generated tags store
  },
  async = true,
  bin = "ctags",
  args = {
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
  },
}

local config = vim.deepcopy(defaults)
local augroup = nil

local function lang_for(ft)
  for lang, fts in pairs(config.lang_ft_map) do
    if vim.list_contains(fts, ft) then
      return lang
    end
  end
end

M.get_config = function()
  return config
end

--- Resolve the project root for a buffer.
--- Priority: `vim.g.gentags_root_dir`, the `root_dir` option, the nearest root marker, `cwd`.
--- @param bufnr? integer
--- @return string
M.root_dir = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.g.gentags_root_dir then
    return vim.g.gentags_root_dir
  end

  local root = config.root_dir
  if type(root) == "function" then
    return root(bufnr) or vim.uv.cwd()
  end
  if type(root) == "string" then
    return root
  end
  if root == false then
    return vim.uv.cwd()
  end

  return vim.fs.root(bufnr, ROOT_MARKERS) or vim.uv.cwd()
end

-- Language plus a base64 of the project root, so the cache survives project moves.
-- ponytail: base64 grows 4/3 with path length, switch to a hash if a 255 byte name is ever hit.
local function tag_file_for(lang, root)
  return vim.fs.joinpath(config.cache.path, lang:gsub(",", "_") .. vim.base64.encode(vim.fs.abspath(root)))
end

M.generate = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local lang = lang_for(ft)
  if not lang then
    vim.notify("gentags: no ctags language for filetype '" .. ft .. "'", vim.log.levels.WARN)
    return
  end

  local root = M.root_dir(bufnr)
  local tag_file = tag_file_for(lang, root)
  -- Buffer-local, and appending dedups an already present path.
  vim.opt_local.tags:append(tag_file)
  ctags.generate(config, lang, tag_file, root)
  return tag_file
end

M.enable = function()
  if augroup then
    return
  end

  local patterns = {}
  for _, fts in pairs(config.lang_ft_map) do
    vim.list_extend(patterns, fts)
  end
  if #patterns == 0 then
    return
  end

  augroup = vim.api.nvim_create_augroup("GenTags", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = patterns,
    callback = function(args)
      local lang = lang_for(vim.bo[args.buf].filetype)
      if not lang then
        return
      end

      local root = M.root_dir(args.buf)
      local tag_file = tag_file_for(lang, root)
      vim.opt_local.tags:append(tag_file)

      if config.generate.on_open and not vim.uv.fs_stat(tag_file) then
        ctags.generate(config, lang, tag_file, root)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    pattern = "*",
    callback = function(args)
      if not config.generate.on_write then
        return
      end

      local lang = lang_for(vim.bo[args.buf].filetype)
      if not lang then
        return
      end

      local root = M.root_dir(args.buf)
      ctags.generate(config, lang, tag_file_for(lang, root), root, { debounce = true })
    end,
  })
end

M.disable = function()
  if augroup then
    vim.api.nvim_del_augroup_by_id(augroup)
    augroup = nil
  end
  ctags.reset()
end

M.setup = function(opts)
  if vim.fn.has("nvim-0.12") ~= 1 then
    vim.notify("gentags requires Neovim 0.12+", vim.log.levels.ERROR)
    return
  end

  M.disable()
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  if vim.fn.executable(config.bin) ~= 1 then
    vim.notify("gentags: '" .. config.bin .. "' is not executable", vim.log.levels.ERROR)
    return
  end

  if config.autostart then
    M.enable()
  end
end

return M
