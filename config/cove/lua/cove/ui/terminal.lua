-- Панель терминала снизу: Ctrl+` — показать/скрыть, F5 — запустить текущий файл.
local M = { buf = nil, win = nil, height = 12 }

local function shell() return vim.fn.executable("fish") == 1 and "fish" or vim.o.shell end

_G.CoveTermBtn = function(i)
  if i == 1 then M.new() elseif i == 2 then M.toggle() end
end

local function style(w)
  vim.wo[w].number = false
  vim.wo[w].relativenumber = false
  vim.wo[w].signcolumn = "no"
  vim.wo[w].cursorline = false
  vim.wo[w].winfixheight = true
  vim.wo[w].winhighlight = "Normal:CoveTree,NormalNC:CoveTree,WinBar:CoveTreeTitle,WinBarNC:CoveTreeTitle"
  vim.wo[w].winbar = T("%#CoveTreeTitle#  󰆍 ТЕРМИНАЛ%=%#CoveTreeDim#%1@v:lua.CoveTermBtn@ 󰐕 %X%2@v:lua.CoveTermBtn@ 󰅖 %X ")
end

local function spawn(cwd)
  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.win, M.buf)
  vim.fn.jobstart(shell(), { term = true, cwd = cwd or vim.fn.getcwd() })
  vim.bo[M.buf].buflisted = false
end

function M.is_open() return M.win and vim.api.nvim_win_is_valid(M.win) end

function M.open(cwd)
  if not M.is_open() then
    vim.cmd("botright " .. M.height .. "split")
    M.win = vim.api.nvim_get_current_win()
    style(M.win)
    if M.buf and vim.api.nvim_buf_is_valid(M.buf) and not cwd then vim.api.nvim_win_set_buf(M.win, M.buf) else spawn(cwd) end
  else
    vim.api.nvim_set_current_win(M.win)
    if cwd then spawn(cwd) end
  end
  vim.cmd.startinsert()
end

function M.toggle()
  if M.is_open() then
    M.height = vim.api.nvim_win_get_height(M.win)
    vim.api.nvim_win_close(M.win, true)
    M.win = nil
  else
    M.open()
  end
end

function M.new() if not M.is_open() then M.open() end; vim.api.nvim_set_current_win(M.win); spawn(); vim.cmd.startinsert() end

-- запустить текущий файл подходящей командой
local runners = {
  python = "python3 %s", lua = "lua %s", sh = "bash %s", bash = "bash %s", fish = "fish %s", zsh = "zsh %s",
  javascript = "node %s", typescript = "npx tsx %s", go = "go run %s", rust = "cargo run",
  c = "gcc %s -o /tmp/cove-run && /tmp/cove-run", cpp = "g++ %s -o /tmp/cove-run && /tmp/cove-run",
  ruby = "ruby %s", php = "php %s", java = "java %s",
}

function M.run_file()
  local A = require("cove.actions")
  local buf = vim.api.nvim_win_get_buf(A.main_win())
  local file = vim.api.nvim_buf_get_name(buf)
  local cmd = runners[vim.bo[buf].filetype]
  if file == "" or not cmd then return vim.notify(T("Не знаю, как запустить этот файл"), vim.log.levels.WARN) end
  vim.api.nvim_buf_call(buf, function() vim.cmd("silent! write") end)
  M.open()
  local chan = vim.bo[M.buf].channel
  vim.fn.chansend(chan, cmd:format(vim.fn.shellescape(file)) .. "\n")
end

function M.setup()
  vim.keymap.set({ "n", "i", "v", "t" }, "<F5>", M.run_file, { desc = T("Запустить файл") })
  -- клик по терминалу — сразу ввод
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    callback = function() if vim.bo.buftype == "terminal" then vim.schedule(function() vim.cmd.startinsert() end) end end,
  })
end

return M
