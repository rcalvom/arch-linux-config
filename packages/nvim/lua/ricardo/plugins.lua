local colors = require("ricardo.colors").palette
local languages = require("ricardo.languages")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers",
          numbers = "none",
          close_command = "bdelete %d",
          right_mouse_command = "bdelete %d",
          left_mouse_command = "buffer %d",
          middle_mouse_command = nil,
          indicator = {
            style = "none",
          },
          buffer_close_icon = "x",
          modified_icon = "+",
          close_icon = "x",
          left_trunc_marker = "<",
          right_trunc_marker = ">",
          max_name_length = 24,
          max_prefix_length = 16,
          tab_size = 18,
          diagnostics = "nvim_lsp",
          diagnostics_update_in_insert = false,
          offsets = {
            {
              filetype = "neo-tree",
              text = "Files",
              text_align = "left",
              highlight = "NeoTreeRootName",
            },
          },
          show_buffer_icons = true,
          show_buffer_close_icons = false,
          show_close_icon = false,
          separator_style = "thin",
          always_show_bufferline = true,
        },
        highlights = {
          fill = { bg = colors.bg },
          background = { fg = colors.dim_fg, bg = colors.bg },
          buffer_visible = { fg = colors.fg, bg = colors.bg },
          buffer_selected = { fg = colors.bright_fg, bg = colors.selection, bold = true, italic = false },
          separator = { fg = colors.selection, bg = colors.bg },
          separator_visible = { fg = colors.selection, bg = colors.bg },
          separator_selected = { fg = colors.selection, bg = colors.selection },
          indicator_selected = { fg = colors.bright_fg, bg = colors.selection },
          modified = { fg = colors.bright_yellow, bg = colors.bg },
          modified_visible = { fg = colors.bright_yellow, bg = colors.bg },
          modified_selected = { fg = colors.bright_yellow, bg = colors.selection },
          close_button = { fg = colors.dim_fg, bg = colors.bg },
          close_button_visible = { fg = colors.dim_fg, bg = colors.bg },
          close_button_selected = { fg = colors.bright_fg, bg = colors.selection },
        },
      })
    end,
  },
  {
    "numToStr/Comment.nvim",
    opts = {},
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "+" },
        change = { text = "~" },
        delete = { text = "_" },
        topdelete = { text = "-" },
        changedelete = { text = "~" },
        untracked = { text = "+" },
      },
      signs_staged_enable = true,
      current_line_blame = false,
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
        end

        map("n", "]c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Next Git change")

        map("n", "[c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Previous Git change")

        map("n", "<leader>gp", gs.preview_hunk, "Preview change")
        map("n", "<leader>gs", gs.stage_hunk, "Stage change")
        map("n", "<leader>gr", gs.reset_hunk, "Reset change")
        map("v", "<leader>gs", function()
          gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Stage selection")
        map("v", "<leader>gr", function()
          gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, "Reset selection")
        map("n", "<leader>gS", gs.stage_buffer, "Stage file")
        map("n", "<leader>gR", gs.reset_buffer, "Reset file")
        map("n", "<leader>gb", gs.toggle_current_line_blame, "Toggle blame")
      end,
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      options = {
        icons_enabled = true,
        theme = {
          normal = {
            a = { fg = colors.bright_fg, bg = colors.dark_blue, gui = "bold" },
            b = { fg = colors.fg, bg = colors.selection },
            c = { fg = colors.fg, bg = colors.bg },
          },
          insert = {
            a = { fg = colors.selection, bg = colors.green, gui = "bold" },
            b = { fg = colors.fg, bg = colors.selection },
            c = { fg = colors.fg, bg = colors.bg },
          },
          visual = {
            a = { fg = colors.selection, bg = colors.bright_yellow, gui = "bold" },
            b = { fg = colors.fg, bg = colors.selection },
            c = { fg = colors.fg, bg = colors.bg },
          },
          replace = {
            a = { fg = colors.bright_fg, bg = colors.red, gui = "bold" },
            b = { fg = colors.fg, bg = colors.selection },
            c = { fg = colors.fg, bg = colors.bg },
          },
          command = {
            a = { fg = colors.bright_fg, bg = colors.magenta, gui = "bold" },
            b = { fg = colors.fg, bg = colors.selection },
            c = { fg = colors.fg, bg = colors.bg },
          },
          inactive = {
            a = { fg = colors.dim_fg, bg = colors.bg },
            b = { fg = colors.dim_fg, bg = colors.bg },
            c = { fg = colors.dim_fg, bg = colors.bg },
          },
        },
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "diagnostics", "encoding", "filetype" },
        lualine_y = {},
        lualine_z = { "location" },
      },
    },
  },
  {
    "williamboman/mason.nvim",
    opts = {},
  },
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    config = function()
      local treesitter = require("nvim-treesitter")

      treesitter.setup()

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("RicardoTreesitter", { clear = true }),
        pattern = languages.treesitter,
        callback = function()
          if pcall(vim.treesitter.start) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = vim.list_extend({ "lua_ls" }, vim.deepcopy(languages.lsp_servers)),
    },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp = require("cmp")

      cmp.setup({
        snippet = {
          expand = function(args)
            vim.snippet.expand(args.body)
          end,
        },
        completion = {
          completeopt = "menu,menuone,noinsert",
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<C-y>"] = cmp.mapping.confirm({ select = true }),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "path" },
        }, {
          { name = "buffer" },
        }),
      })
    end,
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      local autopairs = require("nvim-autopairs")

      autopairs.setup({
        check_ts = true,
        disable_filetype = { "TelescopePrompt" },
      })

      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")

      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")

      telescope.setup({
        defaults = {
          prompt_prefix = "> ",
          selection_caret = "> ",
          path_display = { "smart" },
          mappings = {
            i = {
              ["<Esc>"] = actions.close,
              ["<C-j>"] = actions.move_selection_next,
              ["<C-k>"] = actions.move_selection_previous,
              ["<C-y>"] = actions.select_default,
            },
            n = {
              ["q"] = actions.close,
            },
          },
        },
        pickers = {
          find_files = {
            hidden = true,
          },
          live_grep = {
            additional_args = function()
              return { "--hidden", "--glob", "!.git/" }
            end,
          },
        },
      })
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      close_if_last_window = true,
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = true,
      sort_case_insensitive = true,
      default_component_configs = {
        indent = {
          with_expanders = true,
          expander_collapsed = ">",
          expander_expanded = "v",
          expander_highlight = "NeoTreeIndentMarker",
        },
      },
      filesystem = {
        bind_to_cwd = true,
        follow_current_file = {
          enabled = true,
        },
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = true,
        },
        window = {
          mappings = {
            ["<C-b>"] = "close_window",
          },
        },
      },
      window = {
        position = "left",
        width = 32,
      },
    },
  },
})
