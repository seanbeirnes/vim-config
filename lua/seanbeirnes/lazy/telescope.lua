return {
    "nvim-telescope/telescope.nvim",

    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
    },

    config = function()
        require("telescope").setup({})

        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>pf", builtin.find_files, { desc = "Find files" })
        vim.keymap.set("n", "<C-p>", builtin.git_files, { desc = "Find git files" })
        vim.keymap.set("n", "<leader>gs", builtin.git_status, { desc = "Git status" })
        vim.keymap.set("n", "<leader>gp", function()
            require("seanbeirnes.review").pick()
        end, { desc = "PR review: changed files" })
        vim.keymap.set("n", "<leader>gd", builtin.lsp_definitions, { desc = "Go to definition" })
        vim.keymap.set("n", "<leader>gr", builtin.lsp_references, { desc = "List references" })
        vim.keymap.set("n", "<leader>gi", builtin.lsp_incoming_calls, { desc = "Incoming calls" })
        vim.keymap.set("n", "<leader>go", builtin.lsp_outgoing_calls, { desc = "Outgoing calls" })
        vim.keymap.set("n", "<leader>pws", function()
            local word = vim.fn.expand("<cword>")
            builtin.grep_string({ search = word })
        end, { desc = "Grep word under cursor" })
        vim.keymap.set("n", "<leader>pWs", function()
            local word = vim.fn.expand("<cWORD>")
            builtin.grep_string({ search = word })
        end, { desc = "Grep WORD under cursor" })
        vim.keymap.set("n", "<leader>ps", function()
            builtin.grep_string({ search = vim.fn.input("Grep > ") })
        end, { desc = "Grep for string" })
        vim.keymap.set("n", "<leader>vh", builtin.help_tags, { desc = "Search help" })
        vim.keymap.set("n", "<leader>vk", builtin.keymaps, { desc = "Search keymaps" })
    end,
}
