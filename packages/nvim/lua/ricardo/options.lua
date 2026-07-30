vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = false
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.termguicolors = true
opt.signcolumn = "auto"
opt.cursorline = true
opt.autoread = true
opt.confirm = true
opt.fillchars = { eob = " " }
opt.showtabline = 2
opt.laststatus = 3
opt.cmdheight = 0
opt.showmode = false
opt.showcmd = false
opt.ruler = false
opt.shortmess:append("I")

opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftround = true
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.splitright = true
opt.splitbelow = true

opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 400
