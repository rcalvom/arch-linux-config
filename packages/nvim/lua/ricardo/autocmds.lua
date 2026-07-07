local augroup = vim.api.nvim_create_augroup("RicardoConfig", { clear = true })

vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  callback = require("ricardo.colors").apply,
})

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = augroup,
  callback = function()
    if vim.fn.mode() ~= "c" then
      vim.cmd("checktime")
    end
  end,
})

local function ensure_parent_dir(path)
  local dir = vim.fn.fnamemodify(path, ":p:h")

  if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  callback = function(event)
    ensure_parent_dir(event.match)
  end,
})

local function autosave()
  local buf = vim.api.nvim_get_current_buf()

  if not vim.bo[buf].modified then
    return
  end

  if not vim.bo[buf].modifiable then
    return
  end

  if vim.bo[buf].buftype ~= "" then
    return
  end

  if vim.api.nvim_buf_get_name(buf) == "" then
    return
  end

  ensure_parent_dir(vim.api.nvim_buf_get_name(buf))
  vim.cmd("silent write")
end

vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "FocusLost", "BufLeave" }, {
  group = augroup,
  callback = autosave,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = augroup,
  callback = function()
    if #vim.api.nvim_list_uis() == 0 then
      return
    end

    vim.schedule(function()
      if vim.fn.exists(":Neotree") == 0 then
        return
      end

      local current_win = vim.api.nvim_get_current_win()
      vim.cmd("silent! Neotree show reveal left")

      if vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
      end
    end)
  end,
})
