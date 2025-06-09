local M = {}

M.locks = {}

M.get_lock_file = function(name)
  local lockfile = M.locks[name]

  -- vim.print("get lock")

  if lockfile ~= nil then
    return lockfile
  end
  lockfile = vim.fn.bufadd(name)
  M.locks[name] = lockfile

  local opts = {
    buflisted = false,
    buftype = "nofile",
  }
  for key, value in pairs(opts) do
    vim.api.nvim_set_option_value(key, value, {
      buf = lockfile,
      scope = "local",
    })
  end

  return nil
end

M.remove_lock = function(name)
  local lockfile = M.locks[name]
  if lockfile == nil then
    return
  end

  vim.api.nvim_buf_delete(lockfile, { force = true })
  M.locks[name] = nil
  -- vim.print("removed lock")
end

local function setTimeout(timeout, callback)
  local timer = vim.uv.new_timer()
  timer:start(timeout, 0, function()
    timer:stop()
    timer:close()
    callback()
  end)
  return timer
end

M.try_lock = function(name, func)
  if vim.fn.win_gettype() == "command" then
    return
  end
  local lockfile = M.get_lock_file(name)

  if lockfile == nil then
    func()
  else
    setTimeout(
      500,
      vim.schedule_wrap(function()
        M.try_lock(name, func)
      end)
    )
  end
end

return M
