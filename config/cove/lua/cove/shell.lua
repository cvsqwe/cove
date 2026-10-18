-- Связь с шеллом Cove: состояние редактора в ~/.cache/cove/status.json — проект, файл, ветка,
-- несохранённое, ошибки/предупреждения. Шелл (services/CoveCode.qml) показывает это в панели,
-- когда окно Cove Code активно. Пишет тот экземпляр, у которого фокус.
local M = {}

M.path = vim.fn.expand("~/.cache/cove/status.json")

local function write()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype == "cove-tree" then
    local ok, w = pcall(function() return require("cove.actions").main_win() end)
    if ok and w and vim.api.nvim_win_is_valid(w) then buf = vim.api.nvim_win_get_buf(w) end
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local cwd = vim.fn.getcwd()
  local modified = 0
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.bo[b].modified then modified = modified + 1 end
  end
  local data = {
    pid = vim.fn.getpid(),
    project = vim.fn.fnamemodify(cwd, ":t"),
    cwd = cwd,
    file = name ~= "" and vim.fn.fnamemodify(name, ":t") or "",
    path = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "",
    branch = vim.b[buf].gitsigns_head or "",
    modified = modified,
    errors = #vim.diagnostic.get(nil, { severity = vim.diagnostic.severity.ERROR }),
    warnings = #vim.diagnostic.get(nil, { severity = vim.diagnostic.severity.WARN }),
    time = os.time(),
  }
  vim.fn.mkdir(vim.fn.fnamemodify(M.path, ":h"), "p")
  local f = io.open(M.path .. ".tmp", "w")
  if not f then return end
  f:write(vim.json.encode(data))
  f:close()
  os.rename(M.path .. ".tmp", M.path)
end

-- не чаще раза в 300 мс: диагностика и BufModifiedSet сыплются пачками
local timer = vim.uv.new_timer()
local function schedule()
  timer:stop()
  timer:start(300, 0, vim.schedule_wrap(write))
end

function M.setup()
  local g = vim.api.nvim_create_augroup("CoveShell", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "BufModifiedSet", "FocusGained", "DirChanged", "DiagnosticChanged", "VimEnter" }, {
    group = g, callback = schedule,
  })
  -- gitsigns узнаёт ветку чуть позже открытия буфера
  vim.api.nvim_create_autocmd("User", { group = g, pattern = "GitSignsUpdate", callback = schedule })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = g,
    callback = function()
      -- уходим — убираем свой статус, если он последний записанный
      local f = io.open(M.path, "r")
      if not f then return end
      local ok, d = pcall(vim.json.decode, f:read("*a"))
      f:close()
      if ok and d and d.pid == vim.fn.getpid() then os.remove(M.path) end
    end,
  })
end

return M
