local Recipe = require('__stdlib__/stdlib/data/recipe')

if mods['boblibrary'] then
    local key = 'bobmods-logistics-disableroboports'
    if settings["startup"][key] and settings["startup"][key].value then
        Recipe('roboport-interface'):replace_ingredient('roboport', 'bob-logistic-zone-expander')
    end
end
