return {
    {
        "supermaven-inc/supermaven-nvim",
        config = function()
        require("supermaven-nvim").setup({})
        end,
        keys = {
            {
                "<leader>sm",
                "<cmd>SupermavenToggle<cr>",
                desc = "toggle supermaven-nvim",
            },
        },
    },
}
