local Job = require("plenary.job")
local M = {}

local current_running = nil
local tag_added = false

M.generate = function(cfg, file)
  local args = vim.deepcopy(cfg.ctags.args)

  table.insert(args, "-f")

  local tagfile = cfg.cache.path:joinpath(cfg.tag_file_name):expand()
  if cfg.ctags.in_root then
    tagfile = cfg.root_dir:joinpath(cfg.tag_file_name):expand()
  end

  table.insert(args, tagfile)

  if cfg.ctags.update_all then
    table.insert(args, "-R")
    table.insert(args, cfg.root_dir:expand())
  else
    table.insert(args, "-a")
    table.insert(args, file)
  end

  local j = Job:new({
    command = cfg.ctags.bin,
    args = args,
    on_exit = vim.schedule_wrap(function(job, code)
      if code ~= 0 then
        vim.notify(job._stderr_results, vim.log.levels.ERROR)
        vim.pretty_print(args)
      else
        if not tag_added then
          vim.cmd("set tags+=" .. tagfile)
          tag_added = true
        end
      end
      current_running = nil
    end),
  })

  if current_running ~= nil then
    vim.loop.kill(current_running.pid, 3)
  end
  j:start()
  current_running = j
end

return M
