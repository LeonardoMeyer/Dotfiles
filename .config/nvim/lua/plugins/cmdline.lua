return {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
        "MunifTanjim/nui.nvim",
    },
    config = function()
        vim.cmd("source ~/.cache/wal/colors-wal.vim")
        local color9 = vim.g.color9 or "#808080"
        local color5 = vim.g.color5 or "#ffffff"

        require("noice").setup({
            -- notify_system owns vim.notify, so noice must not replace it
            notify = { enabled = false },
            lsp = {
                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"] = true,
                    ["cmp.entry.get_documentation"] = true,
                },
            },
            presets = {
                bottom_search = false,
                command_palette = true,
                long_message_to_split = true,
                inc_rename = false,
                lsp_doc_border = false,
            },
            messages = { enabled = true },
            routes = {
                {
                    -- error messages only: forward to a system notification
                    -- and hide noice's own popup for them
                    filter = {
                        event = "msg_show",
                        cond = function(message)
                            local kind = message.kind or ""
                            if kind ~= "emsg" and kind ~= "echoerr"
                                and kind ~= "lua_error" and kind ~= "rpc_error" then
                                return false
                            end

                            local text = vim.trim(message:content() or "")
                            if text == "" then
                                return false
                            end

                            vim.schedule(function()
                                vim.notify(text, vim.log.levels.ERROR)
                            end)
                            return true
                        end,
                    },
                    opts = { skip = true },
                },
            },
        })

        vim.cmd("highlight NoiceCmdlineIcon guifg=" .. color9)
        vim.cmd("highlight NoiceCmdlinePopupBorder guifg=" .. color5)
    end,
}
