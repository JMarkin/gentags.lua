local ctags = require("gentags.ctags")
local Path = require("plenary.path")

local M = {}
local config = {
  root_dir = vim.loop.cwd(),
  tag_file_name = nil,
  method = "ctags",
  pattern = { "*" },
  cache = {
    path = Path:new(vim.loop.os_homedir()):joinpath(".cache"):joinpath("nvim"):joinpath("tags"),
    in_root = false,
  },
  ctags = {
    bin = "ctags",
    args = {
      "--extras=+r",
      "--exclude=.git",
      "--exclude=*.db",
      "--exclude=.mypy*",
      "--exclude=.pytest*",
      "--exclude=BUILD",
      "--exclude=.svn",
      "--exclude=vendor*",
      "--exclude=*log*",
      "--exclude=*.min.*",
      "--exclude=*.pyc",
      "--exclude=*.cache",
      "--exclude=*.dll",
      "--exclude=*.pdb",
    },
    update_all = true,
  },
}

M.ctags = function(file)
  ctags.generate(config, file)
end

M.generate = function(opts)
  M[config.method](opts.file)
end

local au_group = nil
local autocmds = function()
  au_group = vim.api.nvim_create_augroup("GenTags", { clear = true })
  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    group = au_group,
    pattern = config.pattern,
    callback = M.generate,
  })
end

local generate_all = function()
  local pre_config = vim.deepcopy(config)
  config.ctags.update_all = true
  M[config.method]()
  config = pre_config
  autocmds()
end

M.enable = function(language)
  if language ~= nil then
    table.insert(config.ctags.args, "--languages=" .. language)
  end
  generate_all()
  autocmds()
end

M.disable = function()
  if au_group ~= nil then
    vim.api.nvim_del_augroup_by_id(au_group)
    au_group = nil
  end
end

M.setup = function(args)
  if args == nil then
    args = {}
  end
  config = vim.tbl_deep_extend("keep", args, config)

  if not config.tag_file_name then
    local root_path = Path:new(config.root_dir)

    config.tag_file_name = root_path:shorten():gsub(root_path._sep, "_"):gsub("%.", "")
    config.root_dir = root_path
  end
  Path:new(config.cache.path):mkdir({ exists_ok = true })
end

return M
