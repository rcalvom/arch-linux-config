local keymap = vim.keymap.set
local opts = { noremap = true, silent = true }

local function goto_line_column()
  vim.ui.input({ prompt = "Go to location > " }, function(input)
    if not input or input == "" then
      return
    end

    local line_text, column_text = input:match("^%s*(%d+)%s*:?%s*(%d*)%s*$")
    local line = tonumber(line_text)

    if not line then
      vim.notify("Use line or line:column format", vim.log.levels.WARN)
      return
    end

    local last_line = vim.api.nvim_buf_line_count(0)
    line = math.max(1, math.min(line, last_line))

    local current_line = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ""
    local column = tonumber(column_text)

    if column then
      column = math.max(1, math.min(column, #current_line + 1))
    else
      column = 1
    end

    vim.api.nvim_win_set_cursor(0, { line, column - 1 })
  end)
end

local function telescope_builtin(name)
  return function()
    require("telescope.builtin")[name]()
  end
end

local function search_current_buffer()
  require("telescope.builtin").current_buffer_fuzzy_find()
end

local function save_file()
  local buf = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(buf)

  if filename ~= "" then
    vim.cmd("write")
    return
  end

  vim.ui.input({ prompt = "Save as > ", completion = "file" }, function(input)
    if not input or input == "" then
      return
    end

    vim.cmd("write " .. vim.fn.fnameescape(vim.fn.expand(input)))
  end)
end

keymap("n", "<leader>w", "<cmd>write<cr>", opts)
keymap("n", "<leader>q", "<cmd>confirm quit<cr>", opts)
keymap("n", "<leader>Q", "<cmd>confirm quitall<cr>", opts)
keymap("n", "<leader>z", "<cmd>set wrap!<cr>", opts)
keymap({ "n", "i" }, "<C-s>", save_file, opts)
keymap("n", "<C-q>", "<cmd>confirm quit<cr>", opts)
keymap("n", "<C-n>", "<cmd>enew<cr>", opts)
keymap("n", "<C-t>", "<cmd>set wrap!<cr>", opts)
keymap("n", "<C-p>", telescope_builtin("find_files"), opts)
keymap({ "n", "i" }, "<C-f>", search_current_buffer, opts)
keymap({ "n", "i" }, "<C-S-f>", telescope_builtin("live_grep"), opts)
keymap({ "n", "i" }, "\27[70;6u", telescope_builtin("live_grep"), opts)
keymap("n", "<C-g>", goto_line_column, opts)
keymap("n", "<C-b>", "<cmd>Neotree toggle reveal left<cr>", opts)
keymap("n", "]b", "<cmd>BufferLineCycleNext<cr>", opts)
keymap("n", "[b", "<cmd>BufferLineCyclePrev<cr>", opts)
keymap("n", "<C-Tab>", "<cmd>BufferLineCycleNext<cr>", opts)
keymap("n", "<C-S-Tab>", "<cmd>BufferLineCyclePrev<cr>", opts)
keymap("n", "<leader>bd", "<cmd>bdelete<cr>", opts)
keymap("n", "<leader>bp", "<cmd>BufferLinePick<cr>", opts)
keymap("n", "<CR>", "i", opts)
keymap("i", "jk", "<Esc>", opts)
keymap("i", "jj", "<Esc>", opts)

keymap("n", "<Esc>", "<cmd>nohlsearch<cr>", opts)

keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)
