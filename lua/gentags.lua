local ctags = require("gentags.ctags")

local M = {}
local config = {
  autostart = true,
  append_on_save = true,
  root_dir = vim.g.gentags_root_dir or vim.uv.cwd(),
  cache = {
    path = vim.fs.joinpath(vim.fn.stdpath("cache"), "tags"),
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
  -- generate filetype based tag
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

local LANG_TAG_MAP = {}

local au_group = vim.api.nvim_create_augroup("GenTags", { clear = true })

local setup_langmap = function()
  if #LANG_TAG_MAP ~= 0 then
    return
  end
  local root_path = config.root_dir

  local cwd_b64 = vim.base64.encode(root_path)

  for lang, _ in pairs(config.lang_ft_map) do
    local tag_file = lang:gsub(",", "_") .. cwd_b64
    LANG_TAG_MAP[lang] = vim.fs.joinpath(config.cache.path, tag_file)
  end
end

M.generate = function()
  local lang = nil
  local ft = vim.bo.filetype

  for key, fts in pairs(config.lang_ft_map) do
    for _, _ft in ipairs(fts) do
      if ft == _ft then
        lang = key
        break
      end
    end
  end
  if not lang then
    return
  end

  setup_langmap()
  local tag_file = LANG_TAG_MAP[lang]
  vim.cmd("setlocal tags+=" .. tag_file)
  ctags.generate(config, lang, tag_file, nil)
  return tag_file
end

M.enable = function()
  setup_langmap()
  for lang, ft in pairs(config.lang_ft_map) do
    local tag_file = LANG_TAG_MAP[lang]

    -- init file
    vim.api.nvim_create_autocmd({ "FileType" }, {
      group = au_group,
      pattern = ft,
      once = true,
      callback = function()
        if vim.fn.exists(tag_file) == 1 then
          return
        end
        ctags.generate(config, lang, tag_file, nil)
      end,
    })

    -- buffer append generated tagfile
    vim.api.nvim_create_autocmd({ "FileType" }, {
      group = au_group,
      pattern = ft,
      callback = function(args)
        -- append new tags to file
        vim.cmd("setlocal tags+=" .. tag_file)
        -- vim.print(tag_file)

        vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
          group = au_group,
          buffer = args.buf,
          callback = function()
            local filepath = vim.fn.expand("%:p")
            ctags.generate(config, lang, tag_file, filepath)
          end,
        })
      end,
    })
  end
end

M.disable = function()
  if au_group ~= nil then
    vim.api.nvim_del_augroup_by_id(au_group)
    au_group = vim.api.nvim_create_augroup("GenTags", { clear = true })
  end
end

M.setup = function(args)
  if args == nil then
    args = {}
  end
  config = vim.tbl_deep_extend("keep", args, config)

  vim.fn.mkdir(vim.fs.dirname(config.cache.path), "p")

  if config.autostart then
    M.enable()
  end
end

return M
