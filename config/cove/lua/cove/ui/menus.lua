-- Меню: строка «Файл / Правка / …» (открывается кликом в верхней строке) и правый клик.
-- Правый клик зависит от места: дерево файлов, выделение или обычный код.
local A = require("cove.actions")
local M = {}

local fns = {}
_G.CoveMenu = function(i) local f = fns[i]; if f then vim.schedule(f) end end

local function esc(s) return (s:gsub("([ .\\|<])", "\\%1")) end
local function add(cmd, menu, label, key, fn)
  fns[#fns + 1] = fn
  local name = esc(menu) .. "." .. esc(label) .. (key and ("<Tab>" .. esc(key)) or "")
  vim.cmd(string.format("%s %s <Cmd>lua CoveMenu(%d)<CR>", cmd, name, #fns))
end
local seps = 0
local function sep(cmd, menu) seps = seps + 1; vim.cmd(string.format("%s %s.-s%d- <Nop>", cmd, esc(menu), seps)) end

local fzf = function(name, opts) return function() require("fzf-lua")[name](opts) end end
local tree = function(name) return function() require("cove.ui.tree")[name]() end end

-- верхние меню (порядок = порядок в строке)
M.top = {
  { T("Файл"), {
    { T("Новый файл"), "Ctrl+N", A.new_file },
    { T("Открыть файл…"), "Ctrl+P", fzf("files") },
    { T("Открыть папку…"), nil, A.pick_folder },
    { T("Последние файлы"), nil, fzf("oldfiles") },
    "-",
    { T("Сохранить"), "Ctrl+S", A.save },
    { T("Сохранить как…"), "Ctrl+Shift+S", A.save_as },
    { T("Сохранить всё"), nil, A.save_all },
    "-",
    { T("Закрыть вкладку"), "Ctrl+W", function() A.close_buffer() end },
    { T("Стартовый экран"), nil, function() require("cove.ui.dashboard").show() end },
    { T("Выход"), "Ctrl+Q", A.quit },
  } },
  { T("Правка"), {
    { T("Отменить"), "Ctrl+Z", function() vim.cmd.undo() end },
    { T("Повторить"), "Ctrl+Y", function() vim.cmd.redo() end },
    "-",
    { T("Выделить всё"), "Ctrl+A", A.select_all },
    { T("Вставить"), "Ctrl+V", function() vim.api.nvim_paste(vim.fn.getreg("+"), true, -1) end },
    "-",
    { T("Найти"), "Ctrl+F", A.find },
    { T("Заменить"), "Ctrl+H", A.replace },
    { T("Найти в проекте"), "Ctrl+Shift+F", fzf("live_grep") },
    "-",
    { T("Комментарий"), "Ctrl+/", function() vim.cmd("normal gcc") end },
    { T("Дублировать строку"), "Ctrl+Shift+D", function() vim.cmd("copy .") end },
    { T("Удалить строку"), "Ctrl+Shift+K", function() vim.cmd("delete _") end },
  } },
  { T("Вид"), {
    { T("Палитра команд"), "Ctrl+Shift+P", A.palette },
    "-",
    { T("Дерево файлов"), "Ctrl+B", tree("toggle") },
    { T("Терминал"), "Ctrl+`", function() require("cove.ui.terminal").toggle() end },
    { T("Проблемы"), nil, fzf("diagnostics_workspace") },
    "-",
    { T("Перенос строк"), nil, function() vim.wo.wrap = not vim.wo.wrap end },
    { T("Разделить вправо"), nil, function() vim.cmd("vsplit") end },
    { T("Разделить вниз"), nil, function() vim.cmd("split") end },
    "-",
    { T("Режим Vim вкл/выкл"), nil, A.toggle_vim },
  } },
  { T("Перейти"), {
    { T("К файлу…"), "Ctrl+P", fzf("files") },
    { T("К строке…"), "Ctrl+G", A.goto_line },
    { T("К символу в файле…"), nil, fzf("lsp_document_symbols") },
    "-",
    { T("К определению"), "F12", function() vim.lsp.buf.definition() end },
    { T("К использованиям"), "Shift+F12", fzf("lsp_references") },
    { T("Назад"), nil, function() vim.cmd([[execute "normal! \<C-o>"]]) end },
    "-",
    { T("Следующая вкладка"), "Ctrl+Tab", function() vim.cmd.bnext() end },
    { T("Предыдущая вкладка"), "Ctrl+Shift+Tab", function() vim.cmd.bprevious() end },
  } },
  { T("Код"), {
    { T("Подсказка"), "Ctrl+K", function() vim.lsp.buf.hover() end },
    { T("Быстрые исправления"), "Ctrl+.", function() vim.lsp.buf.code_action() end },
    { T("Переименовать символ"), "F2", function() vim.lsp.buf.rename() end },
    { T("Форматировать"), "Alt+Shift+F", A.format },
    "-",
    { T("Языковые серверы…"), nil, function() vim.cmd("Mason") end },
    { T("Git: изменения в файле"), nil, fzf("git_bcommits") },
    { T("Git: статус"), nil, fzf("git_status") },
  } },
  { T("Терминал"), {
    { T("Показать/скрыть"), "Ctrl+`", function() require("cove.ui.terminal").toggle() end },
    { T("Новый терминал"), nil, function() require("cove.ui.terminal").new() end },
    { T("Запустить файл"), "F5", function() require("cove.ui.terminal").run_file() end },
  } },
}

function M.build_top()
  for _, m in ipairs(M.top) do
    pcall(vim.cmd, "aunmenu " .. esc(m[1]))
    for _, it in ipairs(m[2]) do
      if it == "-" then sep("anoremenu", m[1]) else add("anoremenu", m[1], it[1], it[2], it[3]) end
    end
  end
end

function M.open(i)
  local m = M.top[i]
  if m then vim.cmd("popup " .. esc(m[1])) end
end

-- ---- правый клик ----
local function popup_editor(visual)
  if visual then
    add("vnoremenu", "PopUp", T("Вырезать"), "Ctrl+X", function() vim.cmd('normal! gv"+d') end)
    add("vnoremenu", "PopUp", T("Копировать"), "Ctrl+C", function() vim.cmd('normal! gv"+y') end)
    add("vnoremenu", "PopUp", T("Вставить"), "Ctrl+V", function() vim.cmd('normal! gv"_d"+P') end)
    sep("vnoremenu", "PopUp")
    add("vnoremenu", "PopUp", T("Комментарий"), "Ctrl+/", function() vim.cmd("normal gvgc") end)
    add("vnoremenu", "PopUp", T("Найти в проекте"), nil, function()
      vim.cmd('normal! gv"zy'); require("fzf-lua").grep({ search = vim.fn.getreg("z") })
    end)
    return
  end
  local lsp = #vim.lsp.get_clients({ bufnr = 0 }) > 0
  if lsp then
    add("anoremenu", "PopUp", T("К определению"), "F12", function() vim.lsp.buf.definition() end)
    add("anoremenu", "PopUp", T("Найти использования"), "Shift+F12", fzf("lsp_references"))
    add("anoremenu", "PopUp", T("Переименовать"), "F2", function() vim.lsp.buf.rename() end)
    add("anoremenu", "PopUp", T("Быстрые исправления"), "Ctrl+.", function() vim.lsp.buf.code_action() end)
    add("anoremenu", "PopUp", T("Подсказка"), "Ctrl+K", function() vim.lsp.buf.hover() end)
    sep("anoremenu", "PopUp")
  end
  add("anoremenu", "PopUp", T("Вставить"), "Ctrl+V", function() vim.api.nvim_paste(vim.fn.getreg("+"), true, -1) end)
  add("anoremenu", "PopUp", T("Выделить всё"), "Ctrl+A", A.select_all)
  add("anoremenu", "PopUp", T("Отменить"), "Ctrl+Z", function() vim.cmd.undo() end)
  sep("anoremenu", "PopUp")
  add("anoremenu", "PopUp", T("Комментарий"), "Ctrl+/", function() vim.cmd("normal gcc") end)
  add("anoremenu", "PopUp", T("Форматировать"), "Alt+Shift+F", A.format)
  add("anoremenu", "PopUp", T("Найти в проекте"), "Ctrl+Shift+F", fzf("live_grep"))
end

local function popup_tree()
  local T = require("cove.ui.tree")
  add("anoremenu", "PopUp", T("Открыть"), nil, T.activate)
  sep("anoremenu", "PopUp")
  add("anoremenu", "PopUp", T("Новый файл"), nil, T.new_file)
  add("anoremenu", "PopUp", T("Новая папка"), nil, T.new_dir)
  add("anoremenu", "PopUp", T("Переименовать"), "F2", T.rename)
  add("anoremenu", "PopUp", T("Удалить"), "Del", T.delete)
  sep("anoremenu", "PopUp")
  add("anoremenu", "PopUp", T("Копировать путь"), nil, T.copy_path)
  add("anoremenu", "PopUp", T("Открыть в терминале"), nil, T.terminal_here)
  add("anoremenu", "PopUp", T("Найти в папке"), nil, T.grep_here)
  sep("anoremenu", "PopUp")
  add("anoremenu", "PopUp", T("Показать скрытые"), nil, T.toggle_hidden)
  add("anoremenu", "PopUp", T("Обновить"), nil, T.refresh)
end

function M.setup()
  M.build_top()
  vim.api.nvim_create_autocmd("MenuPopup", {
    callback = function(ev)
      pcall(vim.cmd, "aunmenu PopUp")
      if vim.bo.filetype == "cove-tree" then popup_tree()
      elseif vim.bo.buftype == "terminal" then
        add("anoremenu", "PopUp", T("Вставить"), nil, function() vim.api.nvim_paste(vim.fn.getreg("+"), true, -1) end)
        add("anoremenu", "PopUp", T("Скрыть терминал"), nil, function() require("cove.ui.terminal").toggle() end)
      else popup_editor(ev.match:find("[vVsS\22\19]") ~= nil) end
    end,
  })
end

return M
