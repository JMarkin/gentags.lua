local M = {}

local function ctags_version(bin)
  local ok, out = pcall(function()
    return vim.system({ bin, "--version" }, { text = true }):wait()
  end)
  if not ok or out.code ~= 0 then
    return nil
  end
  return (out.stdout or ""):match("^[^\n]*")
end

M.check = function()
  vim.health.start("gentags")

  if vim.fn.has("nvim-0.12") == 1 then
    vim.health.ok("Neovim " .. tostring(vim.version()))
  else
    vim.health.error("gentags requires Neovim 0.12+, found " .. tostring(vim.version()))
  end

  local gentags = require("gentags")
  local config = gentags.get_config()

  local bin = config.bin
  if vim.fn.executable(bin) ~= 1 then
    vim.health.error("'" .. bin .. "' is not executable")
  else
    local version = ctags_version(bin)
    if version and version:find("Universal Ctags") then
      vim.health.ok("'" .. bin .. "' is universal-ctags (" .. version .. ")")
    else
      vim.health.warn("'" .. bin .. "' is not universal-ctags, --extras/--exclude args may not work")
    end
  end

  local cache = config.cache.path
  vim.fn.mkdir(cache, "p")
  if vim.fn.isdirectory(cache) == 1 and vim.uv.fs_access(cache, "W") then
    vim.health.ok("cache path is writable: " .. cache)
  else
    vim.health.error("cache path is not writable: " .. cache)
  end

  if next(config.lang_ft_map) == nil then
    vim.health.error("lang_ft_map is empty, no filetype will generate tags")
  else
    local ft_count = 0
    for _, fts in pairs(config.lang_ft_map) do
      ft_count = ft_count + #fts
    end
    vim.health.info(
      string.format("%d ctags languages mapped to %d filetypes", vim.tbl_count(config.lang_ft_map), ft_count)
    )
  end

  vim.health.info(
    string.format(
      "generate.on_open: %s, generate.on_write: %s, async: %s",
      tostring(config.generate.on_open),
      tostring(config.generate.on_write),
      tostring(config.async)
    )
  )

  local ok, root = pcall(gentags.root_dir)
  if ok and root then
    vim.health.info("root for the current buffer: " .. root)
  else
    vim.health.warn("no root resolved for the current buffer")
  end

  local tag_files = vim.fn.glob(cache .. "/*", false, true)
  vim.health.info(#tag_files .. " tag file(s) in the cache")
end

return M
