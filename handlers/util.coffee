###
# Util handler
# 
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

api = require '../api'
async = require 'async'
common = require '../common'
config = require '../config'
db = require '../db'
debug = (require 'debug')('Chatbot:handlers:util')
handlers = require '../handlers'
winston = require 'winston'
{ __, __n } = require '../i18n'

timers = {}

handleMessage = (message, callback) ->
	# Don't match our own messages
	if message.sender is config.userID
		callback?()
		return
		
	if message.message[0] is '!'
		text = message.message[1..].split /\s/
		[ command, parameters ] = [ text.shift(), text.join ' ' ]
		
		switch command
			when 'ping'
				date = new Date()
				api.replyTo message, __("Pong! Message time: %1$s; My time: %2$d:%3$d:%4$d; Difference: %5$d seconds", message.formattedTime, date.getHours(), date.getMinutes(), date.getSeconds(), date.getTime() / 1000 - message.time), no, message.roomID, callback
			when 'timer'
				db.checkPermissionByMessage message, 'util.timer', (hasPermission) ->
					if hasPermission
						if timers[message.room]? and timers[message.room] is 'preparing'
							api.replyTo message, __("There is already a timer being prepared."), no, callback
						else if timers[message.room]?
							api.replyTo message, __("There is already a timer running in this room."), no, callback
						else
							[ seconds ] = parameters.split /[, ]/
							seconds = parseInt seconds
							
							return callback()? unless seconds > 0
							
							timers[message.room] = 'preparing' # prevent starting of multiple timers while waiting for “api.replyTo”
							api.sendMessage __("Starting timer of %1$d seconds.", seconds), no, message.room, ->
								timers[message.room] = setTimeout ->
									delete timers[message.room]
									api.sendMessage __("Time’s up!"), no, message.room, null
								, seconds * 1e3
								
							callback?()
					else
						callback?()
			when 'cancelTimer'
				db.checkPermissionByMessage message, 'util.cancelTimer', (hasPermission) ->
					if hasPermission
						if timers[message.room]? and timers[message.room] isnt 'preparing'
							clearTimeout timers[message.room]
							delete timers[message.room]
							
							api.replyTo message, __("The timer running in this room has been canceled."), no, callback
						else
							api.replyTo message, __("There is no timer running in this room."), no, callback
					else
						callback?()
			else
				callback?()
	else
		callback?()

module.exports =
	handleMessage: handleMessage
	handleUser: (user, callback) -> callback?()
	unload: (callback) -> callback?()
