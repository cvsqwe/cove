-- Стартовый экран: логотип, действия и последние файлы. Всё кликается мышью.
local A = require("cove.actions")
local M = { buf = nil, actions = {} }
local ns = vim.api.nvim_create_namespace("cove-dash")

local logo = {
  " ██████╗  ██████╗ ██╗   ██╗███████╗",
  "██╔════╝ ██╔═══██╗██║   ██║██╔════╝",
  "██║      ██║   ██║██║   ██║█████╗  ",
  "██║      ██║   ██║╚██╗ ██╔╝██╔══╝  ",
  "╚██████╗ ╚██████╔╝ ╚████╔╝ ███████╗",
  " ╚═════╝  ╚═════╝   ╚═══╝  ╚══════╝",
}

local items = {
  { "󰈔", T("Открыть файл…"), "Ctrl+P", function() require("fzf-lua").files() end },
  { "󰝰", T("Открыть папку…"), "", A.pick_folder },
  { "󰝒", T("Новый файл"), "Ctrl+N", A.new_file },
  { "󱎸", T("Найти в проекте"), "Ctrl+Shift+F", function() require("fzf-lua").live_grep() end },
  { "󰘳", T("Палитра команд"), "Ctrl+Shift+P", A.palette },
  { "󰒓", T("Настройки Cove Code"), "", function() A.open(vim.fn.stdpath("config") .. "/init.lua") end },
  { "󰈆", T("Выход"), "Ctrl+Q", A.quit },
}

local function recent()
  local out, seen = {}, {}
  for _, f in ipairs(vim.v.oldfiles) do
    if #out >= 8 then break end
    if not seen[f] and not f:match("^/tmp/") and not f:match("/%.git/") and not f:match("^cove://") and vim.uv.fs_stat(f) then
      seen[f] = true
      out[#out + 1] = f
    end
  end
  return out
end

local function projects()
  local out, seen = {}, {}
  for _, f in ipairs(vim.v.oldfiles) do
    if #out >= 4 then break end
    local root = vim.fs.root(f, { ".git" })
    if root and not seen[root] and vim.uv.fs_stat(root) then seen[root] = true; out[#out + 1] = root end
  end
  return out
end

function M.render()
  if not (M.buf and vim.api.nvim_buf_is_valid(M.buf)) then return end
  local win = vim.fn.bufwinid(M.buf)
  local width = win ~= -1 and vim.api.nvim_win_get_width(win) or vim.o.columns
  local height = win ~= -1 and vim.api.nvim_win_get_height(win) or vim.o.lines
  local lines, hls = {}, {}
  M.actions = {}
  local function center(s, w) return string.rep(" ", math.max(0, math.floor((width - (w or vim.fn.strdisplaywidth(s))) / 2))) end
  local function add(s, hl, act)
    lines[#lines + 1] = s
    if hl then hls[#hls + 1] = { #lines - 1, hl } end
    if act then M.actions[#lines] = act end
  end
  local block = 6 + 3 + #items + 3 + 10
  for _ = 1, math.max(1, math.floor((height - block) / 3)) do add("") end
  local lw = vim.fn.strdisplaywidth(logo[1])
  for _, l in ipairs(logo) do add(center(l, lw) .. l, { "CoveDashLogo" }) end
  add(center("C O D E") .. "C O D E", { "CoveDashDim" })
  add("")
  add("")
  local col_w = 46
  local pad = center("", col_w)
  local function row(ic, label, key, act)
    local left = ic .. "   " .. label
    local space = col_w - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(key)
    local s = pad .. left .. string.rep(" ", math.max(2, space)) .. key
    add(s, { "item", #pad, #ic, #pad + #ic + 3, #pad + #ic + 3 + #label }, act)
  end
  for _, it in ipairs(items) do row(it[1], it[2], it[3], it[4]) end
  local pr = projects()
  if #pr > 0 then
    add("")
    add(pad .. T("ПРОЕКТЫ"), { "CoveDashDim" })
    for _, p in ipairs(pr) do row("󰉋", vim.fn.fnamemodify(p, ":~"), "", function() A.open_folder(p) end) end
  end
  local rc = recent()
  if #rc > 0 then
    add("")
    add(pad .. T("ПОСЛЕДНИЕ ФАЙЛЫ"), { "CoveDashDim" })
    for _, f in ipairs(rc) do
      local ok, mi = pcall(require, "mini.icons")
      local ic = ok and mi.get("file", f) or "󰈔"
      local short = vim.fn.fnamemodify(f, ":~")
      if vim.fn.strdisplaywidth(short) > col_w - 6 then short = "…" .. short:sub(-(col_w - 7)) end
      row(ic, short, "", function() A.open(f) end)
    end
  end
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.bo[M.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(M.buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    local spec = h[2]
    if spec[1] == "item" then
      vim.api.nvim_buf_set_extmark(M.buf, ns, h[1], spec[2], { end_col = spec[3] + spec[2], hl_group = "CoveDashIcon" })
      vim.api.nvim_buf_set_extmark(M.buf, ns, h[1], spec[4], { end_col = spec[5], hl_group = "CoveDashItem" })
      vim.api.nvim_buf_set_extmark(M.buf, ns, h[1], spec[5], { end_col = #lines[h[1] + 1], hl_group = "CoveDashKey" })
    else
      vim.api.nvim_buf_add_highlight(M.buf, ns, spec[1], h[1], 0, -1)
    end
  end
end

local function activate()
  local act = M.actions[vim.api.nvim_win_get_cursor(0)[1]]
  if act then act() end
end

function M.show()
  if not (M.buf and vim.api.nvim_buf_is_valid(M.buf)) then
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.buf, "cove://start")
    vim.bo[M.buf].filetype = "cove-dash"
    vim.bo[M.buf].bufhidden = "hide"
    local o = { buffer = M.buf, silent = true, nowait = true }
    require("cove.ui.click").bind(M.buf, activate)
    vim.keymap.set("n", "<CR>", activate, o)
  end
  vim.api.nvim_set_current_win(A.main_win(true))
  vim.api.nvim_win_set_buf(0, M.buf)
  local w = vim.api.nvim_get_current_win()
  vim.wo[w].number = false
  vim.wo[w].signcolumn = "no"
  vim.wo[w].cursorline = true
  vim.wo[w].winhighlight = "CursorLine:CoveTreeCursor"
  M.render()
  -- курсор — на первый пункт, а не на пустую строку сверху
  local first = math.huge
  for l in pairs(M.actions) do first = math.min(first, l) end
  if first < math.huge then pcall(vim.api.nvim_win_set_cursor, w, { first, 0 }) end
end

function M.setup()
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      local argv = vim.fn.argv()
      if #argv == 0 then
        -- пустой буфер при старте не нужен — его место займёт стартовый экран
        local empty = vim.api.nvim_get_current_buf()
        M.show()
        if vim.api.nvim_buf_get_name(empty) == "" and not vim.bo[empty].modified then pcall(vim.api.nvim_buf_delete, empty, {}) end
      elseif #argv == 1 and vim.fn.isdirectory(argv[1]) == 1 then
        local dirbuf = vim.api.nvim_get_current_buf()
        A.open_folder(argv[1])
        M.show()
        pcall(vim.api.nvim_buf_delete, dirbuf, { force = true })
      elseif vim.fn.argc() > 0 then
        -- файл из аргумента: дерево его папки (или проекта) слева
        local f = vim.fn.fnamemodify(argv[1], ":p")
        require("cove.ui.tree").open(vim.fs.root(f, { ".git" }) or vim.fn.fnamemodify(f, ":h"))
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, { callback = function() if M.buf and vim.fn.bufwinid(M.buf) ~= -1 then M.render() end end })
  vim.api.nvim_create_autocmd("User", { pattern = "CoveTheme", callback = function() M.render() end })
end

return M
