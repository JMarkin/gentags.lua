local gentags = require("gentags")

vim.api.nvim_create_user_command("GenCTags", gentags.generate, { nargs = 0 })
vim.api.nvim_create_user_command("GenTagsEnable", gentags.enable, { nargs = 0 })
vim.api.nvim_create_user_command("GenTagsDisable", gentags.disable, { nargs = 0 })
