fx_version 'cerulean'
game 'gta5'

version '1.0.0'
repository 'https://github.com/Qbox-project/qbx_truckerjob'

shared_scripts {
	'config.lua',
	'@ox_lib/init.lua',
    '@qbx_core/import.lua',
	'@qbx_core/shared/locale.lua',
	'locales/en.lua',
}

server_script 'server/main.lua'

client_script 'client/main.lua'


modules {
    'qbx_core:playerdata',
    'qbx_core:utils',
}

dependencies {
	'ox_lib'
}

provide 'qb-truckerjob'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
