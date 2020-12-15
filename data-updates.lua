local Recipe = require('__stdlib__/stdlib/data/recipe')

if mods['boblibrary'] then
    if settings.get_startup('bobmods-logistics-disableroboports') then
        Recipe('roboport-interface'):replace_ingredient('roboport', 'bob-logistic-zone-expander')
    end
end
