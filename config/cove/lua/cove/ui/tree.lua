-- Дерево файлов слева. Клик по папке — раскрыть, по файлу — открыть. Правый клик — меню (ui/menus.lua).
local M = { root = nil, buf = nil, win = nil, expanded = {}, hidden = false, width = 32, entries = {} }
local uv = vim.uv
local ns = vim.api.nvim_create_namespace("cove-tree")

local function icon(name, isdir, open)
  local ok, mi = pcall(require, "mini.icons")
  if isdir then return open and "󰝰" or "󰉋", "CoveTreeDir" end
  if not ok then return "󰈔", "CoveTree" end
  return mi.get("file", name)
end

local function scan(dir)
  local out = {}
  local h = uv.fs_scandir(dir)
  if not h then return out end
  while true do
    local name, t = uv.fs_scandir_next(h)
    if not name then break end
    if name ~= ".git" and (M.hidden or name:sub(1, 1) ~= ".") then
      local path = (dir == "/" and "" or dir) .. "/" .. name
      local isdir = t == "directory" or (t == "link" and vim.fn.isdirectory(path) == 1)
      out[#out + 1] = { name = name, path = path, dir = isdir }
    end
  end
  table.sort(out, function(a, b)
    if a.dir ~= b.dir then return a.dir end
    return a.name:lower() < b.name:lower()
  end)
  return out
end

local function modified_set()
  local s = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].modified then s[vim.api.nvim_buf_get_name(b)] = true end
  end
  return s
end

function M.render()
  if not (M.buf and vim.api.nvim_buf_is_valid(M.buf)) then return end
  M.entries = {}
  local lines, marks = {}, {}
  local mods = modified_set()
  local cur = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(require("cove.actions").main_win()))
  local function walk(dir, depth)
    for _, e in ipairs(scan(dir)) do
      local open = e.dir and M.expanded[e.path]
      local ic, ichl = icon(e.name, e.dir, open)
      local arrow = e.dir and (open and "󰅀" or "󰅂") or " "
      local pre = string.rep("  ", depth) .. " " .. arrow .. " "
      local line = pre .. ic .. " " .. e.name
      lines[#lines + 1] = line
      e.depth = depth
      M.entries[#lines] = e
      local name_hl = e.path == cur and "CoveTreeActive" or mods[e.path] and "CoveTreeModified" or e.dir and "CoveTreeDir" or "CoveTree"
      marks[#marks + 1] = { #lines - 1, 0, #pre, "CoveTreeDim" }
      marks[#marks + 1] = { #lines - 1, #pre, #pre + #ic, ichl }
      marks[#marks + 1] = { #lines - 1, #pre + #ic + 1, #line, name_hl }
      if mods[e.path] then marks[#marks + 1] = { #lines - 1, #line, nil, "CoveTreeModified", "●" } end
      if open then walk(e.path, depth + 1) end
    end
  end
  walk(M.root, 0)
  if #lines == 0 then lines = { T("   Пустая папка") } end
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.bo[M.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    if m[5] then
      vim.api.nvim_buf_set_extmark(M.buf, ns, m[1], 0, { virt_text = { { " " .. m[5], m[4] } }, virt_text_pos = "eol" })
    else
      vim.api.nvim_buf_set_extmark(M.buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
    end
  end
end

function M.refresh() vim.schedule(M.render) end

-- кнопки в заголовке дерева
_G.CoveTreeBtn = function(i)
  if i == 1 then M.new_file(M.root)
  elseif i == 2 then M.new_dir(M.root)
  elseif i == 3 then M.collapse_all()
  elseif i == 4 then M.refresh() end
end

local function winbar()
  local name = vim.fn.fnamemodify(M.root, ":t"):upper()
  return "%#CoveTreeTitle#  " .. name .. "%=%#CoveTreeDim#"
    .. "%1@v:lua.CoveTreeBtn@ 󰝒 %X%2@v:lua.CoveTreeBtn@ 󰉗 %X%3@v:lua.CoveTreeBtn@ 󰅀 %X%4@v:lua.CoveTreeBtn@ 󰑐 %X "
end

local function setup_buf()
  M.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[M.buf].filetype = "cove-tree"
  vim.bo[M.buf].bufhidden = "hide"
  vim.api.nvim_buf_set_name(M.buf, "cove://tree")
  local o = { buffer = M.buf, silent = true, nowait = true }
  require("cove.ui.click").bind(M.buf, function() M.activate() end)
  vim.keymap.set("n", "<CR>", function() M.activate() end, o)
  vim.keymap.set("n", "<F2>", function() M.rename() end, o)
  vim.keymap.set("n", "<Del>", function() M.delete() end, o)
  vim.keymap.set("n", "<C-n>", function() M.new_file() end, o)
end

local function setup_win()
  local w = M.win
  vim.wo[w].number = false
  vim.wo[w].relativenumber = false
  vim.wo[w].signcolumn = "no"
  vim.wo[w].cursorline = true
  vim.wo[w].wrap = false
  vim.wo[w].winfixwidth = true
  vim.wo[w].statuscolumn = ""
  vim.wo[w].foldcolumn = "0"
  vim.wo[w].winhighlight = "Normal:CoveTree,NormalNC:CoveTree,CursorLine:CoveTreeCursor,EndOfBuffer:CoveTree,WinBar:CoveTreeTitle,WinBarNC:CoveTreeTitle"
  vim.wo[w].winbar = winbar()
end

function M.is_open() return M.win and vim.api.nvim_win_is_valid(M.win) end

function M.open(root)
  M.root = (root or M.root or vim.fn.getcwd()):gsub("(.)/$", "%1")   -- «/» остаётся «/»
  if not (M.buf and vim.api.nvim_buf_is_valid(M.buf)) then setup_buf() end
  if not M.is_open() then
    local prev = vim.api.nvim_get_current_win()
    vim.cmd("topleft vertical " .. M.width .. "split")
    M.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.win, M.buf)
    setup_win()
    if vim.api.nvim_win_is_valid(prev) then vim.api.nvim_set_current_win(prev) end
  else
    vim.wo[M.win].winbar = winbar()
  end
  M.reveal()
  M.render()
end

function M.close() if M.is_open() then vim.api.nvim_win_close(M.win, true) end; M.win = nil end
function M.toggle() if M.is_open() then M.close() else M.open() end end

function M.current() return M.entries[vim.api.nvim_win_get_cursor(M.win or 0)[1]] end

-- раскрыть папки до текущего файла
function M.reveal()
  if not M.root then return end
  local f = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(require("cove.actions").main_win()))
  local prefix = M.root == "/" and "/" or M.root .. "/"
  if f == "" or f:sub(1, #prefix) ~= prefix then return end
  local d = vim.fn.fnamemodify(f, ":h")
  -- до корня; «/» — предел, дальше подниматься некуда (иначе вечный цикл)
  while #d > #M.root and d ~= "/" do M.expanded[d] = true; d = vim.fn.fnamemodify(d, ":h") end
end

function M.activate()
  local e = M.current()
  if not e then return end
  if e.dir then
    M.expanded[e.path] = not M.expanded[e.path] or nil
    M.render()
  else
    require("cove.actions").open(e.path)
  end
end

function M.collapse_all() M.expanded = {}; M.render() end
function M.toggle_hidden() M.hidden = not M.hidden; M.render() end

-- папка для новых файлов: выбранная папка или папка выбранного файла
local function target_dir(dir)
  if dir then return dir end
  local e = M.is_open() and vim.api.nvim_get_current_win() == M.win and M.current()
  if not e then return M.root or vim.fn.getcwd() end
  return e.dir and e.path or vim.fn.fnamemodify(e.path, ":h")
end

function M.new_file(dir)
  dir = target_dir(dir)
  vim.ui.input({ prompt = T("Новый файл в ") .. vim.fn.fnamemodify(dir, ":~") }, function(name)
    if not name or name == "" then return end
    local p = dir .. "/" .. name
    vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
    if not uv.fs_stat(p) then local f = io.open(p, "w"); if f then f:close() end end
    M.expanded[dir] = true
    require("cove.actions").open(p)
    M.refresh()
  end)
end

function M.new_dir(dir)
  dir = target_dir(dir)
  vim.ui.input({ prompt = T("Новая папка в ") .. vim.fn.fnamemodify(dir, ":~") }, function(name)
    if not name or name == "" then return end
    vim.fn.mkdir(dir .. "/" .. name, "p")
    M.expanded[dir] = true
    M.expanded[dir .. "/" .. name] = true
    M.refresh()
  end)
end

function M.rename()
  local e = M.current()
  if not e then return end
  vim.ui.input({ prompt = T("Переименовать"), default = e.name }, function(name)
    if not name or name == "" or name == e.name then return end
    local to = vim.fn.fnamemodify(e.path, ":h") .. "/" .. name
    local ok, err = uv.fs_rename(e.path, to)
    if not ok then return vim.notify(T("Не удалось: ") .. tostring(err), vim.log.levels.ERROR) end
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(b) == e.path then vim.api.nvim_buf_set_name(b, to); vim.api.nvim_buf_call(b, function() vim.cmd("silent! write!") end) end
    end
    M.refresh()
  end)
end

function M.delete()
  local e = M.current()
  if not e then return end
  if vim.fn.confirm(T("Удалить «") .. e.name .. T("» в корзину?"), T("&Удалить\n&Отмена"), 2) ~= 1 then return end
  local ok = vim.fn.executable("gio") == 1 and vim.system({ "gio", "trash", e.path }):wait().code == 0
  if not ok then ok = pcall(vim.fs.rm, e.path, { recursive = true }) end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local n = vim.api.nvim_buf_get_name(b)
    if n == e.path or n:sub(1, #e.path + 1) == e.path .. "/" then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
  end
  M.refresh()
end

function M.copy_path()
  local e = M.current()
  if e then vim.fn.setreg("+", e.path); vim.notify(T("Путь скопирован: ") .. vim.fn.fnamemodify(e.path, ":~")) end
end

function M.terminal_here() require("cove.ui.terminal").open(target_dir()) end
function M.grep_here() require("fzf-lua").live_grep({ cwd = target_dir() }) end

function M.setup()
  local g = vim.api.nvim_create_augroup("CoveTree", {})
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "BufModifiedSet", "FocusGained" }, {
    group = g,
    callback = function(ev)
      if not M.is_open() or vim.bo[ev.buf].filetype == "cove-tree" then return end
      if ev.event == "BufEnter" then M.reveal() end
      M.refresh()
    end,
  })
  vim.api.nvim_create_autocmd("DirChanged", { group = g, callback = function() if M.is_open() then M.open(vim.fn.getcwd()) end end })
  vim.api.nvim_create_autocmd("User", { group = g, pattern = "CoveTheme", callback = function() if M.is_open() then M.render() end end })
end

return M
