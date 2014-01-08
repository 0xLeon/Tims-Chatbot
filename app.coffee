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

fs = require 'fs'
async = require 'async'
request = (require 'request').defaults jar: new (require('tough-cookie').CookieJar)(null, false)
config = require './config'

common = require './common'
common.request = request

config.port ?= 9001
config.ip ?= '0.0.0.0'
config.securityToken = ''
config.userID = null

frontend = require './frontend'
api = require './api'

process.on 'SIGTERM', -> api.leaveChat -> process.exit 0
process.on 'SIGINT', -> api.leaveChat -> process.exit 0

api.fetchSecurityToken -> api.sendLoginRequest ->
	# new session after login, refetch token
	api.fetchSecurityToken -> api.getRoomList (roomList) ->
		common.fatal 'No available rooms' if roomList.length is 0
		do frontend.listen
		api.joinRoom roomList[0].roomID, ->
			do api.recursiveFetchMessages
