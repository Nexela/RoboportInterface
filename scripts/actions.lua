local Position = require('__stdlib__/stdlib/area/position')
local min, max = math.min, math.max

local Actions = {}

--- Run all parameters on a specific cell
--- @param cell_data ri.cell_data
Actions['Run'] = function(cell_data)
    if cell_data.network_data.available_bots <= 0 then return nil, nil, nil, true end
    if not cell_data.cell.valid then return end

    if cell_data.enemy_radius >= 0 and cell_data.network_data.surface.find_nearest_enemy {
        position = cell_data.position,
        max_distance = cell_data.enemy_radius,
        force = cell_data.network_data.force
    } then cell_data.has_enemy = true end

    for _, parameter in pairs(cell_data.network_data.parameters) do
        if cell_data.network_data.available_bots <= 0 then return end
        Actions[parameter.action](parameter, cell_data)
    end
end

--- @param parameter ri.parameter_map
--- @param cell_data ri.cell_data
Actions['deconstruct_entity'] = function(parameter, cell_data)
    if cell_data.has_enemy then return end

    if parameter.item_name and parameter.count < 0 then
        parameter.limit = parameter.limit - (cell_data.network_data.contents[parameter.item_name] or 0)
    end
    if parameter.limit <= 0 then return end

    local entities = cell_data.network_data.surface.find_entities_filtered {
        area = cell_data.area,
        type = parameter.type,
        limit = max(0, min(parameter.limit, cell_data.network_data.network.available_construction_robots)),
        to_be_deconstructed = false,
    }
    local num_entities = #entities
    parameter.limit = parameter.limit - num_entities
    cell_data.network_data.available_bots = cell_data.network_data.available_bots - num_entities
    for _, entity in pairs(entities) do entity.order_deconstruction(cell_data.network_data.force) end
end

--- @param parameter ri.parameter_map
--- @param cell_data ri.cell_data
Actions['refill_turrets'] = function(parameter, cell_data)
    local ammo_name = parameter.prototype.name
    local network_ammo_count = parameter.ammo_count or cell_data.network_data.contents[ammo_name] or 0
    if network_ammo_count <= 0 then return end

    local turrets = cell_data.network_data.surface.find_entities_filtered {
        area = cell_data.area,
        type = 'ammo-turret',
        to_be_deconstructed = false,
        force = cell_data.network_data.force
    }

    for _, turret in pairs(turrets) do
        if cell_data.network_data.available_bots <= 0 then return nil, nil, nil, true end
        if network_ammo_count <= 0 then return end

        local position = turret.position
        if cell_data.network_data.surface.find_entity('item-request-proxy', position) then return end

        local inventory = turret.get_inventory(defines.inventory.turret_ammo) --[[@as LuaInventory]]
        local insertable = inventory.get_insertable_count(ammo_name)
        if insertable <= 0 then goto continue end
        local count = math.min(parameter.count - inventory.get_item_count(ammo_name), insertable)
        if count <= 0 or count > parameter.count then goto continue end

        if cell_data.network_data.surface.create_entity {
            position = position,
            name = 'item-request-proxy',
            target = turret,
            force = cell_data.network_data.force,
            modules = { [ammo_name] = count }
        } then
            cell_data.network_data.available_bots = cell_data.network_data.available_bots - 1
            network_ammo_count = network_ammo_count - count
            parameter.ammo_count = network_ammo_count
        end

        ::continue::
    end
end

--- @param parameter ri.parameter_map
--- @param cell ri.cell_data
Actions['landfill_the_world'] = function(parameter, cell)
    local tile_name = parameter.prototype.name
    parameter.network_tile_count = parameter.network_tile_count or (cell.network_data.contents[tile_name] or 0)
    if parameter.count <= 0 or parameter.network_tile_count <= 0 then return end

    local water_tiles = cell.network_data.surface.find_tiles_filtered {
        area = cell.area,
        collision_mask = 'water-tile',
        force = cell.network_data.force,
        limit = max(0, min(parameter.limit, cell.network_data.network.available_construction_robots))
    }

    for _, tile in pairs(water_tiles) do
        if cell.network_data.available_bots <= 0 then return nil, nil, nil, true end
        if parameter.limit <= 0 or parameter.network_tile_count <= 0 then return end
        local position = Position(tile.position):center()
        if cell.network_data.surface.find_entity('tile-ghost', position) then goto continue end

        if cell.network_data.surface.create_entity {
            name = 'tile-ghost',
            ghost_name = parameter.tile_prototype.name,
            position = position,
            force = cell.network_data.force
        } then
            cell.network_data.available_bots = cell.network_data.available_bots - 1
            parameter.limit = parameter.limit - 1
            parameter.network_tile_count = parameter.network_tile_count - 1
        end

        ::continue::
    end
end

--- @param parameter ri.parameter_map
--- @param cell ri.cell_data
Actions['pave_the_world'] = function(parameter, cell)
    local tile_name = parameter.prototype.name
    parameter.network_tile_count = parameter.network_tile_count or (cell.network_data.contents[tile_name] or 0)
    if parameter.network_tile_count <= 0 then return end

    local tiles = cell.network_data.surface.find_tiles_filtered {
        area = cell.area,
        collision_mask = 'ground-tile',
        force = cell.network_data.force,
        has_hidden_tile = false,
        limit = max(0, min(parameter.limit, cell.network_data.network.available_construction_robots))
    }

    for _, tile in pairs(tiles) do
        if cell.network_data.available_bots <= 0 then return nil, nil, nil, true end
        if parameter.limit <= 0 or parameter.network_tile_count <= 0 then return end

        local position = Position(tile.position):center()
        if cell.network_data.surface.find_entity('tile-ghost', position) then goto continue end

        if cell.network_data.surface.create_entity {
            name = 'tile-ghost',
            ghost_name = parameter.tile_prototype.name,
            position = position,
            force = cell.network_data.force
        } then
            cell.network_data.available_bots = cell.network_data.available_bots - 1
            parameter.limit = parameter.limit - 1
            parameter.network_tile_count = parameter.network_tile_count - 1
        end

        ::continue::
    end
end

--- @param parameter ri.parameter_map
--- @param cell ri.cell_data
Actions['strip_the_world'] = function(parameter, cell)
    -- !API find_tiles_filtered has_tile_ghost/to_be_deconstructed
    local tile_name = parameter.tile_prototype.name

    local tiles = cell.network_data.surface.find_tiles_filtered {
        name = tile_name,
        area = cell.area,
        collision_mask = 'ground-tile',
        has_hidden_tile = true,
        limit = max(0, min(parameter.limit, cell.network_data.network.available_construction_robots)) * 3
    }

    for _, tile in pairs(tiles) do
        if cell.network_data.available_bots <= 0 then return nil, nil, nil, true end
        if parameter.limit <= 0 then return end
        if tile.to_be_deconstructed() then goto continue end
        local position = Position(tile.position):center()
        if cell.network_data.surface.find_entity('tile-ghost', position) then goto continue end
        if cell.network_data.surface.find_entity('entity-ghost', position) then goto continue end

        if tile.order_deconstruction(cell.network_data.force) then
            cell.network_data.available_bots = cell.network_data.available_bots - 1
            parameter.limit = parameter.limit - 1
        end

        ::continue::
    end
end

return Actions
