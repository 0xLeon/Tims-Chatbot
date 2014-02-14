###
# Chatbot for Tim's Chat 3
# Copyright (C) 2011 - 2014 Tim Düsterhus
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
###

winston = require 'winston'
winston.remove winston.transports.Console
winston.add winston.transports.Console,
	colorize: yes
	timestamp: yes
	level: 'debug'

winston.info "Starting, PID #{process.pid}"

fs = require 'fs'
async = require 'async'
request = require 'request'
jar = request.jar()
jar._jar.rejectPublicSuffixes = false
request = request.defaults jar: jar

config = require './config'

process.title = "Chatbot (#{config.host})"

common = require './common'
common.request = request

config.host = config.host.replace /\/+$/, ''

config.port ?= 9001
config.ip ?= '0.0.0.0'
config.enableFrontend ?= yes
config.database ?= __dirname + '/storage.sqlite3'

config.locale ?= 'en'

config.securityToken = ''
config.userID = null
config.upSince = new Date()

i18n = require 'i18n'
i18n.configure
	directory: __dirname + '/locales'
i18n.setLocale config.locale

db = require './db'
api = require './api'
handlers = require './handlers'

# gracefully leave chat and exit upon SIGTERM and SIGINT
process.on 'SIGTERM', -> api.leaveChat -> process.exit 0
process.on 'SIGINT', -> api.leaveChat -> process.exit 0

api.fetchSecurityToken -> api.sendLoginRequest ->
	# new session after login, refetch token
	api.fetchSecurityToken -> api.getRoomList (roomList) ->
		# probably no permissions, abort
		common.fatal 'No available rooms' if roomList.length is 0
		
		do (require './frontend').listen if config.enableFrontend
		
		api.joinRoom roomList[0].roomID, ->
			do handlers.loadHandlers
			api.sendMessage i18n.__("I'm here!"), yes, ->
				api.recursiveFetchMessages (data) ->
					async.each data.messages, (item, callback) ->
						handlers.handleMessage item, callback
					, (err) ->
						#console.log "Handled each message"
					async.each data.users, (item, callback) ->
						handlers.handleUser item, callback
					, (err) ->
						#console.log "Handled each message"
