local Event = require('__stdlib__/stdlib/event/event').set_protected_mode(true)

local ev = defines.events
Event.build_events = { ev.on_built_entity, ev.on_robot_built_entity, ev.script_raised_built, ev.script_raised_revive, ev.on_entity_cloned }
Event.mined_events = { ev.on_pre_player_mined_item, ev.on_robot_pre_mined, ev.script_raised_destroy }

require('scripts/roboport-interface')

remote.add_interface(script.mod_name, require('__stdlib__/stdlib/scripts/interface'))
-- commands.add_command(script.mod_name, 'Roboport Interface commands', require('scripts/commands'))
