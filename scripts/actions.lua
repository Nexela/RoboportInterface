local Position = require('__stdlib__/stdlib/area/position')
local min, max = math.min, math.max

local Actions = {}

--- Run all parameters on a specific cell
--- @param cell ri.cell_data
Actions['Run'] = function(cell)
    if cell.network.available_bots <= 0 then return nil, nil, nil, true end
    if not cell.cell.valid then return end

    if cell.enemy_radius >= 0 and cell.network.surface.find_nearest_enemy{
        position = cell.position,
        max_distance = cell.enemy_radius,
        force = cell.network.force
    } then cell.has_enemy = true end

    for _, param in pairs(cell.network.parameters) do
        if cell.network.available_bots <= 0 then return end
        Actions[param.action](param, cell)
    end
end

--- @param param ri.parameter_map
--- @param cell ri.cell_data
Actions['deconstruct_entity'] = function(param, cell)
    if cell.has_enemy then return end

    if param.item_name and param.count < 0 then
        param.limit = param.limit - (cell.network.contents[param.item_name] or 0)
    end
    if param.limit <= 0 then return end

    local entities = cell.network.surface.find_entities_filtered{
        area = cell.area,
        type = param.type,
        limit = max(0, min(param.limit, cell.network.network.available_construction_robots)),
        to_be_deconstructed = false,
    }
    local num_entities = #entities
    param.limit = param.limit - num_entities
    cell.network.available_bots = cell.network.available_bots - num_entities
    for _, entity in pairs(entities) do entity.order_deconstruction(cell.network.force) end
end

--- @param param ri.parameter_map
--- @param cell ri.cell_data
Actions['refill_turrets'] = function(param, cell)
    local ammo_name = param.prototype.name
    local network_ammo_count = param.ammo_count or cell.network.contents[ammo_name] or 0
    if network_ammo_count <= 0 then return end

    local turrets = cell.network.surface.find_entities_filtered{
        area = cell.area,
        type = 'ammo-turret',
        to_be_deconstructed = false,
        force = cell.network.force
    }

    for _, turret in pairs(turrets) do
        if cell.network.available_bots <= 0 then return nil, nil, nil, true end
        if network_ammo_count <= 0  then return end

        local position = turret.position
        if cell.network.surface.find_entity('item-request-proxy', position) then return end

        local inventory = turret.get_inventory(defines.inventory.turret_ammo)
        local insertable = inventory.get_insertable_count(ammo_name)
        if insertable <= 0 then goto continue end
        local count = math.min(param.count - inventory.get_item_count(ammo_name), insertable)
        if count <= 0 or count > param.count then goto continue end

        if cell.network.surface.create_entity{
            position = position,
            name = 'item-request-proxy',
            target = turret,
            force = cell.network.force,
            modules = {[ammo_name] = count}
        } then
            cell.network.available_bots = cell.network.available_bots - 1
            network_ammo_count = network_ammo_count - count
            param.ammo_count = network_ammo_count
        end

        ::continue::
    end
end

--- @param param ri.parameter_map
--- @param cell ri.cell_data
Actions['landfill_the_world'] = function(param, cell)
    local tile_name = param.prototype.name
    param.network_tile_count = param.network_tile_count or (cell.network.contents[tile_name] or 0)
    if param.count <= 0 or param.network_tile_count <= 0 then return end

    local water_tiles = cell.network.surface.find_tiles_filtered{
        area = cell.area,
        collision_mask = 'water-tile',
        force = cell.network.force,
        limit = max(0, min(param.limit, cell.network.network.available_construction_robots))
    }

    for _, tile in pairs(water_tiles) do
        if cell.network.available_bots <= 0 then return nil, nil, nil, true end
        if param.limit <= 0 or param.network_tile_count <= 0 then return end
        local position = Position(tile.position):center()
        if cell.network.surface.find_entity('tile-ghost', position) then goto continue end

        if cell.network.surface.create_entity{
            name = 'tile-ghost',
            ghost_name = param.tile_prototype.name,
            position = position,
            force = cell.network.force
        } then
            cell.network.available_bots = cell.network.available_bots - 1
            param.limit = param.limit - 1
            param.network_tile_count = param.network_tile_count - 1
        end

        ::continue::
    end

end

--- @param param ri.parameter_map
--- @param cell ri.cell_data
Actions['pave_the_world'] = function(param, cell)
    local tile_name = param.prototype.name
    param.network_tile_count = param.network_tile_count or (cell.network.contents[tile_name] or 0)
    if param.network_tile_count <= 0 then return end

    local tiles = cell.network.surface.find_tiles_filtered{
        area = cell.area,
        collision_mask = 'ground-tile',
        force = cell.network.force,
        has_hidden_tile = false,
        limit = max(0, min(param.limit, cell.network.network.available_construction_robots))
    }

    for _, tile in pairs(tiles) do
        if cell.network.available_bots <= 0 then return nil, nil, nil, true end
        if param.limit <= 0 or param.network_tile_count <= 0 then return end

        local position = Position(tile.position):center()
        if cell.network.surface.find_entity('tile-ghost', position) then goto continue end

        if cell.network.surface.create_entity{
            name = 'tile-ghost',
            ghost_name = param.tile_prototype.name,
            position = position,
            force = cell.network.force
        } then
            cell.network.available_bots = cell.network.available_bots - 1
            param.limit = param.limit - 1
            param.network_tile_count = param.network_tile_count - 1
        end

        ::continue::
    end
end

--- @param param ri.parameter_map
--- @param cell ri.cell_data
Actions['strip_the_world'] = function(param, cell)
    -- !API find_tiles_filtered has_tile_ghost/to_be_deconstructed
    local tile_name = param.tile_prototype.name

    local tiles = cell.network.surface.find_tiles_filtered{
        name = tile_name,
        area = cell.area,
        collision_mask = 'ground-tile',
        has_hidden_tile = true,
        limit = max(0, min(param.limit, cell.network.network.available_construction_robots)) * 3
    }

    for _, tile in pairs(tiles) do
        if cell.network.available_bots <= 0 then return nil, nil, nil, true end
        if param.limit <= 0 then return end
        if tile.to_be_deconstructed() then goto continue end
        local position = Position(tile.position):center()
        if cell.network.surface.find_entity('tile-ghost', position) then goto continue end
        if cell.network.surface.find_entity('entity-ghost', position) then goto continue end

        if tile.order_deconstruction(cell.network.force) then
            cell.network.available_bots = cell.network.available_bots - 1
            param.limit = param.limit - 1
        end

        ::continue::
    end
end

return Actions
