-- Статусная строка: ветка git, проблемы, позиция, отступы, язык. Сегменты кликаются.
local M = {}

_G.CoveStatusClick = function(i)
  if i == 1 then require("fzf-lua").diagnostics_document()
  elseif i == 2 then require("cove.actions").goto_line()
  elseif i == 3 then
    vim.ui.select({ "2", "4", "8", T("Табуляция") }, { prompt = T("Отступ › ") }, function(v)
      if not v then return end
      if v == T("Табуляция") then vim.bo.expandtab = false else vim.bo.expandtab = true; vim.bo.shiftwidth = tonumber(v); vim.bo.tabstop = tonumber(v) end
    end)
  elseif i == 4 then require("fzf-lua").filetypes()
  elseif i == 5 then require("cove.lsp").install_suggested()
  elseif i == 6 then require("fzf-lua").git_branches()
  elseif i == 7 then vim.cmd("Mason")
  end
end

local function diag()
  local e = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
  local w = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
  return string.format("%%1@v:lua.CoveStatusClick@%%#CoveStatusError# 󰅚 %d %%#CoveStatusWarn#󰀪 %d %%X", e, w)
end

function M.render()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype == "cove-tree" then
    local w = require("cove.actions").main_win()
    buf = vim.api.nvim_win_get_buf(w)
  end
  local s = {}
  s[#s + 1] = vim.g.cove_vim and ("%#CoveStatusAccent#  " .. vim.api.nvim_get_mode().mode:upper() .. "  ") or "%#CoveStatusAccent#  󰞍  "
  local head = vim.b[buf].gitsigns_head
  if head and head ~= "" then s[#s + 1] = "%6@v:lua.CoveStatusClick@%#CoveStatus# 󰘬 " .. head .. " %X" end
  s[#s + 1] = diag()
  local name = vim.api.nvim_buf_get_name(buf)
  local rel = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or T("Без имени")
  s[#s + 1] = "%=%#CoveStatusDim#" .. rel .. (vim.bo[buf].modified and " ●" or "") .. "%="
  local sug = require("cove.lsp").suggestion(vim.bo[buf].filetype)
  if sug then s[#s + 1] = T("%5@v:lua.CoveStatusClick@%#CoveStatusAction# 󰏗 Установить поддержку ") .. sug.label .. " %X" end
  local clients = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({ bufnr = buf }))
  if #clients > 0 then s[#s + 1] = "%7@v:lua.CoveStatusClick@%#CoveStatus# 󰒋 " .. table.concat(clients, ", ") .. " %X" end
  local cur = vim.api.nvim_win_get_cursor(0)
  s[#s + 1] = string.format(T("%%2@v:lua.CoveStatusClick@%%#CoveStatus#  Стр %d, стлб %d %%X"), cur[1], cur[2] + 1)
  s[#s + 1] = "%3@v:lua.CoveStatusClick@%#CoveStatus#  " .. (vim.bo[buf].expandtab and (T("Пробелы: ") .. vim.bo[buf].shiftwidth) or T("Табуляция")) .. " %X"
  s[#s + 1] = "%#CoveStatus#  " .. (vim.bo[buf].fileencoding ~= "" and vim.bo[buf].fileencoding:upper() or "UTF-8") .. " "
  local ft = vim.bo[buf].filetype
  s[#s + 1] = "%4@v:lua.CoveStatusClick@%#CoveStatus#  " .. (ft ~= "" and ft or T("текст")) .. "  %X"
  return table.concat(s)
end

function M.setup()
  vim.o.statusline = "%!v:lua.require'cove.ui.statusline'.render()"
end

return M
