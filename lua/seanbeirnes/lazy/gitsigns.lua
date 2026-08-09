return {
    "lewis6991/gitsigns.nvim",
    config = function()
        require("gitsigns").setup({
            signs = {
                add = { text = "+" },
                change = { text = "~" },
                delete = { text = "_" },
                topdelete = { text = "^" },
                changedelete = { text = "~" },
                untracked = { text = "?" },
            },
            signs_staged = {
                add = { text = "+" },
                change = { text = "~" },
                delete = { text = "_" },
                topdelete = { text = "^" },
                changedelete = { text = "~" },
                untracked = { text = "?" },
            },
            on_attach = function(bufnr)
                local gitsigns = require("gitsigns")

                local function map(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
                end

                map("n", "]c", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "]c", bang = true })
                    else
                        gitsigns.nav_hunk("next")
                    end
                end, "Next git hunk")

                map("n", "[c", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "[c", bang = true })
                    else
                        gitsigns.nav_hunk("prev")
                    end
                end, "Previous git hunk")

                map("n", "<leader>hs", gitsigns.stage_hunk, "Stage git hunk")
                map("n", "<leader>hr", gitsigns.reset_hunk, "Reset git hunk")
                map("v", "<leader>hs", function()
                    gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, "Stage selected git hunk")
                map("v", "<leader>hr", function()
                    gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
                end, "Reset selected git hunk")

                map("n", "<leader>hS", gitsigns.stage_buffer, "Stage git buffer")
                map("n", "<leader>hR", gitsigns.reset_buffer, "Reset git buffer")
                map("n", "<leader>hp", gitsigns.preview_hunk, "Preview git hunk")
                map("n", "<leader>hi", gitsigns.preview_hunk_inline, "Preview git hunk inline")
                map("n", "<leader>hb", function()
                    gitsigns.blame_line({ full = true })
                end, "Blame git line")
                map("n", "<leader>hB", gitsigns.toggle_current_line_blame, "Toggle git line blame")
                map("n", "<leader>hd", gitsigns.diffthis, "Diff git buffer")
                map("n", "<leader>hD", function()
                    gitsigns.diffthis("~")
                end, "Diff git buffer against previous commit")
                map("n", "<leader>hw", gitsigns.toggle_word_diff, "Toggle git word diff")
                map({ "o", "x" }, "ih", gitsigns.select_hunk, "Select git hunk")
            end,
        })
    end,
}
