-- Клавиши как в обычных редакторах (VS Code и т.п.). Во всех режимах: ввод, выделение, нормальный.
local A = require("cove.actions")
local map = function(modes, lhs, rhs, desc, opts)
  vim.keymap.set(modes, lhs, rhs, vim.tbl_extend("force", { silent = true, desc = desc }, opts or {}))
end
local all = { "n", "i", "v" }

-- файлы
map(all, "<C-s>", A.save, T("Сохранить"))
map(all, "<C-S-s>", A.save_as, T("Сохранить как"))
map(all, "<C-n>", A.new_file, T("Новый файл"))
map(all, "<C-o>", function() require("fzf-lua").files() end, T("Открыть файл"))
map(all, "<C-p>", function() require("fzf-lua").files() end, T("Открыть файл"))
map(all, "<C-S-p>", A.palette, T("Палитра команд"))
map(all, "<F1>", A.palette, T("Палитра команд"))
map(all, "<C-w>", function() A.close_buffer() end, T("Закрыть вкладку"))
map(all, "<C-q>", A.quit, T("Выход"))

-- правка
map(all, "<C-z>", "<Cmd>undo<CR>", T("Отменить"))
map(all, "<C-y>", "<Cmd>redo<CR>", T("Повторить"))
map(all, "<C-S-z>", "<Cmd>redo<CR>", T("Повторить"))
map(all, "<C-a>", A.select_all, T("Выделить всё"))
map("v", "<C-c>", '"+y', T("Копировать"))
map("v", "<C-x>", '"+d', T("Вырезать"))
map("v", "<C-v>", '"_d"+P', T("Вставить вместо выделения"))
map("i", "<C-v>", "<C-r><C-o>+", T("Вставить"))
map("n", "<C-v>", '"+P', T("Вставить"))
map("i", "<C-c>", '<Cmd>let @+ = getline(".") . "\n"<CR>', T("Копировать строку"))
map("i", "<C-x>", '<Cmd>let @+ = getline(".") . "\n"<CR><Cmd>delete _<CR>', T("Вырезать строку"))
map("i", "<C-S-d>", "<Cmd>copy .<CR>", T("Дублировать строку"))
map("i", "<C-S-k>", "<Cmd>delete _<CR>", T("Удалить строку"))
map("i", "<A-Up>", "<Cmd>move .-2<CR>", T("Строку вверх"))
map("i", "<A-Down>", "<Cmd>move .+1<CR>", T("Строку вниз"))
map("v", "<A-Up>", ":move '<-2<CR>gv", T("Строки вверх"))
map("v", "<A-Down>", ":move '>+1<CR>gv", T("Строки вниз"))
map("i", "<C-/>", "<Cmd>normal gcc<CR>", T("Комментарий"), { remap = true })
map("i", "<C-_>", "<Cmd>normal gcc<CR>", T("Комментарий"), { remap = true })
map("v", "<C-/>", "gc", T("Комментарий"), { remap = true })
map("i", "<C-BS>", "<C-w>", T("Удалить слово"))
map("i", "<C-Del>", "<C-o>dw", T("Удалить слово вперёд"))
map("v", "<Tab>", ">gv", T("Отступ"))
map("v", "<S-Tab>", "<gv", T("Убрать отступ"))
map("v", "<BS>", '"_d', T("Удалить выделенное"))
map("i", "<Esc>", function()
  if package.loaded["blink.cmp"] and require("blink.cmp").is_visible() then require("blink.cmp").hide() end
  vim.cmd.nohlsearch()
end, T("Закрыть подсказки и подсветку поиска"))

-- поиск и переходы
map(all, "<C-f>", A.find, T("Найти"))
map(all, "<C-h>", A.replace, T("Заменить"))
map(all, "<F3>", "<Cmd>normal! n<CR>", T("Следующее совпадение"))
map(all, "<S-F3>", "<Cmd>normal! N<CR>", T("Предыдущее совпадение"))
map(all, "<C-S-f>", function() require("fzf-lua").live_grep() end, T("Найти в проекте"))
map(all, "<C-g>", A.goto_line, T("Перейти к строке"))
map(all, "<F12>", function() vim.lsp.buf.definition() end, T("К определению"))
map(all, "<S-F12>", function() require("fzf-lua").lsp_references() end, T("Использования"))
map(all, "<F2>", function() vim.lsp.buf.rename() end, T("Переименовать"))
map(all, "<C-.>", function() vim.lsp.buf.code_action() end, T("Быстрые исправления"))
map(all, "<A-S-f>", A.format, T("Форматировать"))
map(all, "<C-k>", function() vim.lsp.buf.hover() end, T("Подсказка"))

-- вкладки и панели
map(all, "<C-PageDown>", "<Cmd>bnext<CR>", T("Следующая вкладка"))
map(all, "<C-PageUp>", "<Cmd>bprevious<CR>", T("Предыдущая вкладка"))
map(all, "<C-Tab>", "<Cmd>bnext<CR>", T("Следующая вкладка"))
map(all, "<C-S-Tab>", "<Cmd>bprevious<CR>", T("Предыдущая вкладка"))
for i = 1, 9 do
  map(all, "<A-" .. i .. ">", function() require("cove.ui.tabline").go(i) end, T("Вкладка ") .. i)
end
map(all, "<C-b>", function() require("cove.ui.tree").toggle() end, T("Дерево файлов"))
map({ "n", "i", "v", "t" }, "<C-`>", function() require("cove.ui.terminal").toggle() end, T("Терминал"))
map({ "n", "i", "v", "t" }, "<C-j>", function() require("cove.ui.terminal").toggle() end, T("Терминал"))
