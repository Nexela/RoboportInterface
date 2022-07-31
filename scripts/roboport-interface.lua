local Actions = require('scripts/actions')
local Event = require('__stdlib__/stdlib/event/event')
local Area = require('__stdlib__/stdlib/area/area') ---@diagnostic disable-line: unused-local
local Position = require('__stdlib__/stdlib/area/position')

local math = require('__stdlib__/stdlib/utils/math')

local abs, clamp = math.abs, math.clamp
local for_n_of = require('scripts/for_n_of')
local parse_parameters = require('scripts/parse_parameters')

local CELLS_PER_TICK = 1
local TICKS_BETWEEN_CELLS = 10
local CHANNEL_SIGNAL = { name = 'interface-signal-roboport-channel', type = 'virtual' }

--- @param interface LuaEntity
local function build_network_table(interface)
    local unit_number = interface.unit_number --[[@as uint]]
    if global.running_interfaces[unit_number] then return end

    local behaviour = interface.get_control_behavior()
    ---@cast behaviour LuaConstantCombinatorControlBehavior
    if not (behaviour and behaviour.enabled) then return end

    local parameters, settings, action_count = parse_parameters(behaviour.parameters)
    if action_count == 0 then return end

    local port = interface.surface.find_entity('roboport-interface-main', interface.position)
    if not port then return end

    local network = port.logistic_network
    if not (network and network.all_construction_robots > 0) then return end

    local network_cells = network.cells
    local num_cells_to_search = (settings['interface-signal-roboport-count'] and settings['interface-signal-roboport-count'].count) or #network_cells
    if num_cells_to_search <= 0 then return end

    local bot_utilization_setting = (settings['interface-signal-bot-utilization'] and settings['interface-signal-bot-utilization'].count or 100) / 100
    local utilization = clamp(abs(bot_utilization_setting), 0, 1) --[[@as float]]
    local available_bots = network.available_construction_robots * utilization
    if available_bots <= 0 then return end

    local channel = (settings['interface-signal-roboport-channel'] and settings['interface-signal-roboport-channel'].count) or 0
    local enemy_range_offset = (settings['interface-signal-enemy-range'] and settings['interface-signal-enemy-range'].count) or 0

    --- Holds all the network data
    --- @class ri.network_data
    local network_data = {
        unit_number = unit_number,
        interface = interface,
        surface = interface.surface,
        force = network.force,
        parameters = parameters,
        contents = network.get_contents(),
        network = network,
        utilization = utilization,
        available_bots = available_bots
    }

    local cell_group = {} ---@type ri.cell_data[]
    local cell_count = 0
    for _, cell in pairs(network_cells) do
        if cell_count == num_cells_to_search then break end

        local radius = cell.construction_radius
        if cell.mobile or radius == 0 then goto continue end

        local owner = cell.owner
        if channel ~= 0 and channel ~= owner.get_merged_signal(CHANNEL_SIGNAL) then goto continue end

        local position = Position(owner.position)
        cell_count = cell_count + 1

        --- Holds all the cell data
        --- @class ri.cell_data
        local cell_data = {
            network_data = network_data,
            cell = cell,
            owner = owner,
            position = position, ---@type MapPosition
            area = position:expand_to_area(radius), ---@type BoundingBox
            enemy_radius = radius + enemy_range_offset,
            has_enemy = false
        }

        cell_group[cell_count] = cell_data
        ::continue::
    end
    if cell_count == 0 then return end

    global.running_interfaces[unit_number] = cell_group
end

do -- Events
    --- @param event on_tick
    local function on_tick(event)
        if event.tick % TICKS_BETWEEN_CELLS ~= 0 then return end
        for interface_number, cell_group in pairs(global.running_interfaces) do
            local index, _, finished = for_n_of(cell_group, global.index[interface_number], CELLS_PER_TICK, Actions.Run)
            global.index[interface_number] = index
            if finished then
                global.running_interfaces[interface_number] = nil
                global.index[interface_number] = index

            end
        end
    end

    Event.register(defines.events.on_tick, on_tick)


    -- There is where all the magic happens
    -- Check signals, then execute the actions.
    --- @param event on_sector_scanned
    local function on_sector_scanned(event)
        if event.radar.name == 'roboport-interface-scanner' then
            local entity = event.radar
            local interface = entity.surface.find_entity('roboport-interface-cc', entity.position)
            return interface and build_network_table(interface)
        end
    end

    Event.register(defines.events.on_sector_scanned, on_sector_scanned)

    -- Build the interface, after built check the area around it for interface components to revive or create.
    local function build_roboport_interface(event)
        local interface = event.created_entity or event.entity --- @type LuaEntity|nil
        if interface and interface.name == 'roboport-interface-main' then
            local pos, force = interface.position, interface.force
            local cc, ra

            for _, entity in pairs(interface.surface.find_entities_filtered { position = pos, force = force }) do
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
            if not (cc and cc.valid) then
                cc = interface.surface.create_entity { name = 'roboport-interface-cc', position = pos, force = force }
            end
            if not (ra and ra.valid) then
                ra = interface.surface.create_entity { name = 'roboport-interface-scanner', position = pos, force = force }
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
            local filter = { position = interface.position, force = interface.force }
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

    local function on_init()
        global.running_interfaces = {} ---@type {[uint]: ri.cell_data}
        global.index = {} ---@type {[uint]: any}
    end

    Event.on_init(on_init)

end
