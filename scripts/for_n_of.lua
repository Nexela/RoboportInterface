--- Call the given function on a set number of items in a table, returning the next starting key.
---
--- Calls `callback(value, key)` over `n` items from `tbl`, starting after `from_k`.
---
--- The first return value of each invocation of `callback` will be collected and returned in a table keyed by the
--- current item's key.
---
--- The second return value of `callback` is a flag requesting deletion of the current item.
---
--- The third return value of `callback` is a flag requesting that the iteration be immediately aborted. Use this flag to
--- early return on some condition in `callback`. When aborted, `for_n_of` will return the previous key as `from_k`, so
--- the next call to `for_n_of` will restart on the key that was aborted (unless it was also deleted).
---
--- **DO NOT** delete entires from `tbl` from within `callback`, this will break the iteration. Use the deletion flag
--- instead.
---
--- # Examples
---
--- ```lua
--- local extremely_large_table = {
---   [1000] = 1,
---   [999] = 2,
---   [998] = 3,
---   ...,
---   [2] = 999,
---   [1] = 1000,
--- }
--- event.on_tick(function()
---   global.from_k = table.for_n_of(extremely_large_table, global.from_k, 10, function(v) game.print(v) end)
--- end)
--- ```
--- From flib by Raiguard
--- @generic k, v, ret
--- @param tbl table The table to iterate over.
--- @param from_key k The key to start iteration at, or `nil` to start at the beginning of `tbl`.\
---  - If the key does not exist in `tbl`, it will be treated as `nil`, _unless_ a custom `_next` function is used.
--- @param n number The number of items to iterate.
--- @param callback fun(V: v, from_k: k, ...):ret, boolean, boolean #Receives `value`, `key`, `...` as parameters.
--- @param _next? fun(tbl: table<k, v>, index:k|nil, ...):k, v #A custom `next()` function.\
---  - If not provided, the default `next()` will be used. Reveives `tbl`, `key`, `...` as parameters.
--- @vararg ...? Additional parameters for callback/next if needed.
--- @return any next_key Where the iteration ended. Can be any valid table key, or `nil`. Pass this as `from_k` in the next call to `for_n_of` for `tbl`.
--- @return table<k, ret> results The results compiled from the first return of `callback`.
--- @return boolean reached_end Whether or not the end of the table was reached on this iteration.
local function for_n_of(tbl, from_key, n, callback, _next, ...)
    -- Bypass if a custom `next` function was provided
    if not _next then
        -- Verify start key exists, else start from scratch
        if from_key and not tbl[from_key] then from_key = nil end
        _next = next ---@cast _next -? Use default `next`
    end

    local prev_key
    local delete, abort, finished
    local result = {}

    -- Run `n` times
    for _ = 1, n, 1 do
        local v
        if not delete then prev_key = from_key end
        from_key, v = _next(tbl, from_key)
        if delete then tbl[delete] = nil end

        if from_key then
            result[from_key], delete, abort, finished = callback(v, from_key, ...)
            if delete then delete = from_key end
            if abort or finished then break end
        else
            return from_key, result, true
        end
    end

    if delete then
        tbl[delete] = nil
        from_key = prev_key
    elseif abort then
        from_key = prev_key
    end
    return from_key, result, finished
end

return for_n_of
