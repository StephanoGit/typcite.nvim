vim.opt.runtimepath:append(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
vim.opt.runtimepath:append(
  vim.fn.expand("~/.local/share/nvim/site/pack/vendor/start/plenary.nvim"))
require("typcite").setup({ default_keymaps = false })
