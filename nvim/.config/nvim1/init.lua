require("config.lazy")
require("config.options")
require("config.keymaps")

-- Force .js files to be treated as javascriptreact for better highlighting
vim.filetype.add({
  extension = {
    js = "javascriptreact",
    jsx = "javascriptreact",
    ts = "typescriptreact",
    tsx = "typescriptreact",
  },
})

vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({
      higroup = "IncSearch",  -- Highlight group to use
      timeout = 150,          -- Duration in milliseconds
      on_visual = true,       -- Highlight when yanking visual selection
      on_macro = false,       -- Do not highlight when executing macros
    })
  end,
})   
