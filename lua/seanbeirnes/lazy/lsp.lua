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
		local cmp = require('cmp')
		local cmp_lsp = require("cmp_nvim_lsp")
		local capabilities = vim.tbl_deep_extend(
			"force",
			{},
			vim.lsp.protocol.make_client_capabilities(),
			cmp_lsp.default_capabilities())

		require("fidget").setup({})
		require("mason").setup()
		require("mason-lspconfig").setup({
			ensure_installed = {
				"bashls",
				"biome",
				"cssls",
				"gopls",
                "html",
				"jdtls",
				"pyright",
				"tsc",
                "tailwindcss"

			},
			handlers = {
				function(server_name) -- default handler (optional)
					require("lspconfig")[server_name].setup {
						capabilities = capabilities
					}
				end,
				bashls = function()
					local lspconfig = require("lspconfig")
					lspconfig.bashls.setup {
						capabilities = capabilities,
						settings = {
							bashIde = {
								globPattern = "*@(.sh|.inc|.bash|.command)"
							}
						}
					}
				end
			}
		})

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
				{ name = 'nvim_lsp' },
			}, {
					{ name = 'buffer' },
				})
		})
	end
}
