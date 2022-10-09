fx_version 'cerulean'
game       'gta5'

version '1.0.0'
repository 'https://github.com/QBCore-Remastered/qb-truckerjob'

shared_scripts {
	'config.lua',
	'@qb-core/shared/locale.lua',
	'locales/en.lua',
	'@ox_lib/init.lua'
}

client_script 'client/main.lua'

server_script 'server/main.lua'

dependencies {
	'ox_lib',
	'ox_target'
}

lua54 'yes'