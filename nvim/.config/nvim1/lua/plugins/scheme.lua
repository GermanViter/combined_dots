return {
    "catppuccin/nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true,
        integrations = {
          treesitter = true,
          cmp = true,
          telescope = true,
          mason = true,
          harpoon = true,
        }
      })
      vim.cmd.colorscheme("catppuccin")
    end
}
