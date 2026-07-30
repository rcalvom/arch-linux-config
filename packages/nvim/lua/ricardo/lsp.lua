local languages = require("ricardo.languages")
local lsp_capabilities = require("cmp_nvim_lsp").default_capabilities()
local augroup = vim.api.nvim_create_augroup("RicardoLsp", { clear = true })

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = augroup,
  callback = function(event)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, noremap = true, silent = true, desc = desc })
    end

    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gr", vim.lsp.buf.references, "Show references")
    map("n", "K", vim.lsp.buf.hover, "Show documentation")
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
    -- map("n", "[d", function() vim.diagnostic.jump({count = -1, float = true}), "Previous diagnostic")
    -- map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
    map("n", "<leader>e", vim.diagnostic.open_float, "Show diagnostic")
    map("n", "<leader>dl", vim.diagnostic.setloclist, "Diagnostic list")
  end,
})

vim.lsp.config("lua_ls", {
  capabilities = lsp_capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
      },
    },
  },
})

for _, server in ipairs(languages.lsp_servers) do
  vim.lsp.config(server, {
    capabilities = lsp_capabilities,
  })
end

vim.lsp.enable(vim.list_extend({ "lua_ls" }, vim.deepcopy(languages.lsp_servers)))
