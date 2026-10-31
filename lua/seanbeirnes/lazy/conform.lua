-- Format with the project's own formatter (Biome or Prettier) so files match
-- the repo's config. Falls back to LSP formatting when neither is configured.
local web = { "biome", "prettier", stop_after_first = true }
-- Biome's HTML formatter is opt-in, so prefer Prettier when a repo has both
local html = { "prettier", "biome", stop_after_first = true }

return {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
        {
            "<leader>f",
            function()
                require("conform").format({ async = true, lsp_format = "fallback" })
            end,
            desc = "Format buffer",
        },
    },
    opts = {
        -- format Lua on save (only in repos with a stylua config); everything
        -- else formats on demand with <leader>f
        format_on_save = function(bufnr)
            if vim.bo[bufnr].filetype ~= "lua" then
                return
            end
            -- skip quietly when the repo has no stylua config
            if not require("conform").get_formatter_info("stylua", bufnr).available then
                return
            end
            return { timeout_ms = 1000, lsp_format = "never" }
        end,
        formatters_by_ft = {
            javascript = web,
            javascriptreact = web,
            typescript = web,
            typescriptreact = web,
            json = web,
            jsonc = web,
            css = web,
            scss = web,
            markdown = web,
            yaml = web,
            html = html,
            sh = { "shfmt" },
            bash = { "shfmt" },
            lua = { "stylua" },
        },
        formatters = {
            -- only run when the project actually has a config for them
            biome = { require_cwd = true },
            prettier = { require_cwd = true },
            stylua = { require_cwd = true },
        },
    },
}
