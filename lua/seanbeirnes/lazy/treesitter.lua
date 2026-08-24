local parsers = {
    "bash",
    "c",
    "c_sharp",
    "cpp",
    "css",
    "dockerfile",
    "go",
    "html",
    "java",
    "javascript",
    "jsdoc",
    "json",
    "lua",
    "markdown",
    "markdown_inline",
    "php",
    "python",
    "ruby",
    "rust",
    "sql",
    "templ",
    "toml",
    "typescript",
    "vim",
    "vimdoc",
    "xml",
    "yaml",
}

local configured_parsers = {}
for _, parser in ipairs(parsers) do
    configured_parsers[parser] = true
end

return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter").install(parsers)

        vim.api.nvim_create_autocmd("FileType", {
            callback = function(args)
                local language = vim.treesitter.language.get_lang(args.match) or args.match
                if not configured_parsers[language] then
                    return
                end

                local started = pcall(vim.treesitter.start, args.buf, language)
                if started then
                    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end

                if args.match == "markdown" then
                    vim.bo[args.buf].syntax = "markdown"
                end
            end,
        })
    end,
}
