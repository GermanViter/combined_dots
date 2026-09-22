local ok, variant = pcall(require, "config.theme_variant")
if not ok then
  variant = "main"
end

local is_catppuccin = variant == "catppuccin"
local is_black = variant == "black"
local is_gruvbox = variant == "gruvbox"

return {
  -- Catppuccin
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    enabled = is_catppuccin,
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true,
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  -- Black Metal (Gorgoroth)
  {
    "tahayvr/matteblack.nvim",
    lazy = false,
    name = "matteblack",
    enabled = is_black,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("matteblack") -- ✅
    end,
  },
  -- Gruvbox
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    name = "gruvbox",
    enabled = is_gruvbox,
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        contrast = "soft",
        transparent_mode = true,
      })
      vim.cmd.colorscheme("gruvbox")
    end,
  },
  -- Rosé Pine
  {
    "rose-pine/neovim",
    name = "rose-pine",
    enabled = not (is_catppuccin or is_black or is_gruvbox),
    priority = 1000,
    config = function()
      require("rose-pine").setup({
        variant = variant,
        dark_variant = "main",
        dim_inactive_windows = false,
        extend_background_behind_borders = true,
        transparent_background = true,
        styles = {
          transparency = true,
        },
      })
      vim.cmd("colorscheme rose-pine")
    end,
  },
}
