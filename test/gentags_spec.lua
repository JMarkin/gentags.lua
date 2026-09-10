-- Run: nvim --clean --headless -l test/gentags_spec.lua
-- No framework: every check is an assert-like comparison, a non-zero exit means failure.

local here = vim.fs.dirname(vim.fs.abspath(debug.getinfo(1, "S").source:sub(2)))
local repo = vim.fs.dirname(here)
vim.opt.runtimepath:prepend(repo)

local PROJ = vim.fs.joinpath(here, "fixtures", "proj")
local SRC = vim.fs.joinpath(PROJ, "src", "foo.lua")
local real_system = vim.system

local failures = 0
local caches = {}

local function check(name, ok, extra)
  if not ok then
    failures = failures + 1
  end
  print(
    string.format("%-42s %s%s", name, ok and "OK" or "FAIL", extra ~= nil and ("  [" .. tostring(extra) .. "]") or "")
  )
end

local function read(path)
  local fh = io.open(path, "r")
  if not fh then
    return ""
  end
  local content = fh:read("*a") or ""
  fh:close()
  return content
end

local function count(list, value)
  local n = 0
  for _, v in ipairs(list) do
    if v == value then
      n = n + 1
    end
  end
  return n
end

local function wait_for(fn)
  return vim.wait(10000, fn, 50)
end

local function cache_path(name)
  local path = vim.fn.tempname() .. "-gentags-" .. name
  vim.fn.delete(path, "rf")
  caches[#caches + 1] = path
  return path
end

local function tag_file(cache, root, lang)
  return vim.fs.joinpath(cache, (lang or "Lua") .. vim.base64.encode(vim.fs.abspath(root)))
end

--- Count ctags invocations from now on.
local function count_runs()
  local calls = { n = 0 }
  vim.system = function(...)
    calls.n = calls.n + 1
    return real_system(...)
  end
  return calls
end

local CACHE = cache_path("main")
local gentags = require("gentags")

-- Configuration -------------------------------------------------------------

gentags.setup({ cache = { path = CACHE } })
local first_autocommands = #vim.api.nvim_get_autocmds({ group = "GenTags" })
gentags.setup({ cache = { path = CACHE } })
local second_autocommands = #vim.api.nvim_get_autocmds({ group = "GenTags" })
check(
  "setup twice keeps autocommands unchanged",
  first_autocommands > 0 and first_autocommands == second_autocommands,
  string.format("%d -> %d", first_autocommands, second_autocommands)
)

-- Root detection ------------------------------------------------------------

vim.cmd.edit(SRC)
check("root via pyproject.toml marker", gentags.root_dir(0) == PROJ, gentags.root_dir(0))

local buf = vim.fn.bufadd(vim.fs.joinpath(repo, "lua", "gentags.lua"))
check("root via .git marker", gentags.root_dir(buf) == repo, gentags.root_dir(buf))

gentags.setup({ cache = { path = CACHE }, root_dir = "/tmp/fixed-root" })
check("root_dir string wins", gentags.root_dir(0) == "/tmp/fixed-root", gentags.root_dir(0))

gentags.setup({ cache = { path = CACHE }, root_dir = false })
check("root_dir false falls back to cwd", gentags.root_dir(0) == vim.uv.cwd(), gentags.root_dir(0))

gentags.setup({
  cache = { path = CACHE },
  root_dir = function()
    return "/tmp/function-root"
  end,
})
check("root_dir function wins", gentags.root_dir(0) == "/tmp/function-root", gentags.root_dir(0))

gentags.setup({ cache = { path = CACHE } })
vim.g.gentags_root_dir = "/tmp/global-root"
check("vim.g.gentags_root_dir wins", gentags.root_dir(0) == "/tmp/global-root", gentags.root_dir(0))
vim.g.gentags_root_dir = nil

-- Generation ----------------------------------------------------------------

vim.cmd.edit(SRC)
vim.cmd("setfiletype lua")
local tf = tag_file(CACHE, PROJ)
check(
  "tags generated on FileType",
  wait_for(function()
    return read(tf):find("fixture_fn") ~= nil
  end),
  tf
)

vim.api.nvim_exec_autocmds("FileType", { buffer = 0 })
vim.api.nvim_exec_autocmds("FileType", { buffer = 0 })
check("tag file in 'tags' exactly once", count(vim.opt_local.tags:get(), tf) == 1, count(vim.opt_local.tags:get(), tf))

local runs = count_runs()
vim.cmd.write()
vim.wait(1000)
check("one write runs ctags once", runs.n == 1, runs.n)

runs.n = 0
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = 0 })
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = 0 })
vim.wait(1000)
check("same tick triggers collapse to one run", runs.n == 1, runs.n)

-- A wedged run must absorb later requests instead of spawning parallel ctags.
runs.n = 0
vim.system = function()
  runs.n = runs.n + 1
  return { wait = function() end }
end
for _ = 1, 3 do
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = 0 })
  vim.wait(600)
end
check("in-flight run absorbs later requests", runs.n == 1, runs.n)
vim.system = real_system

-- Disabled triggers ---------------------------------------------------------

local CACHE_OFF = cache_path("off")
gentags.setup({ cache = { path = CACHE_OFF }, generate = { on_open = false, on_write = false } })
vim.cmd.edit(SRC)
vim.api.nvim_exec_autocmds("FileType", { buffer = 0 })
local tf_off = tag_file(CACHE_OFF, PROJ)
runs.n = 0
vim.cmd.write()
vim.wait(1000)
check("on_open/on_write false run nothing", runs.n == 0, runs.n)
check(
  "tag file attached with generation off",
  count(vim.opt_local.tags:get(), tf_off) == 1,
  count(vim.opt_local.tags:get(), tf_off)
)
vim.system = real_system

-- Unmapped filetype ---------------------------------------------------------

gentags.setup({ cache = { path = CACHE } })
vim.bo.filetype = "text"
local ok, result = pcall(gentags.generate)
check("unmapped filetype returns nil", ok and result == nil, tostring(result))

-- Disable and manual generation --------------------------------------------

gentags.disable()
local group_ok, remaining = pcall(vim.api.nvim_get_autocmds, { group = "GenTags" })
check("disable removes autocommands", not group_ok or #remaining == 0, group_ok and #remaining or "group removed")

vim.cmd.edit(SRC)
vim.bo.filetype = "lua"
vim.uv.fs_unlink(tf)
gentags.generate()
check(
  "generate works after disable",
  wait_for(function()
    return read(tf):find("fixture_fn") ~= nil
  end),
  tf
)

-- Health --------------------------------------------------------------------

vim.cmd("checkhealth gentags")

--- Last generated health report.
local function health_report()
  local body = ""
  for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(candidate):match("^health://") then
      body = table.concat(vim.api.nvim_buf_get_lines(candidate, 0, -1, false), "\n")
    end
  end
  return body
end

local body = health_report()
check(
  "checkhealth gentags produces a report",
  body:find("gentags") ~= nil,
  body ~= "" and "report found" or "no report"
)
check("checkhealth gentags has no errors", body:find("ERROR") == nil, body:match("[^\n]*ERROR[^\n]*"))

--- Run the health checks and collect what they report, so a check that never
--- complains cannot pass this spec.
local function collect_health()
  local reported = {}
  local saved = {
    start = vim.health.start,
    ok = vim.health.ok,
    warn = vim.health.warn,
    error = vim.health.error,
    info = vim.health.info,
  }
  vim.health.start = function() end
  for _, level in ipairs({ "ok", "warn", "error", "info" }) do
    vim.health[level] = function(msg)
      reported[#reported + 1] = level:upper() .. " " .. tostring(msg)
    end
  end
  local ok, err = pcall(require("gentags.health").check)
  vim.health.start = saved.start
  vim.health.ok = saved.ok
  vim.health.warn = saved.warn
  vim.health.error = saved.error
  vim.health.info = saved.info
  return table.concat(reported, "\n"), ok, err
end

local healthy, health_ok = collect_health()
check("health check runs", health_ok, health_ok and nil or healthy)
check(
  "health reports universal-ctags",
  healthy:find("universal%-ctags") ~= nil,
  healthy:find("universal%-ctags") and "universal-ctags" or healthy
)
check("health reports no errors", healthy:find("ERROR") == nil, healthy:match("[^\n]*ERROR[^\n]*"))

-- A health check that never complains is worthless: force a broken config.
gentags.setup({ cache = { path = CACHE }, bin = "gentags-no-such-ctags" })
local broken = collect_health()
check(
  "health reports a missing binary",
  broken:find("not executable") ~= nil,
  broken:match("[^\n]*not executable[^\n]*")
)

gentags.disable()
for _, path in ipairs(caches) do
  vim.fn.delete(path, "rf")
end

print(failures == 0 and "SPEC PASS" or ("SPEC FAIL: " .. failures))
os.exit(failures == 0 and 0 or 1)
