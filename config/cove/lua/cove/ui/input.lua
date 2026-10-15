-- Свой vim.ui.input: окошко по центру с заголовком (вместо строки ввода внизу).
local M = {}

function M.input(opts, on_confirm)
  opts = opts or {}
  -- хвостовые «:» и «›» срезаем по-строковому: в классе символов Lua многобайтный «›»
  -- распадается на байты и откусывает конец русских букв
  local title = (opts.prompt or T("Ввод")):gsub("%s*›%s*$", ""):gsub("%s*:%s*$", "")
  local default = opts.default or ""
  local width = math.max(44, vim.fn.strdisplaywidth(default) + 8, vim.fn.strdisplaywidth(title) + 8)
  width = math.min(width, vim.o.columns - 6)
  local prev = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.b[buf].completion = false
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded",
    row = math.floor(vim.o.lines * 0.25), col = math.floor((vim.o.columns - width) / 2),
    width = width, height = 1, title = " " .. title .. " ", title_pos = "center",
  })
  vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })
  vim.cmd("startinsert!")
  local done = false
  local function finish(val)
    if done then return end
    done = true
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    if vim.api.nvim_win_is_valid(prev) then vim.api.nvim_set_current_win(prev) end
    vim.schedule(function() on_confirm(val) end)
  end
  local o = { buffer = buf, nowait = true }
  vim.keymap.set({ "i", "n" }, "<CR>", function() finish(vim.api.nvim_get_current_line()) end, o)
  vim.keymap.set({ "i", "n" }, "<Esc>", function() finish(nil) end, o)
  vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = function() finish(nil) end })
end

vim.ui.input = M.input
return M
