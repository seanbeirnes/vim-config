-- Format with the project's own formatter (Biome or Prettier) so files match
-- the repo's config. Falls back to LSP formatting when neither is configured.
local web = { "biome", "prettier", stop_after_first = true }
-- Biome's HTML formatter is opt-in, so prefer Prettier when a repo has both
local html = { "prettier", "biome", stop_after_first = true }

return {
    "stevearc/conform.nvim",
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
        },
        formatters = {
            -- only run when the project actually has a config for them
            biome = { require_cwd = true },
            prettier = { require_cwd = true },
        },
    },
}
