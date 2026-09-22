return {
    'nvim-telescope/telescope.nvim', version = '*',
    dependencies = {
        'nvim-lua/plenary.nvim',
        -- optional but recommended
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    keys = {
        { '<leader><leader>', '<cmd>Telescope find_files<cr>', desc = 'Telescope find files' },
        { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Telescope live grep' },
        { '<leader>fb', '<cmd>Telescope buffers<cr>', desc = 'Telescope buffers' },
        { '<leader>fh', '<cmd>Telescope help_tags<cr>', desc = 'Telescope help tags' },
    },
    config = function()
        require('telescope').setup{
            defaults = {
                mappings = {
                    i = {
                        ["<C-h>"] = "which_key"
                    }
                }
            },
        }
    end
}
