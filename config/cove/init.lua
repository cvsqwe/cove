-- Cove Code — терминальная IDE системы Cove. Движок — Neovim (NVIM_APPNAME=cove),
-- всё, что видно и кликается, — свой код в lua/cove/. Запуск: `cove [файл|папка]`.
vim.loader.enable()
require("cove.i18n") -- T() — язык интерфейса, до остальных модулей

require("cove.options")
require("cove.theme").setup()
require("cove.keys")
require("cove.ui.input")
require("cove.ui.menus").setup()
require("cove.ui.tabline").setup()
require("cove.ui.statusline").setup()
require("cove.ui.tree").setup()
require("cove.ui.terminal").setup()
require("cove.ui.dashboard").setup()
require("cove.plugins")
