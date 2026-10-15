-- Верхняя строка: логотип, меню «Файл / Правка / …», вкладки открытых файлов. Всё кликается.
local M = {}

local function icon(buf)
  local ok, mi = pcall(require, "mini.icons")
  if not ok then return "󰈔", "CoveTab" end
  local name = vim.api.nvim_buf_get_name(buf)
  local i, hl = mi.get("file", name ~= "" and name or "untitled")
  return i, hl
end

function M.bufs()
  return vim.tbl_filter(function(b) return vim.bo[b].buflisted and vim.api.nvim_buf_is_loaded(b) end, vim.api.nvim_list_bufs())
end

function M.go(i) local b = M.bufs()[i]; if b then vim.api.nvim_set_current_win(require("cove.actions").main_win(true)); vim.cmd.buffer(b) end end

_G.CoveLogoClick = function() require("cove.ui.dashboard").show() end
_G.CoveMenuClick = function(i) require("cove.ui.menus").open(i) end
_G.CoveTabClick = function(b, _, button)
  if button == "m" then return require("cove.actions").close_buffer(b) end
  vim.api.nvim_set_current_win(require("cove.actions").main_win(true))
  vim.cmd.buffer(b)
end
_G.CoveTabClose = function(b) require("cove.actions").close_buffer(b) end
_G.CoveToolClick = function(i)
  if i == 1 then require("cove.ui.tree").toggle()
  elseif i == 2 then require("cove.ui.terminal").toggle()
  elseif i == 3 then require("cove.actions").palette() end
end

local function name_of(b)
  local n = vim.api.nvim_buf_get_name(b)
  if n == "" then return T("Без имени") end
  return vim.fn.fnamemodify(n, ":t")
end

function M.render()
  local s = { "%#CoveBarLogo#%@v:lua.CoveLogoClick@  󰞍 Cove %X" }
  for i, m in ipairs(require("cove.ui.menus").top) do
    s[#s + 1] = string.format("%%#CoveBarMenu#%%%d@v:lua.CoveMenuClick@ %s %%X", i, m[1])
  end
  s[#s + 1] = "%#CoveBar#  "
  local cur = vim.api.nvim_get_current_buf()
  if vim.bo[cur].buftype ~= "" then cur = vim.api.nvim_win_get_buf(require("cove.actions").main_win()) end
  for _, b in ipairs(M.bufs()) do
    local active = b == cur
    local ic, ichl = icon(b)
    local mod = vim.bo[b].modified
    local base = active and "CoveTabActive" or "CoveTab"
    s[#s + 1] = string.format("%%%d@v:lua.CoveTabClick@%%#%s#%s %%#%s#%s %%#%s#%s %%X",
      b, active and "CoveTabAccent" or "CoveTab", active and "▎" or " ",
      active and ichl or "CoveTab", ic, base, name_of(b))
    s[#s + 1] = string.format("%%%d@v:lua.CoveTabClose@%%#%s#%s %%X",
      b, mod and (active and "CoveTabActiveModified" or "CoveTabModified") or (active and "CoveTabActiveClose" or "CoveTabClose"),
      mod and "●" or "󰅖")
  end
  s[#s + 1] = "%#CoveBar#%="
  s[#s + 1] = "%1@v:lua.CoveToolClick@ 󰙅 %X%2@v:lua.CoveToolClick@ 󰆍 %X%3@v:lua.CoveToolClick@ 󰘳  %X"
  return table.concat(s)
end

function M.setup()
  vim.o.tabline = "%!v:lua.require'cove.ui.tabline'.render()"
  vim.api.nvim_create_autocmd({ "BufModifiedSet", "BufAdd", "BufDelete", "BufEnter" }, {
    callback = function() vim.schedule(function() vim.cmd.redrawtabline() end) end,
  })
end

return M
