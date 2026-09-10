local M = {}

-- One ctags run per tag file at a time; later requests collapse into a single follow-up run.
local running = {}
local pending = {}
local timers = {}

-- ponytail: fixed debounce for write-triggered runs, expose it if anyone needs tuning.
local DEBOUNCE_MS = 300

local function run(cfg, lang, tag_file, root)
  if running[tag_file] then
    pending[tag_file] = true
    return
  end

  vim.fn.mkdir(vim.fs.dirname(tag_file), "p")

  local args = { cfg.bin, "--languages=" .. lang, "-f", tag_file }
  vim.list_extend(args, cfg.args)
  vim.list_extend(args, { "-R", root })

  running[tag_file] = true
  local job = vim.system(
    args,
    { text = true },
    vim.schedule_wrap(function(obj)
      running[tag_file] = nil
      if obj.code ~= 0 then
        vim.notify(
          "gentags: " .. cfg.bin .. " failed (" .. obj.code .. ")\n" .. (obj.stderr or ""),
          vim.log.levels.ERROR
        )
      end
      -- ponytail: ctags writes straight to tag_file, a failed run can leave it partial.
      -- Write to a temp file and rename if that ever bites.
      if pending[tag_file] then
        pending[tag_file] = nil
        run(cfg, lang, tag_file, root)
      end
    end)
  )

  if not cfg.async then
    job:wait()
  end
end

--- Generate tags for a language into tag_file.
--- @param opts? { debounce?: boolean }
M.generate = function(cfg, lang, tag_file, root, opts)
  if not (opts and opts.debounce) then
    run(cfg, lang, tag_file, root)
    return
  end

  local timer = timers[tag_file]
  if not timer then
    timer = vim.uv.new_timer()
    timers[tag_file] = timer
  end

  -- Starting an active timer restarts it, so rapid writes collapse into one run.
  timer:start(
    DEBOUNCE_MS,
    0,
    vim.schedule_wrap(function()
      timer:stop()
      run(cfg, lang, tag_file, root)
    end)
  )
end

M.reset = function()
  for name, timer in pairs(timers) do
    timer:stop()
    timer:close()
    timers[name] = nil
  end
  running = {}
  pending = {}
end

return M
