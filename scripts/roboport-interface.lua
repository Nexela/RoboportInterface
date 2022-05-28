local Event = require('__stdlib__/stdlib/event/event')
local math = require('__stdlib__/stdlib/utils/math')
local table = require('__stdlib__/stdlib/utils/table')
local abs, clamp, min, max = math.abs, math.clamp, math.min, math.max

--- @class ri.parameter_map
local parameter_map = {
    ['interface-signal-item-on-ground'] = {action = 'deconstruct_entity', type = 'item-entity'},
    ['interface-signal-chop-trees'] = {action = 'deconstruct_entity', type = 'tree', item_name = 'wood'},
    ['interface-signal-catch-fish'] = {action = 'deconstruct_entity', type = 'fish', item_name = 'raw-fish'},
    ['interface-signal-refill-turrets'] = {action = 'refill_turrets'},
    ['interface-signal-smarter-charging'] = {action = 'smarter_recharge'},
    ['interface-signal-upgrade-modules'] = {action = 'upgrade_modules'},
    ['interface-signal-deconstruct-finished-miners'] = {action = 'deconstruct_finished_miners', type = 'mining-drill'},
    ['interface-signal-landfill-the-world'] = {action = 'landfill_the_world'},
    ['interface-signal-build-tiles'] = {action = 'tile_ground', item_name = 'hazard-concrete'},
    ['interface-signal-remove-tiles'] = {action = 'remove_tiles'},
    ['interface-signal-roboport-count'] = {action = nil},
    ['interface-signal-enemy-range'] = {action = nil},
    ['interface-signal-bot-utilization'] = {action = nil},
    ['interface-signal-roboport-channel'] = {action = nil}
}

--- @param parameters ConstantCombinatorParameters[]
--- @return ri.parameter_map
--- @return int
local function get_parameter_dictionary(parameters)
    local new_parameters = {}
    local count = 0
    for _, parameter in pairs(parameters) do
        local name = parameter.signal.name
        if name and parameter_map[name] then
            new_parameters[name] = table.deep_copy(parameter_map[name])
            new_parameters[name].count = parameter.count
            if new_parameters[name].action then count = count + 1 end
        end
    end
    return new_parameters, count
end

--- @param interface LuaEntity
local function run_interface(interface)
    local behaviour = interface.get_control_behavior() ---@type LuaConstantCombinatorControlBehavior
    if not (behaviour and behaviour.enabled) then return end

    local parameters, action_count = get_parameter_dictionary(behaviour.parameters)
    if action_count == 0 then return end

    local port = interface.surface.find_entity('roboport-interface-main', interface.position)
    if not port then return end

    local network = port.logistic_network
    if not network then return end

    local per_value = parameters['interface-signal-bot-utilization'] and parameters['interface-signal-bot-utilization'].count or 100
    local per = clamp(abs(per_value / 100), 0, 1)
    local available_bots = network.available_construction_robots * per
    if available_bots <= 0 then return end

    -- Subtract 1 from network cells to not include self
    local cells = network.cells
    local cells_to_search = (parameters['interface-signal-roboport-count'] and parameters['interface-signal-roboport-count'].count) or (#cells - 1)
    if cells_to_search <= 0 then return end

    local channel = (parameters['interface-signal-roboport-channel'] and parameters['interface-signal-roboport-channel'].count) or 0
    local enemy_range = (parameters['interface-signal-enemy-range'] and parameters['interface-signal-enemy-range'].count) or 0

    local force = network.force
    local surface = interface.surface
    local contents = network.get_contents()

    for _, param in pairs(parameters) do
        if not param.action then goto continue_parameters end

        -- If the count is negative then check for contents of network
        local limit = abs(param.count)
        if param.item_name and param.count < 0 then
            limit = limit - (contents[param.item_name] or 0)
        end
        if limit <= 0 then break end

        for _, cell in pairs(cells) do
            if limit <= 0 or cells_to_search <= 0 or available_bots <= 0 then break end
            local owner = cell.owner
            local cell_radius = cell.construction_radius
            if cell.mobile or cell_radius <= 0 then goto continue_cells end
            if channel ~= 0 and owner.get_merged_signal({name = 'interface-signal-roboport-channel', type = 'virtual'}) ~= channel then
                goto continue_cells
            end

            local position = owner.position

            local radius = cell_radius + enemy_range
            if radius >= 0 and surface.find_nearest_enemy{
                position = position,
                max_distance = radius,
                force = force
            }
            then goto continue_cells end

            if param.action == 'deconstruct_entity' then
                local entities = surface.find_entities_filtered{
                    position = position,
                    radius = cell_radius,
                    type = param.type,
                    limit = max(0, min(limit, available_bots)),
                    to_be_deconstructed = false,
                }
                local num_entities = #entities
                limit = limit - num_entities
                available_bots = available_bots - num_entities
                cells_to_search = cells_to_search - 1
                for _, entity in pairs(entities) do entity.order_deconstruction(force) end
            end
            ::continue_cells::
        end
        ::continue_parameters::
    end
end

do -- Events
    --- @param event on_tick
    local function on_tick(event)

    end
    Event.register(defines.events.on_tick, on_tick)


    -- There is where all the magic happens
    -- Check signals, then execute the actions.
    --- @param event on_sector_scanned
    local function on_sector_scanned(event)
        if event.radar.name == 'roboport-interface-scanner' then
            local entity = event.radar
            local interface = entity.surface.find_entity('roboport-interface-cc', entity.position)
            return interface and run_interface(interface)
        end
    end
    Event.register(defines.events.on_sector_scanned, on_sector_scanned)

    -- Build the interface, after built check the area around it for interface components to revive or create.
    local function build_roboport_interface(event)
        local interface = event.created_entity or event.entity
        if interface and interface.name == 'roboport-interface-main' then
            local pos, force = interface.position, interface.force
            local cc, ra = {}, {} -- Don't listen the masses.... a little gc churn later is two less type() calls now.

            for _, entity in pairs(interface.surface.find_entities_filtered{position = pos, force = force}) do
                if entity ~= interface then
                    -- If we have ghosts either via blueprint or something killed them
                    if entity.name == 'entity-ghost' then
                        if entity.ghost_name == 'roboport-interface-cc' then
                            _, cc = entity.revive()
                        elseif entity.ghost_name == 'roboport-interface-scanner' then
                            _, ra = entity.revive()
                        end
                    elseif entity.name == 'roboport-interface-cc' then
                        cc = entity
                    elseif entity.name == 'roboport-interface-scanner' then
                        ra = entity
                    end
                end
            end

            -- If neither CC or RA are valid at this point then let us create them.
            if not cc.valid then
                cc = interface.surface.create_entity{name = 'roboport-interface-cc', position = pos, force = force}
            end
            if not ra.valid then
                ra = interface.surface.create_entity{name = 'roboport-interface-scanner', position = pos, force = force}
            end

            interface.energy = 0 -- roboports start with a buffer of energy. Lets take that away!
            ra.backer_name = interface.backer_name -- Use the same backer name for the interface and radar
            cc.direction = defines.direction.north
            cc.destructible = false
            ra.destructible = false
        end
    end
    Event.register(Event.build_events, build_roboport_interface)

    -- Cleanup interface on death
    local function kill_or_remove_interface_parts(event, destroy)
        if event.entity.name == 'roboport-interface-main' then
            local interface = event.entity
            local filter = {position = interface.position, force = interface.force}
            for _, entity in pairs(interface.surface.find_entities_filtered(filter)) do
                if entity ~= interface and entity.name:find('^roboport%-interface') then
                    if destroy then return entity.destroy() end
                    return entity.die()
                end
            end
        end
    end
    Event.register(defines.events.on_entity_died, kill_or_remove_interface_parts)
    Event.register(Event.mined_events, function(event)
        kill_or_remove_interface_parts(event, true)
    end)

end
