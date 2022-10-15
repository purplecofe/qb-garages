fx_version 'cerulean'
game 'gta5'

description 'QB-Garages'
version '1.0.0'
author 'JDev'

shared_scripts {
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/tc.lua',
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client/main.lua',
    'client/impound.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/impound.lua',
}

lua54 'yes'
