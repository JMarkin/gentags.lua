-- Dev entrypoint: run `nvim -u minimal.lua` from the repository root.
vim.opt.runtimepath:prepend(vim.fn.getcwd())

require("gentags").setup()
