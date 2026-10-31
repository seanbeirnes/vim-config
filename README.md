# My Neovim Configuration
Inspired by [ThePrimeagen's init.lua repo](https://github.com/ThePrimeagen/init.lua/tree/master)

## Requirements

- Neovim 0.12 or later
- `git`
- `tree-sitter-cli` 0.26.1 or later (see [Tree-sitter](#tree-sitter))
- [`ripgrep`](https://github.com/BurntSushi/ripgrep) for Telescope's grep
  pickers
- Node.js and `npm`, which Mason uses to install most language servers
- Go, which Mason uses to install `gopls`
- TypeScript 7 or later for the `tsc` language server. It ships with the
  native compiler; projects on older TypeScript get no TypeScript language
  server.

## Tree-sitter

This configuration uses the `main` branch of
[`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter), which
requires Neovim 0.12 or later and `tree-sitter-cli` 0.26.1 or later.

Run `:TSUpdate` after updating `nvim-treesitter` so the installed parsers stay
compatible with the plugin. Lazy also runs this automatically when it installs
or updates the plugin.

## Language servers

[Mason](https://github.com/mason-org/mason.nvim) installs these automatically
on startup:

| Language | Server |
| --- | --- |
| TypeScript / JavaScript | `tsc` |
| Biome (lint) | `biome` |
| HTML | `html` |
| CSS | `cssls` |
| Tailwind CSS | `tailwindcss` |
| Python | `pyright` (types), `ruff` (lint, format) |
| Go | `gopls` |
| Bash | `bashls`, with `shellcheck` for diagnostics |
| Dockerfile | `docker_language_server` |

## Formatting

`<leader>f` formats the current buffer with
[conform.nvim](https://github.com/stevearc/conform.nvim), using the project's
own formatter so the result matches the repo's config:

| File types | Formatter |
| --- | --- |
| JS, TS, JSX, TSX, JSON, CSS, SCSS, Markdown, YAML | Biome, else Prettier |
| HTML | Prettier, else Biome |
| Shell | `shfmt` |
| Lua | StyLua, automatically on save |
| Everything else | The language server |

Biome and Prettier only run when the project has a config file for them
(`biome.json`, `.prettierrc`, etc.), and use the project's installed version
when available. Otherwise formatting falls back to the language server.

StyLua also only runs in repos with a `stylua.toml` or `.stylua.toml`. This
repo's config pins 4-space indentation, and CI checks every push and PR with
`stylua --check`.

Run `:ConformInfo` to see which formatter applies to the current buffer.

## Keymaps

Leader is `<Space>`. Every keymap has a description; press `<leader>vk` to
search them with Telescope.
