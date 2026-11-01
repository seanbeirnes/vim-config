-- PR review mode: diff every buffer against the merge base with the default
-- branch (same comparison as GitHub's "Files changed"), with line highlights
-- and inline deleted lines, plus a Telescope picker of the PR's changed files.
local M = {}

local state = { enabled = false, base = nil, branch = nil }

-- inline deleted lines; toggle_deleted is deprecated in gitsigns, so skip it
-- quietly if a future version removes it
local function set_deleted(gitsigns, value)
    if type(gitsigns.toggle_deleted) == "function" then
        pcall(gitsigns.toggle_deleted, value)
    end
end

local function git(args)
    local result = vim.system(vim.list_extend({ "git" }, args), { text = true }):wait()
    if result.code ~= 0 then
        return nil
    end
    return vim.trim(result.stdout)
end

-- origin/HEAD (e.g. origin/main), falling back to common default branch names
local function default_branch()
    local head = git({ "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })
    if head then
        return head
    end
    for _, name in ipairs({ "origin/main", "origin/master", "main", "master" }) do
        if git({ "rev-parse", "--verify", "--quiet", name }) then
            return name
        end
    end
end

local function merge_base()
    local branch = default_branch()
    if not branch then
        return nil, nil, "no default branch found"
    end
    local base = git({ "merge-base", "HEAD", branch })
    if not base then
        return nil, nil, "no merge base with " .. branch
    end
    return base, branch
end

function M.enable()
    local base, branch, err = merge_base()
    if not base then
        vim.notify("Review mode: " .. err, vim.log.levels.WARN)
        return false
    end
    local gitsigns = require("gitsigns")
    gitsigns.change_base(base, true)
    gitsigns.toggle_linehl(true)
    set_deleted(gitsigns, true)
    state = { enabled = true, base = base, branch = branch }
    vim.notify(("Review mode on: diffing against %s (%s)"):format(branch, base:sub(1, 7)))
    return true
end

function M.disable()
    local gitsigns = require("gitsigns")
    gitsigns.reset_base(true)
    gitsigns.toggle_linehl(false)
    set_deleted(gitsigns, false)
    state = { enabled = false }
    vim.notify("Review mode off")
end

function M.toggle()
    if state.enabled then
        M.disable()
    else
        M.enable()
    end
end

-- `git diff` of one file against the merge base with the whole file as
-- context; returns the diff lines (headers stripped) and the first changed line
-- in the new file
local function full_diff(base, path, old_path)
    local args = { "diff", "--no-color", "-M", "--unified=1000000", base, "--" }
    if old_path then
        table.insert(args, old_path)
    end
    table.insert(args, path)
    local out = git(args) or ""

    local lines, first_change, new_line = {}, nil, 0
    local in_body = false
    for _, line in ipairs(vim.split(out, "\n", { plain = true })) do
        if in_body then
            local mark = line:sub(1, 1)
            if mark ~= "-" then
                new_line = new_line + 1
            end
            if not first_change and (mark == "+" or mark == "-") then
                -- a removed line sits just before the next line of the new file
                local file_line = mark == "-" and new_line + 1 or new_line
                first_change = { preview = #lines + 1, file = math.max(file_line, 1) }
            end
            table.insert(lines, line)
        elseif line:match("^@@") then
            in_body = true
        end
    end
    return lines, first_change
end

local function changed_files(base)
    local out = git({ "diff", "--name-status", "-M", "--diff-filter=d", base })
    local files = {}
    for _, line in ipairs(vim.split(out or "", "\n", { trimempty = true })) do
        local parts = vim.split(line, "\t", { plain = true })
        local status = parts[1]:sub(1, 1)
        if status == "R" then
            table.insert(files, { status = status, path = parts[3], old_path = parts[2] })
        else
            table.insert(files, { status = status, path = parts[2] })
        end
    end
    -- untracked files are part of the working tree too
    for _, path in
        ipairs(vim.split(git({ "ls-files", "--others", "--exclude-standard" }) or "", "\n", { trimempty = true }))
    do
        table.insert(files, { status = "?", path = path })
    end
    return files
end

-- Telescope picker of files changed since the merge base, previewing each
-- file's full diff; selecting one turns review mode on and opens the file at
-- its first change
function M.pick()
    if not state.enabled and not M.enable() then
        return
    end
    local base = state.base

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local previewers = require("telescope.previewers")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local entry_display = require("telescope.pickers.entry_display")
    local devicons_ok, devicons = pcall(require, "nvim-web-devicons")

    local status_hl = { A = "GitSignsAdd", M = "GitSignsChange", R = "GitSignsChange", ["?"] = "GitSignsUntracked" }
    local displayer = entry_display.create({
        separator = " ",
        items = { { width = 1 }, { width = 2 }, { remaining = true } },
    })

    local files = changed_files(base)
    if #files == 0 then
        vim.notify("Review mode: no changes against " .. state.branch)
        return
    end

    pickers
        .new({}, {
            prompt_title = ("PR changes vs %s"):format(state.branch),
            finder = finders.new_table({
                results = files,
                entry_maker = function(file)
                    local icon, icon_hl = " ", nil
                    if devicons_ok then
                        icon, icon_hl =
                            devicons.get_icon(file.path, vim.fn.fnamemodify(file.path, ":e"), { default = true })
                    end
                    return {
                        value = file,
                        ordinal = file.path,
                        path = file.path,
                        display = function()
                            return displayer({
                                { file.status, status_hl[file.status] },
                                { icon, icon_hl },
                                file.path,
                            })
                        end,
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            previewer = previewers.new_buffer_previewer({
                title = "Diff (full file)",
                define_preview = function(self, entry)
                    local file = entry.value
                    local lines, first_change
                    if file.status == "?" then
                        lines = vim.tbl_map(function(l)
                            return "+" .. l
                        end, vim.fn.readfile(file.path))
                        first_change = { preview = 1 }
                    else
                        lines, first_change = full_diff(base, file.path, file.old_path)
                    end
                    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                    require("telescope.previewers.utils").regex_highlighter(self.state.bufnr, "diff")
                    if first_change then
                        -- after Telescope finishes resetting the preview window
                        local winid = self.state.winid
                        vim.schedule(function()
                            if vim.api.nvim_win_is_valid(winid) then
                                pcall(vim.api.nvim_win_set_cursor, winid, { first_change.preview, 0 })
                                vim.api.nvim_win_call(winid, function()
                                    vim.cmd("normal! zz")
                                end)
                            end
                        end)
                    end
                end,
            }),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local file = action_state.get_selected_entry().value
                    actions.close(prompt_bufnr)
                    vim.cmd.edit(vim.fn.fnameescape(file.path))
                    if file.status ~= "?" then
                        local _, first_change = full_diff(base, file.path, file.old_path)
                        if first_change then
                            pcall(vim.api.nvim_win_set_cursor, 0, { first_change.file, 0 })
                            vim.cmd("normal! zz")
                        end
                    end
                end)
                return true
            end,
        })
        :find()
end

return M
