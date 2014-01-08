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
request = (require 'request').defaults jar: new (require('tough-cookie').CookieJar)(null, false)
config = require './config'

process.title = "Chatbot (#{config.host})"

common = require './common'
common.request = request

config.port ?= 9001
config.ip ?= '0.0.0.0'

config.securityToken = ''
config.userID = null
config.upSince = new Date()

frontend = require './frontend'
api = require './api'
handlers = require './handlers'

process.on 'SIGTERM', -> api.leaveChat -> process.exit 0
process.on 'SIGINT', -> api.leaveChat -> process.exit 0

api.fetchSecurityToken -> api.sendLoginRequest ->
	# new session after login, refetch token
	api.fetchSecurityToken -> api.getRoomList (roomList) ->
		common.fatal 'No available rooms' if roomList.length is 0
		do frontend.listen
		api.joinRoom roomList[0].roomID, ->
			do handlers.loadHandlers
			api.sendMessage "I'm here!", yes, ->
				api.recursiveFetchMessages (data) ->
					async.each data.messages, (item, callback) ->
						handlers.handle item, callback
					, (err) ->
						console.log "Handled each message"
