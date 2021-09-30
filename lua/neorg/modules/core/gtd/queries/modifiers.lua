return function(module)
    return {
        public = {
            --- Modifies an `option` from `object` (the content must not be extracted!) with new `value`
            --- @param object table
            --- @param node_type string
            --- @param option string
            --- @param value string|table
            --- @param opts table
            ---   - opts.tag (string)           the tag to create if we use opts.force_create
            ---   - opts.index (number)         if object.option is a table, specify an index to select the node index to modify
            --                                  e.g contexts = { "home", "mac" }, replacing "mac" with opts.index = 2
            modify = function(object, node_type, option, value, opts)
                opts = opts or {}
                if not value then
                    return object
                end

                -- Create the tag (opts.tag) with the values if opts.force_create and opts.tag
                if not object[option] then
                    if not opts.tag then
                        log.error("Please specify a tag with opts.tag")
                        return
                    end
                    module.public.insert_tag({ object.node, object.bufnr }, value, opts.tag)
                    return module.public.update(object, node_type)
                end

                local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

                -- Select the node to modify
                local fetched_node
                if type(object[option]) == "table" then
                    if opts.tag then
                        object = module.public.delete(object, node_type, option)
                        module.public.insert_tag({ object.node, object.bufnr }, value, opts.tag)
                        return module.public.update(object, node_type)
                    else
                        log.error("Only tags and content are supported for modification")
                        return
                    end
                else
                    -- Easy, modify the content
                    fetched_node = object[option]
                end

                -- Get the position of the node to modify
                local start_row, start_col, end_row, end_col = ts_utils.get_node_range(fetched_node)

                if not end_row or not end_col then
                    return module.public.update(object, node_type)
                end

                -- Replacing old option with new one (The empty string is to prevent lines below to wrap)
                vim.api.nvim_buf_set_text(object.bufnr, start_row, start_col, end_row, end_col, { value, "" })

                return module.public.update(object, node_type)
            end,

            --- Delete a node from an `object` with `option` key
            --- @param object table
            --- @param option string
            --- @param opts table
            delete = function(object, node_type, option, opts)
                opts = opts or {}

                local ts_utils = module.required["core.integrations.treesitter"].get_ts_utils()

                local fetched_node
                if type(object[option]) == "table" then
                    local carryover_tags = vim.tbl_map(function(n)
                        local carryover_tag = module.required["core.queries.native"].find_parent_node(
                            { n, object.bufnr },
                            "carryover_tag"
                        )
                        return carryover_tag[1]
                    end, object[option])

                    -- If they are not from the same carryover_tag, error
                    local same_tags = vim.tbl_filter(function(t)
                        return t == carryover_tags[1]
                    end, carryover_tags)
                    if #same_tags < #carryover_tags then
                        log.error("All tags from " .. option .. " must have the same carryover_tag")
                        return
                    end

                    fetched_node = carryover_tags[1]
                else
                    fetched_node = object[option]
                end

                local start_row, start_col, end_row, end_col = ts_utils.get_node_range(fetched_node)

                -- FIXME: Out of bounds if i only delete without going to modify

                -- Deleting object
                vim.api.nvim_buf_set_text(object.bufnr, start_row, start_col, end_row, end_col, { "" })

                -- FIXME: module.update is nil here
                local new_node = module.public.update(object, node_type)
                return new_node
            end,
        },
    }
end
