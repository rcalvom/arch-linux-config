local M = {}

M.palette = {
  bg = "none",
  fg = "#d6d6d6",
  bright_fg = "#f1f1f1",
  dim_fg = "#818181",
  cursorline = "#212121",
  selection = "#2c2c2c",
  dark_blue = "#005f87",
  accent = "#20bbfc",
  blue = "#008ec4",
  cyan = "#20a5ba",
  green = "#10a778",
  bright_green = "#5fd7af",
  yellow = "#a89c14",
  bright_yellow = "#f3e430",
  red = "#c30771",
  bright_red = "#fb007a",
  magenta = "#6855de",
}

function M.apply()
  local colors = M.palette
  local hl = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  local transparent_groups = {
    "Normal",
    "NormalNC",
    "SignColumn",
    "EndOfBuffer",
    "LineNr",
    "CursorLineNr",
    "StatusLine",
    "StatusLineNC",
  }

  for _, group in ipairs(transparent_groups) do
    hl(group, { bg = colors.bg })
  end

  hl("Normal", { fg = colors.fg, bg = colors.bg })
  hl("Comment", { fg = colors.dim_fg, italic = true })
  hl("Constant", { fg = colors.cyan })
  hl("String", { fg = colors.bright_green })
  hl("Character", { fg = colors.bright_green })
  hl("Number", { fg = colors.magenta })
  hl("Boolean", { fg = colors.magenta })
  hl("Identifier", { fg = colors.fg })
  hl("Function", { fg = colors.accent })
  hl("Statement", { fg = colors.blue })
  hl("Keyword", { fg = colors.blue })
  hl("Conditional", { fg = colors.blue })
  hl("Repeat", { fg = colors.blue })
  hl("Operator", { fg = colors.bright_fg })
  hl("PreProc", { fg = colors.cyan })
  hl("Type", { fg = colors.bright_yellow })
  hl("Special", { fg = colors.accent })
  hl("Error", { fg = colors.bright_red })
  hl("Todo", { fg = colors.bright_yellow, bold = true })

  hl("LineNr", { fg = colors.dim_fg, bg = colors.bg })
  hl("CursorLine", { bg = colors.cursorline })
  hl("CursorLineNr", { fg = colors.bright_fg, bg = colors.cursorline, bold = true })
  hl("Visual", { bg = colors.selection })
  hl("Search", { fg = colors.selection, bg = colors.bright_yellow })
  hl("IncSearch", { fg = colors.selection, bg = colors.accent })
  hl("Pmenu", { fg = colors.fg, bg = colors.selection })
  hl("PmenuSel", { fg = colors.selection, bg = colors.accent })
  hl("PmenuSbar", { bg = colors.selection })
  hl("PmenuThumb", { bg = colors.dim_fg })

  hl("DiagnosticError", { fg = colors.bright_red })
  hl("DiagnosticWarn", { fg = colors.bright_yellow })
  hl("DiagnosticInfo", { fg = colors.accent })
  hl("DiagnosticHint", { fg = colors.cyan })

  hl("GitSignsAdd", { fg = colors.green, bg = colors.bg })
  hl("GitSignsChange", { fg = colors.accent, bg = colors.bg })
  hl("GitSignsDelete", { fg = colors.bright_red, bg = colors.bg })

  hl("TelescopeNormal", { fg = colors.fg, bg = colors.bg })
  hl("TelescopeBorder", { fg = colors.dim_fg, bg = colors.bg })
  hl("TelescopePromptBorder", { fg = colors.blue, bg = colors.bg })
  hl("TelescopePromptTitle", { fg = colors.bright_fg, bg = colors.dark_blue, bold = true })
  hl("TelescopeSelection", { fg = colors.bright_fg, bg = colors.dark_blue })
  hl("TelescopeMatching", { fg = colors.blue, bold = true })

  hl("NeoTreeNormal", { fg = colors.fg, bg = colors.bg })
  hl("NeoTreeNormalNC", { fg = colors.fg, bg = colors.bg })
  hl("NeoTreeEndOfBuffer", { fg = colors.bg, bg = colors.bg })
  hl("NeoTreeWinSeparator", { fg = colors.dark_blue, bg = colors.bg })
  hl("NeoTreeRootName", { fg = colors.bright_fg, bold = true })
  hl("NeoTreeDirectoryName", { fg = colors.fg })
  hl("NeoTreeDirectoryIcon", { fg = colors.blue })
  hl("NeoTreeFileName", { fg = colors.fg })
  hl("NeoTreeFileNameOpened", { fg = colors.bright_fg, bold = true })
  hl("NeoTreeIndentMarker", { fg = colors.dim_fg })
  hl("NeoTreeGitAdded", { fg = colors.green })
  hl("NeoTreeGitModified", { fg = colors.accent })
  hl("NeoTreeGitDeleted", { fg = colors.bright_red })

  hl("BufferLineFill", { bg = colors.bg })
  hl("BufferLineBackground", { fg = colors.dim_fg, bg = colors.bg })
  hl("BufferLineBufferSelected", { fg = colors.bright_fg, bg = colors.selection, bold = true })
  hl("BufferLineBufferVisible", { fg = colors.fg, bg = colors.bg })
  hl("BufferLineSeparator", { fg = colors.selection, bg = colors.bg })
  hl("BufferLineSeparatorSelected", { fg = colors.selection, bg = colors.selection })
  hl("BufferLineIndicatorSelected", { fg = colors.bright_fg, bg = colors.selection })
  hl("BufferLineModified", { fg = colors.bright_yellow, bg = colors.bg })
  hl("BufferLineModifiedSelected", { fg = colors.bright_yellow, bg = colors.selection })

  hl("@variable", { fg = colors.fg })
  hl("@variable.builtin", { fg = colors.cyan })
  hl("@variable.parameter", { fg = colors.bright_fg })
  hl("@variable.member", { fg = colors.cyan })
  hl("@constant", { fg = colors.magenta })
  hl("@constant.builtin", { fg = colors.magenta })
  hl("@module", { fg = colors.cyan })
  hl("@label", { fg = colors.bright_yellow })
  hl("@string", { fg = colors.bright_green })
  hl("@string.escape", { fg = colors.bright_yellow })
  hl("@number", { fg = colors.magenta })
  hl("@boolean", { fg = colors.magenta })
  hl("@function", { fg = colors.accent })
  hl("@function.call", { fg = colors.accent })
  hl("@function.builtin", { fg = colors.cyan })
  hl("@function.method", { fg = colors.accent })
  hl("@function.method.call", { fg = colors.accent })
  hl("@constructor", { fg = colors.bright_yellow })
  hl("@keyword", { fg = colors.blue })
  hl("@keyword.function", { fg = colors.blue })
  hl("@keyword.import", { fg = colors.cyan })
  hl("@keyword.operator", { fg = colors.blue })
  hl("@operator", { fg = colors.bright_fg })
  hl("@type", { fg = colors.bright_yellow })
  hl("@type.builtin", { fg = colors.bright_yellow })
  hl("@attribute", { fg = colors.bright_yellow })
  hl("@property", { fg = colors.cyan })
  hl("@punctuation", { fg = colors.dim_fg })
  hl("@punctuation.bracket", { fg = colors.dim_fg })
  hl("@punctuation.delimiter", { fg = colors.dim_fg })
  hl("@comment", { fg = colors.dim_fg, italic = true })
  hl("@comment.todo", { fg = colors.bright_yellow, bold = true })
  hl("@comment.error", { fg = colors.bright_red, bold = true })
  hl("@comment.warning", { fg = colors.bright_yellow, bold = true })
end

return M
