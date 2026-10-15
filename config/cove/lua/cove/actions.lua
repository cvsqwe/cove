-- Действия редактора: их вызывают клавиши, меню, стартовый экран и палитра команд.
local M = {}

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO, { title = "Cove" }) end

-- окно для открытия файлов: не дерево, не терминал, не стартовый экран
function M.main_win(create)
  local cur = vim.api.nvim_get_current_win()
  local function ok(w)
    local b = vim.api.nvim_win_get_buf(w)
    local cfg = vim.api.nvim_win_get_config(w)
    return cfg.relative == "" and vim.bo[b].filetype ~= "cove-tree" and vim.bo[b].buftype ~= "terminal"
  end
  if ok(cur) then return cur end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if ok(w) then return w end end
  if not create then return cur end
  vim.cmd("botright vsplit")
  return vim.api.nvim_get_current_win()
end

function M.open(path)
  if not path or path == "" then return end
  path = vim.fn.fnamemodify(path, ":p")
  if vim.fn.isdirectory(path) == 1 then return M.open_folder(path) end
  vim.api.nvim_set_current_win(M.main_win(true))
  vim.cmd.edit(vim.fn.fnameescape(path))
end

function M.open_folder(path)
  path = vim.fn.fnamemodify(path, ":p"):gsub("(.)/$", "%1")
  vim.cmd.cd(vim.fn.fnameescape(path))
  require("cove.ui.tree").open(path)
  notify(T("Папка: ") .. vim.fn.fnamemodify(path, ":~"))
end

function M.pick_folder()
  require("fzf-lua").fzf_exec("fd --type d --hidden --exclude .git --exclude node_modules --max-depth 4 . ~", {
    prompt = T("Папка › "),
    winopts = { title = T(" Открыть папку ") },
    actions = { ["default"] = function(sel) if sel[1] then M.open_folder(vim.fn.expand(sel[1])) end end },
  })
end

function M.new_file()
  vim.api.nvim_set_current_win(M.main_win(true))
  vim.cmd.enew()
end

function M.save()
  if vim.bo.buftype ~= "" then return end
  if vim.api.nvim_buf_get_name(0) == "" then return M.save_as() end
  vim.cmd("silent! write")
  notify(T("Сохранено: ") .. vim.fn.expand("%:t"))
end

function M.save_as()
  vim.ui.input({ prompt = T("Сохранить как: "), default = vim.fn.getcwd() .. "/", completion = "file" }, function(p)
    if not p or p == "" then return end
    vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
    vim.cmd("saveas " .. vim.fn.fnameescape(p))
    require("cove.ui.tree").refresh()
  end)
end

function M.save_all() vim.cmd("silent! wall"); notify(T("Все файлы сохранены")) end

-- закрыть вкладку: окно остаётся, на его месте — соседняя вкладка или стартовый экран
function M.close_buffer(buf)
  buf = (buf and buf ~= 0) and buf or vim.api.nvim_get_current_buf()
  if vim.bo[buf].modified then
    local c = vim.fn.confirm(T("Сохранить «") .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t") .. "»?", T("&Сохранить\n&Не сохранять\n&Отмена"), 1)
    if c == 1 then vim.api.nvim_buf_call(buf, function() M.save() end)
    elseif c ~= 2 then return end
  end
  local others = vim.tbl_filter(function(b) return b ~= buf and vim.bo[b].buflisted end, vim.api.nvim_list_bufs())
  for _, w in ipairs(vim.fn.win_findbuf(buf)) do
    vim.api.nvim_win_call(w, function()
      if #others > 0 then vim.cmd.buffer(others[#others]) else require("cove.ui.dashboard").show() end
    end)
  end
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

function M.quit() vim.cmd("confirm qall") end

function M.find() vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>/", true, false, true), "n", false) end

function M.replace()
  local word = vim.fn.expand("<cword>")
  vim.ui.input({ prompt = T("Найти: "), default = word }, function(a)
    if not a or a == "" then return end
    vim.ui.input({ prompt = T("Заменить «") .. a .. T("» на: ") }, function(b)
      if b == nil then return end
      local esc = function(s) return vim.fn.escape(s, "/\\") end
      local ok, err = pcall(vim.cmd, "%s/\\V" .. esc(a) .. "/" .. esc(b) .. "/g")
      notify(ok and T("Заменено") or (T("Не найдено: ") .. a), ok and nil or vim.log.levels.WARN)
    end)
  end)
end

function M.goto_line()
  vim.ui.input({ prompt = T("Строка: ") }, function(n)
    n = tonumber(n)
    if n then vim.api.nvim_win_set_cursor(0, { math.max(1, math.min(n, vim.api.nvim_buf_line_count(0))), 0 }) end
  end)
end

function M.select_all()
  local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n>gg0vG$<C-g>", true, false, true)
  vim.api.nvim_feedkeys(keys, "n", false)
end

function M.toggle_vim()
  vim.g.cove_vim = not vim.g.cove_vim
  if vim.g.cove_vim then vim.cmd.stopinsert() end
  notify(vim.g.cove_vim and T("Режим Vim включён: Esc — нормальный режим") or T("Обычный режим редактора"))
end

function M.format()
  local ok, conform = pcall(require, "conform")
  if ok then conform.format({ lsp_format = "fallback" }) else vim.lsp.buf.format() end
end

-- палитра команд: всё, что умеет редактор, — по имени
M.commands = {
  { T("Открыть файл…"), function() require("fzf-lua").files() end, "Ctrl+P" },
  { T("Открыть папку…"), M.pick_folder },
  { T("Новый файл"), M.new_file, "Ctrl+N" },
  { T("Сохранить"), M.save, "Ctrl+S" },
  { T("Сохранить как…"), M.save_as, "Ctrl+Shift+S" },
  { T("Сохранить всё"), M.save_all },
  { T("Закрыть вкладку"), function() M.close_buffer() end, "Ctrl+W" },
  { T("Найти в файле"), M.find, "Ctrl+F" },
  { T("Заменить в файле"), M.replace, "Ctrl+H" },
  { T("Найти в проекте"), function() require("fzf-lua").live_grep() end, "Ctrl+Shift+F" },
  { T("Перейти к строке…"), M.goto_line, "Ctrl+G" },
  { T("Последние файлы"), function() require("fzf-lua").oldfiles() end },
  { T("Дерево файлов"), function() require("cove.ui.tree").toggle() end, "Ctrl+B" },
  { T("Терминал"), function() require("cove.ui.terminal").toggle() end, "Ctrl+`" },
  { T("Форматировать файл"), M.format, "Alt+Shift+F" },
  { T("Переименовать символ"), function() vim.lsp.buf.rename() end, "F2" },
  { T("Перейти к определению"), function() vim.lsp.buf.definition() end, "F12" },
  { T("Найти использования"), function() require("fzf-lua").lsp_references() end, "Shift+F12" },
  { T("Быстрые исправления"), function() vim.lsp.buf.code_action() end, "Ctrl+." },
  { T("Проблемы в проекте"), function() require("fzf-lua").diagnostics_workspace() end },
  { T("Языковые серверы (установить)"), function() vim.cmd("Mason") end },
  { T("Режим Vim вкл/выкл"), M.toggle_vim },
  { T("Стартовый экран"), function() require("cove.ui.dashboard").show() end },
  { T("Выход"), M.quit, "Ctrl+Q" },
}

function M.palette()
  local items = vim.tbl_map(function(c) return c[3] and (c[1] .. "  ·  " .. c[3]) or c[1] end, M.commands)
  vim.ui.select(items, { prompt = T("Команда › ") }, function(_, i) if i then M.commands[i][2]() end end)
end

return M
