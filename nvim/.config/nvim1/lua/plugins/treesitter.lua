return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter-textobjects",
  },
  config = function()
    -- Enable native treesitter highlighting
    vim.api.nvim_create_autocmd({ "FileType" }, {
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf()
        local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
        if lang then
          pcall(vim.treesitter.start, bufnr, lang)
        end
      end,
    })
  end,
}
