-- Поведение «обычного редактора»: мышь, системный буфер обмена, всегда режим ввода.
local o = vim.opt

o.mouse = "a"
o.mousemodel = "popup_setpos"          -- правый клик — контекстное меню (lua/cove/ui/menus.lua)
o.mousescroll = "ver:3,hor:6"
o.selectmode = "mouse,key"             -- выделение мышью и Shift+стрелками — как в обычных редакторах:
o.keymodel = "startsel,stopsel"        -- набранный текст заменяет выделенное
o.clipboard = "unnamedplus"            -- копировать/вставить — через системный буфер (wl-clipboard)
o.whichwrap = "b,s,<,>,[,]"            -- стрелки переходят на соседнюю строку
o.virtualedit = "onemore"

o.number = true
o.signcolumn = "yes"
o.cursorline = true
o.termguicolors = true
o.showmode = false
o.laststatus = 3                       -- одна статусная строка на всё окно
o.showtabline = 2                      -- строка меню и вкладок видна всегда
o.cmdheight = 1
o.splitright = true
o.splitbelow = true
o.scrolloff = 6
o.sidescrolloff = 8
o.wrap = false
o.undofile = true
o.swapfile = false
o.confirm = true                       -- закрытие несохранённого — вопрос, а не ошибка
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.updatetime = 250
o.timeoutlen = 400
o.pumheight = 12
o.winborder = "rounded"
o.fillchars = { eob = " ", vert = "│", horiz = "─" }
o.title = true
o.titlestring = "%t — Cove Code"
o.shortmess:append("IcsW")
o.completeopt = "menu,menuone,noselect"

vim.g.loaded_netrw = 1                 -- папки открывает своё дерево (ui/tree.lua)
vim.g.loaded_netrwPlugin = 1

-- ---- всегда режим ввода ----
-- В обычных файлах редактор сразу печатает. Режим Vim можно включить: меню «Вид» → «Режим Vim».
vim.g.cove_vim = false

local function editable(buf)
  buf = buf or 0
  return vim.bo[buf].buftype == "" and vim.bo[buf].modifiable and not vim.bo[buf].readonly
end
_G.CoveEditable = editable

local function ensure_insert()
  if vim.g.cove_vim or not editable() then return end
  local m = vim.api.nvim_get_mode().mode
  if m == "n" then vim.cmd.startinsert() end
end

local grp = vim.api.nvim_create_augroup("CoveInsert", {})
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, { group = grp, callback = function() vim.schedule(ensure_insert) end })
-- после копирования, выделения, команд — снова печатаем
vim.api.nvim_create_autocmd("ModeChanged", { group = grp, pattern = "*:n", callback = function() vim.schedule(ensure_insert) end })
