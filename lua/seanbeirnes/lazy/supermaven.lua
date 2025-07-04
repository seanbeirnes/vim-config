local function toggle_supermaven()
    if package.loaded["supermaven-nvim"] then
        local api = require("supermaven-nvim.api")
        api.toggle()
        if api.is_running() then
            print("Supermaven: ON")
        else
            print("Supermaven: OFF")
        end
    else
        print("Supermaven: Cannot toggle, plugin not loaded")
    end
end

return {
    {
        "supermaven-inc/supermaven-nvim",
        lazy = false,
        config = function()
            require("supermaven-nvim").setup({})
        end,
        keys = {
            {
                "<leader>sm",
                toggle_supermaven,
                desc = "toggle supermaven-nvim",
            },
        },
    },
}
