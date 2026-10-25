fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbfuel'
author 'qbcore2'
version '1.0.0'
description 'Vehicle fuel and EV charging for the qblib test server'

provide 'LegacyFuel'

dependency 'qblib'
dependency 'qbcore'
dependency 'qbtarget'

shared_script '@qblib/init.lua'

shared_scripts {
    'config.lua',
    'shared/fuel.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'
