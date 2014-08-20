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

# This objects holds the currently running timers
timers = {}

# This objects holds the currently running votes
votes = {}

###
# Sorts an object by value
#
# @param	{Object} obj The object being sorted.
# @param	{String} order The sorting order “ASC” or “DESC”.
# @return	{Array} A sorted containing objects of the form {key: 'ABC', value: 10} or an empty array on invalid input.
###
sortObject = (obj, order = 'DESC') ->
	return [] unless typeof obj is 'object'
	
	Object.keys(obj).sort (a, b) ->
		if order is 'DESC'
			if obj[a] > obj[b]
				-1
			else if obj[a] < obj[b]
				1
			else
				0
		else # 'ASC'
			if obj[a] > obj[b]
				1
			else if obj[a] < obj[b]
				-1
			else
				0
	.map (key) ->
		key: key,
		value: obj[key]
		
handleMessage = (message, callback) ->
	# Don't match our own messages
	if message.sender is config.userID
		callback?()
		return
		
	# Messages for this handler must start with an exclamation mark
	unless message.message[0] is '!'
		callback?()
		return
		
	text = message.message[1..].split /\s/
	[ command, parameters ] = [ text.shift(), text.join ' ' ]
	
	switch command
		when 'ping'
			date = new Date()
			api.replyTo message, __("Pong! Message time: %1$s; My time: %2$d:%3$d:%4$d; Difference: %5$d seconds", message.formattedTime, date.getHours(), date.getMinutes(), date.getSeconds(), date.getTime() / 1000 - message.time), no, message.roomIDID, callback
		when 'timer'
			db.checkPermissionByMessage message, 'util.timer', (hasPermission) ->
				unless hasPermission
					callback?()
					return
					
				# Prevent starting of multiple timers while waiting for “api.replyTo”
				if timers[message.roomID]? and timers[message.roomID] is 'preparing'
					api.replyTo message, __("There is already a timer being prepared."), no, callback
				else if timers[message.roomID]? # Just one concurrent timer is allowed per room
					api.replyTo message, __("There is already a timer running in this room."), no, callback
				else
					[ seconds ] = parameters.split /[, ]/
					seconds = parseInt seconds
					
					# Default to 60 seconds on invalid input
					seconds = 60 if isNaN(seconds) or seconds <= 0
					
					timers[message.roomID] = 'preparing' # prevent starting of multiple timers while waiting for “api.replyTo”
					api.sendMessage __("Starting timer of %1$d seconds.", seconds), no, message.roomID, ->
						timers[message.roomID] = setTimeout ->
							delete timers[message.roomID]
							api.sendMessage __("Time’s up!"), no, message.roomID, null
						, seconds * 1e3
						
						callback?()
		when 'cancelTimer'
			db.checkPermissionByMessage message, 'util.cancelTimer', (hasPermission) ->
				unless hasPermission
					callback?()
					return
					
				if timers[message.roomID]? and timers[message.roomID] isnt 'preparing'
					clearTimeout timers[message.roomID]
					delete timers[message.roomID]
					
					api.replyTo message, __("The timer running in this room has been canceled."), no, callback
				else
					api.replyTo message, __("There is no timer running in this room."), no, callback
		when 'startVote'
			db.checkPermissionByMessage message, 'util.startVote', (hasPermission) ->
				unless hasPermission
					callback?()
					return
					
				# Prevent starting of multiple votes while waiting for “api.replyTo”
				if votes[message.roomID]? and votes[message.roomID].timeout is 'preparing'
					api.replyTo message, __("There is already a vote being prepared."), no, callback
				else if votes[message.roomID]? # Just one concurrent vote is allowed per room
					api.replyTo message, __("There is already a vote running in this room."), no, callback
				else
					[ seconds ] = parameters.split /[, ]/
					seconds = parseInt seconds
					
					# Default to 60 seconds on invalid input
					seconds = 60 if isNaN(seconds) or seconds <= 0
					
					# Prepare the vote object
					votes[message.roomID] =
						timeout: 'preparing' # Prevent starting of multiple votes while waiting for “api.replyTo”
						votes: {}
						voters: []
						timeoutFunction: null
						
					# Start the vote after this message has been sent
					api.sendMessage __("Starting vote (duration: %1$d seconds).", seconds), no, message.roomID, ->
						# Define the “onTimeout” function (this is also used in “stopVote”)
						votes[message.roomID].timeoutFunction = ->
							clearTimeout votes[message.roomID].timeout
							delete votes[message.roomID].timeout
							delete votes[message.roomID].timeoutFunction
							
							result = ''
							# Build a sorted list (DESC) of votes/values
							for key, option of sortObject votes[message.roomID].votes
								do (key, option) ->
									result += "“#{option.key}”: #{option.value}\n"
									
							api.sendMessage __("Vote’s ended!\nResult:") + "\n" + result, no, message.roomID, null, ->
								delete votes[message.roomID]
								
						# Set the timeout and assign the previously defined function to it
						votes[message.roomID].timeout = setTimeout votes[message.roomID].timeoutFunction, seconds * 1e3
						
						callback?()
		when 'vote'
			option = parameters.trim().toLowerCase()
			
			# Stop further processing of this “vote command” if no vote is running or the voter has already voted during the vote period
			if not votes[message.roomID]? or option is '' or votes[message.roomID].voters[message.sender]?
				callback?()
				return
				
			# Mark “voter” like “has voted during this vote”
			votes[message.roomID].voters[message.sender] = true
			
			# Unless the given vote option is known add it to the voted options
			unless votes[message.roomID].votes[option]?
				votes[message.roomID].votes[option] = 1
			else
				votes[message.roomID].votes[option]++
				
			callback?()
		when 'stopVote'
			db.checkPermissionByMessage message, 'util.startVote', (hasPermission) ->
				unless hasPermission
					callback?()
					return
					
				# Run the “onTimeout” function of the currently running vote for this room
				votes[message.roomID].timeoutFunction() if votes[message.roomID]?.timeoutFunction? and typeof votes[message.roomID].timeoutFunction is 'function'
				
				callback?()
		else
			callback?()

module.exports =
	handleMessage: handleMessage
	handleUser: (user, callback) -> callback?()
	unload: (callback) -> callback?()
