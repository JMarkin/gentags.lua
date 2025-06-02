local gentags = require("gentags")

vim.api.nvim_create_user_command(
  "GenCTags",
  gentags.generate,
  { nargs = 0, desc = "Generate tags by ctags and add it to tags" }
)
vim.api.nvim_create_user_command("GenTagsEnable", gentags.enable, { nargs = 0, desc = "Enable autoappend tags" })
vim.api.nvim_create_user_command("GenTagsDisable", gentags.disable, { nargs = 0, desc = "Disable autoappend tags" })
