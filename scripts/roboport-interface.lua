-------------------------------------------------------------------------------
--[[roboport-interface]] -------------------------------------------------------------------------------
local Event = require('__stdlib__/stdlib/event/event')
local table = require('__stdlib__/stdlib/utils/table')
local abs = math.abs
--[[--
raw-wood-cutting, scan for trees, if value is negative only scan for trees if wood in network is less then that amount
tile-item, scan for tiles, only checks first signal, if negative, will not place tiles unless that many are in network.
item-on-ground-sig, Scan for items on ground, if found cell will check for items-ground and mark for pickup if no enemies in range
networks-sig

parameters ={
    {
        count = 1,
        index = 1,
        signal = {
            name = "nano-signal-item-on-ground",
            type = "virtual"
        }
    },
    {
        count = 1,
        index = 2,
        signal = {
            type = "item"
        }
    },
}
--]] --

local parameter_map = {
    ['interface-signal-chop-trees'] = {action = 'deconstruct_entity', type = 'tree', item_name = 'wood'},
    ['interface-signal-item-on-ground'] = {action = 'deconstruct_entity', type = 'item-entity'},
    ['interface-signal-catch-fish'] = {action = 'deconstruct_entity', type = 'fish', item_name = 'raw-fish'},
    -- ['interface-build-tiles'] = {action = 'tile_ground', item_name = 'hazard-concrete'},
    ['interface-signal-deconstruct-finished-miners'] = {action = 'deconstruct_finished_miners', type = 'mining-drill'},
    ['interface-signal-landfill-the-world'] = {action = 'landfill_the_world'},
    ['interface-signal-remove-tiles'] = {action = 'remove_tiles'}
}

local function get_parameters(parameters)
    local new_parameters = {}
    for _, parameter in pairs(parameters) do
        local name = parameter.signal.name
        if name and parameter.count ~= 0 then
            if parameter_map[name] then
                new_parameters[name] = table.deep_copy(parameter_map[name])
                new_parameters[name].count = parameter.count
            elseif parameter.signal.type == 'item' then
                local proto = game.item_prototypes[name]
                if proto then
                    local tile_result = proto.place_as_tile_result
                    if tile_result then
                        new_parameters[name] = {
                            action = 'tile_ground',
                            tile = tile_result.result,
                            count = parameter.count
                        }
                    end
                end

            end
        end
    end
    return new_parameters
end

-- local function get_available_bots(cell)
--     local net = cell.logistic_network
--     local percentage = settings.global['interface-free-bots-per'].value / 100
--     return floor(net.available_construction_robots - (net.all_construction_robots * percentage))
-- end

-- local function get_network(interface)
--     local port = interface.surface.find_entity('roboport-interface-main', interface.position)
--     if port then
--         local network = port.logistic_network
--         local cell = table.find(port.logistic_cell.neighbours, function(v)
--             return v.construction_radius > 0
--         end) or port.logistic_cell
--         return network, cell
--     end
-- end

-- local function get_entity_info(entity)
--     return entity.surface, entity.force, entity.position
-- end

-- local function deconstruct_entity(data)
--     -- Queue.mark_items_or_trees = function(data)
--     if data.logistic_cell.valid and data.logistic_cell.construction_radius > 0 and data.logistic_cell.logistic_network then
--         local surface, force, position = get_entity_info(data.logistic_cell.owner)
--         if not (data.type or data.find_name) then data.type = 'NIL' end
--         if not surface.find_nearest_enemy{
--             position = position,
--             max_distance = data.logistic_cell.construction_radius * 1.5 + 40,
--             force = force
--         } then
--             local filter = {
--                 area = Position.expand_to_area(position, data.logistic_cell.construction_radius),
--                 name = data.find_name,
--                 type = data.type,
--                 limit = 300
--             }
--             local available_bots = get_available_bots(data.logistic_cell)
--             local limit = -99999999999
--             if data.value < 0 and data.item_name then
--                 limit = (data.logistic_cell.logistic_network.get_contents()[data.item_name] or 0) + data.value
--             end

--             for _, item in pairs(surface.find_entities_filtered(filter)) do
--                 if available_bots > 0 and (limit < 0) then
--                     if not item.to_be_deconstructed(force) then
--                         item.order_deconstruction(force)
--                         available_bots = available_bots - 1
--                         limit = limit + 1
--                     end
--                 else
--                     break
--                 end
--             end
--         end
--     end
-- end

-- local function has_resources(miner)
--     local _find = function(v, _)
--         return v.prototype.resource_category == 'basic-solid' and (v.amount > 0 or v.prototype.infinite_resource)
--     end
--     local filter = {
--         area = Position.expand_to_area(miner.position, miner.prototype.mining_drill_radius),
--         type = 'resource'
--     }
--     if miner.mining_target then
--         return (miner.mining_target.amount or 0) > 0
--     else
--         return table.find(miner.surface.find_entities_filtered(filter), _find)
--     end
-- end

-- Queue.deconstruct_finished_miners = function(data)
--     if not game.active_mods['AutoDeconstruct'] then
--         if data.logistic_cell.valid and data.logistic_cell.construction_radius > 0 and
--             data.logistic_cell.logistic_network then
--             local surface, force, position = get_entity_info(data.logistic_cell.owner)
--             local filter = {
--                 area = Position.expand_to_area(position, data.logistic_cell.construction_radius),
--                 type = data.type or 'error',
--                 force = force
--             }
--             for _, miner in pairs(surface.find_entities_filtered(filter)) do
--                 if not miner.to_be_deconstructed(force) and miner.minable and not miner.has_flag('not-deconstructable') and
--                     not has_resources(miner) then miner.order_deconstruction(force) end
--             end
--         end
--     end
-- end

--- @param interface LuaEntity
local function run_interface(interface)
    local behaviour = interface.get_control_behavior() ---@type LuaConstantCombinatorControlBehavior
    if not (behaviour and behaviour.enabled) then return end

    local parameters = get_parameters(behaviour.parameters)
    if table_size(parameters) == 0 then return end

    local port = interface.surface.find_entity('roboport-interface-main', interface.position)
    if not port then return end

    local network = port.logistic_network
    if not network then return end

    local percentage = settings.global['interface-free-bots-per'].value / 100
    if network.available_construction_robots <= network.all_construction_robots * percentage then return end

    -- If the closest roboport signal is present and > 0 then just run on the attached cell
    -- Todo rename to interface-signal-cell-count
    local cells_to_search = math.abs(parameters['interface-signal-closest-roboport'] or #network.cells)
    parameters['interface-signal-closest-roboport'] = nil
    if cells_to_search == 0 then return end

    local force = network.force
    local surface = interface.surface

    for _, param in pairs(parameters) do
        local limit = abs(param.count)
        local positive = abs(param.count) == param.count

        -- If the count is negative then check for contents of network
        if param.item_name and param.count < 0 then
            local network_count = network.get_contents()[param.item_name] or 0
            if network_count > limit then
                limit = 0
            else
                limit = limit - network_count
            end
        end

        for _, cell in pairs(network.cells) do
            if not cell.mobile and cell.construction_radius > 0 then

                if param.action == 'deconstruct_entity' then
                    if limit <= 0 or cells_to_search <= 0 then break end
                    local entities = surface.find_entities_filtered{
                        position = cell.owner.position,
                        radius = cell.construction_radius,
                        type = param.type,
                        to_be_deconstructed = false,
                        limit = limit
                    }
                    limit = limit - #entities
                    cells_to_search = cells_to_search - 1
                    for _, entity in pairs(entities) do entity.order_deconstruction(force) end
                elseif param.action == 'tile_ground' then
                    if limit <= 0 then break end
                    local tiles = surface.find_tiles_filtered{
                        position = cell.owner.position,
                        radius = cell.construction_radius,
                        -- has_hidden_tile = false,
                        collision_mask = {'ground-tile'}
                        -- limit = limit,
                    }
                    for _, tile in pairs(tiles) do
                        if limit <= 0 then break end
                        -- Positive build tile
                        if positive then
                            if not tile.hidden_tile then
                                if not surface.find_entity('tile-ghost', tile.position) then
                                    limit = limit - 1
                                    surface.create_entity{
                                        name = 'tile-ghost',
                                        force = force,
                                        position = tile.position,
                                        inner_name = param.tile.name
                                    }
                                end
                            end

                        else -- remove tile

                        end
                    end
                end
            end
        end
    end
end

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
