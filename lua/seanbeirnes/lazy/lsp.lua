return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/nvim-cmp",
        "j-hui/fidget.nvim",
    },

    config = function()
        local cmp = require("cmp")

        -- applies to every server; per-server overrides go in
        -- vim.lsp.config("<server>", { ... })
        vim.lsp.config("*", {
            capabilities = require("cmp_nvim_lsp").default_capabilities(),
        })

        require("fidget").setup({})
        require("mason").setup()
        -- installs these servers and enables every server Mason has installed
        require("mason-lspconfig").setup({
            ensure_installed = {
                "bashls",
                "biome",
                "cssls",
                "docker_language_server",
                "gopls",
                "html",
                "pyright",
                "ruff",
                "tsc",
                "tailwindcss",
            },
        })

        -- non-LSP tools: shellcheck powers bashls diagnostics, shfmt formats shell,
        -- stylua formats Lua
        local registry = require("mason-registry")
        registry.refresh(function()
            for _, name in ipairs({ "shellcheck", "shfmt", "stylua" }) do
                local ok, pkg = pcall(registry.get_package, name)
                if ok and not pkg:is_installed() then
                    pkg:install()
                end
            end
        end)

        cmp.setup({
            snippet = {
                expand = function(args)
                    vim.snippet.expand(args.body)
                end,
            },
            -- preset keys: <C-n>/<C-p> to select, <C-y> to accept, <C-e> to close
            mapping = cmp.mapping.preset.insert({
                ["<C-Space>"] = cmp.mapping.complete(),
            }),
            sources = cmp.config.sources({
                { name = "nvim_lsp" },
            }, {
                { name = "buffer" },
            }),
        })
    end,
}
