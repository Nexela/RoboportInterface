local table = require('__stdlib__/stdlib/utils/table')
local abs = math.abs

--- @class ri.parameter_map
--- @field action string function to call
--- @field count integer
--- @field limit integer
--- @field type? string
--- @field item_name? string
--- @field prototype? LuaItemPrototype
--- @field tile_prototype? LuaTilePrototype
--- @field ammo_count? integer

--- @type {[string]: ri.parameter_map}
local parameter_map = {
    ['interface-signal-item-on-ground'] = { action = 'deconstruct_entity', type = 'item-entity' },
    ['interface-signal-chop-trees'] = { action = 'deconstruct_entity', type = 'tree', item_name = 'wood' },
    ['interface-signal-catch-fish'] = { action = 'deconstruct_entity', type = 'fish', item_name = 'raw-fish' },
    -- ['interface-signal-smarter-charging'] = {action = 'smarter_recharge'},
    -- ['interface-signal-upgrade-modules'] = {action = 'upgrade_modules'},
    -- ['interface-signal-deconstruct-finished-miners'] = {action = 'deconstruct_finished_miners', type = 'mining-drill'},
}

--- @type {[string]: integer}
local settings_map = {
    ['interface-signal-roboport-count'] = 1,
    ['interface-signal-enemy-range'] = 0,
    ['interface-signal-bot-utilization'] = 100,
    ['interface-signal-roboport-channel'] = 0,
}

--- @param parameters ConstantCombinatorParameters[]
--- @return {[string]: ri.parameter_map}
--- @return {[string]: integer}
--- @return int
local function parse_parameters(parameters)
    local new_parameters = {}
    local new_settings = {}
    local action_count = 0
    for _, parameter in pairs(parameters) do
        local name = parameter.signal.name
        if not name then goto continue end
        if parameter.signal.type == 'virtual' then
            if parameter_map[name] then
                local virtual_parameter = table.deep_copy(parameter_map[name])
                virtual_parameter.count = parameter.count
                virtual_parameter.limit = math.abs(parameter.count)
                action_count = action_count + 1
                table.insert(new_parameters, virtual_parameter)
            elseif settings_map[name] then
                new_settings[name] = parameter.count
            end
        elseif parameter.signal.type == 'item' then
            local prototype = game.item_prototypes[name]
            if not prototype then goto continue end

            local item_parameter = {
                prototype = prototype,
                count = parameter.count,
                limit = abs(parameter.count)
            }

            if prototype.type == 'ammo' then
                item_parameter.action = 'refill_turrets'
                action_count = action_count + 1
                table.insert(new_parameters, item_parameter)
                goto continue
            end

            local tile_result = prototype.place_as_tile_result
            local tile = tile_result and tile_result.result
            if tile then
                ---@cast tile_result -?
                item_parameter.tile_prototype = tile

                if tile_result.condition['ground-tile'] then
                    item_parameter.action = 'landfill_the_world'
                elseif tile_result.condition['water-tile'] then
                    if parameter.count > 0 then
                        item_parameter.action = 'pave_the_world'
                    elseif parameter.count < 0 then
                        item_parameter.action = 'strip_the_world'
                    end
                end

                action_count = action_count + 1
                table.insert(new_parameters, item_parameter)
                goto continue
            end
        end
        ::continue::
    end
    return new_parameters, new_settings, action_count
end

return parse_parameters
