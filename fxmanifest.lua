fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_fuel'
-- Keep the legacy resource name resolvable for exports['qbfuel'] callers.
provide 'qbfuel'
author 'qbcore2'
version '1.0.0'
description 'Vehicle fuel and EV charging for the kora_lib test server'

provide 'LegacyFuel'

dependency 'kora_lib'
dependency 'kora_core'
dependency 'kora_target'

shared_script '@kora_lib/init.lua'

shared_scripts {
    'config.lua',
    'shared/fuel.lua',
}

client_scripts {
    'client/main.lua',
    'client/blips.lua',
}
server_script 'server/main.lua'
