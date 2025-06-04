local lock = require("gentags.lockfile")

local M = {}

M.generate = function(cfg, lang, tag_file, filepath)
  local args = {
    "--languages=" .. lang,
    "-f",
    tag_file,
  }

  for _, v in ipairs(cfg.args) do
    table.insert(args, v)
  end

  -- if filepath then
  --   table.insert(args, "-a")
  --   table.insert(args, filepath)
  -- else
  table.insert(args, "-R")
  table.insert(args, cfg.root_dir)
  -- end

  local lockname = vim.base64.encode(tag_file)

  lock.try_lock(lockname, function()
    local j = vim.system(
      { cfg.bin, table.unpack(args) },
      {
        text = true,
      },
      vim.schedule_wrap(function(obj)
        local code = obj.code
        if code ~= 0 then
          vim.notify(obj.stderr, vim.log.levels.ERROR)
        end

        lock.remove_lock(lockname)
      end)
    )

    -- vim.print(j.pid)

    if not cfg.async then
      j:wait()
    end
    -- vim.print(cfg.bin)
  end)
end

return M
