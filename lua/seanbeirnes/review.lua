-- PR review mode: diff every buffer against the merge base with the default
-- branch (same comparison as GitHub's "Files changed"), with line and word
-- highlights and inline deleted lines, plus a Telescope picker of the PR's
-- changed files.
local M = {}

local state = { enabled = false, base = nil, branch = nil }

local FETCH_TIMEOUT_MS = 10000

-- the open changed-files picker, rebuilt when the review base moves
local open_picker
local refresh_open_picker
-- file to keep selected once a rebuilt picker finishes loading its entries
local reselect_path

local function close_open_picker()
    if open_picker and not open_picker.closed then
        require("telescope.actions").close(open_picker.prompt_bufnr)
    end
end

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

local function merge_base_with(branch)
    return git({ "merge-base", "HEAD", branch })
end

local function merge_base()
    local branch = default_branch()
    if not branch then
        return nil, nil, "no default branch found"
    end
    local base = merge_base_with(branch)
    if not base then
        return nil, nil, "no merge base with " .. branch
    end
    return base, branch
end

-- Pulling only the feature branch leaves the remote-tracking default branch
-- stale, which puts main's newer commits in the review diff. Fetch it without
-- blocking, then move the review base if the merge base changed. Comparing
-- merge bases rather than branch tips makes main advancing past the merge a
-- no-op.
local function refresh_base_in_background()
    local remote, remote_branch = state.branch:match("^([^/]+)/(.+)$")
    if not remote then
        return
    end
    local fetched_branch = state.branch
    vim.system({ "git", "fetch", "--quiet", "--no-tags", remote, remote_branch }, {
        text = true,
        timeout = FETCH_TIMEOUT_MS,
        env = { GIT_TERMINAL_PROMPT = "0" },
    }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                local reason = vim.split(vim.trim(result.stderr or ""), "\n")[1]
                vim.notify(
                    ("Review base not refreshed, fetching %s failed: %s"):format(
                        fetched_branch,
                        reason ~= "" and reason or "timed out"
                    )
                )
            end
            -- check the current review session even after a failed fetch:
            -- toggling off and on mid-fetch can make the newer fetch lose the
            -- ref lock to the older one, which already updated the ref
            if not state.enabled then
                return
            end
            local base = merge_base_with(state.branch)
            if not base or base == state.base then
                return
            end
            require("gitsigns").change_base(base, true)
            state.base = base
            refresh_open_picker()
            vim.notify(("Review base updated after fetching %s (%s)"):format(state.branch, base:sub(1, 7)))
        end)
    end)
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
    gitsigns.toggle_word_diff(true)
    set_deleted(gitsigns, true)
    state = { enabled = true, base = base, branch = branch }
    vim.notify(("Review mode on: diffing against %s (%s)"):format(branch, base:sub(1, 7)))
    refresh_base_in_background()
    return true
end

function M.disable()
    -- its previews and jumps diff against the review base, which is going away
    close_open_picker()
    local gitsigns = require("gitsigns")
    gitsigns.reset_base(true)
    gitsigns.toggle_linehl(false)
    gitsigns.toggle_word_diff(false)
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

-- lines added/removed per file, keyed by (new) path; binary files are nil
local function line_counts(base)
    local out = git({ "diff", "--numstat", "-M", "-z", base }) or ""
    local fields = vim.split(out, "\0", { plain = true })
    local counts, i = {}, 1
    while i <= #fields do
        local added, removed, path = fields[i]:match("^(%S+)\t(%S+)\t(.*)$")
        if not added then
            break
        end
        if path == "" then
            -- rename: the old and new paths follow as separate fields
            path = fields[i + 2]
            i = i + 3
        else
            i = i + 1
        end
        counts[path] = { added = tonumber(added), removed = tonumber(removed) }
    end
    return counts
end

local function changed_files(base)
    local out = git({ "diff", "--name-status", "-M", "--diff-filter=d", base })
    local counts = line_counts(base)
    local files = {}
    for _, line in ipairs(vim.split(out or "", "\n", { trimempty = true })) do
        local parts = vim.split(line, "\t", { plain = true })
        local status = parts[1]:sub(1, 1)
        local file = status == "R" and { status = status, path = parts[3], old_path = parts[2] }
            or { status = status, path = parts[2] }
        file.counts = counts[file.path]
        table.insert(files, file)
    end
    -- untracked files are part of the working tree too
    for _, path in
        ipairs(vim.split(git({ "ls-files", "--others", "--exclude-standard" }) or "", "\n", { trimempty = true }))
    do
        local ok, lines = pcall(vim.fn.readfile, path)
        table.insert(files, { status = "?", path = path, counts = { added = ok and #lines or 0, removed = 0 } })
    end
    return files
end

local status_hl = { A = "GitSignsAdd", M = "GitSignsChange", R = "GitSignsChange", ["?"] = "GitSignsUntracked" }

-- "+12 -3" line counts, or "bin" for binary files
local function fmt_counts(file)
    local c = file.counts
    if not (c and c.added) then
        return "bin", ""
    end
    return "+" .. c.added, "-" .. c.removed
end

-- Telescope finder over `files`, with the count columns sized to the widest
local function files_finder(files)
    local finders = require("telescope.finders")
    local entry_display = require("telescope.pickers.entry_display")
    local devicons_ok, devicons = pcall(require, "nvim-web-devicons")

    local add_w, del_w = 0, 0
    for _, file in ipairs(files) do
        local a, d = fmt_counts(file)
        add_w, del_w = math.max(add_w, #a), math.max(del_w, #d)
    end
    local displayer = entry_display.create({
        separator = " ",
        items = { { width = 1 }, { width = 2 }, { width = add_w }, { width = del_w }, { remaining = true } },
    })

    return finders.new_table({
        results = files,
        entry_maker = function(file)
            local icon, icon_hl = " ", nil
            if devicons_ok then
                icon, icon_hl = devicons.get_icon(file.path, vim.fn.fnamemodify(file.path, ":e"), { default = true })
            end
            return {
                value = file,
                ordinal = file.path,
                path = file.path,
                display = function()
                    local added, removed = fmt_counts(file)
                    return displayer({
                        { file.status, status_hl[file.status] },
                        { icon, icon_hl },
                        { added, "GitSignsAdd" },
                        { removed, "GitSignsDelete" },
                        file.path,
                    })
                end,
            }
        end,
    })
end

-- the file set and line counts depend on the base, so the entries are
-- rebuilt; the selection stays on the same file so Enter doesn't open another
refresh_open_picker = function()
    if not open_picker or open_picker.closed then
        return
    end
    local files = changed_files(state.base)
    if #files == 0 then
        close_open_picker()
        vim.notify("Review mode: no changes against " .. state.branch)
        return
    end
    local selected = open_picker:get_selection()
    reselect_path = selected and selected.path
    open_picker:refresh(files_finder(files))
end

local function reselect_after_refresh(picker)
    if not reselect_path then
        return
    end
    local path = reselect_path
    reselect_path = nil
    for entry in picker.manager:iter() do
        if entry.path == path then
            picker:set_selection(picker:get_row(picker.manager:find_entry(entry)))
            return
        end
    end
end

-- Telescope picker of files changed since the merge base (turning review mode
-- on first), previewing each file's full diff; selecting one opens the file at
-- its first change. It opens on the current base without waiting for the
-- background fetch, and rebuilds its list if that fetch moves the base.
function M.pick()
    if not state.enabled and not M.enable() then
        return
    end

    local pickers = require("telescope.pickers")
    local previewers = require("telescope.previewers")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local files = changed_files(state.base)
    if #files == 0 then
        vim.notify("Review mode: no changes against " .. state.branch)
        return
    end

    open_picker = pickers.new({}, {
        prompt_title = ("PR changes vs %s"):format(state.branch),
        finder = files_finder(files),
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
                    lines, first_change = full_diff(state.base, file.path, file.old_path)
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
                local entry = action_state.get_selected_entry()
                if not entry then
                    return
                end
                local file = entry.value
                actions.close(prompt_bufnr)
                vim.cmd.edit(vim.fn.fnameescape(file.path))
                if file.status ~= "?" then
                    local _, first_change = full_diff(state.base, file.path, file.old_path)
                    if first_change then
                        pcall(vim.api.nvim_win_set_cursor, 0, { first_change.file, 0 })
                        vim.cmd("normal! zz")
                    end
                end
            end)
            return true
        end,
    })
    local picker = open_picker
    picker:register_completion_callback(function()
        reselect_after_refresh(picker)
    end)
    picker:find()
end

return M
