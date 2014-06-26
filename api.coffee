
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

common = require './common'
config = require './config'
winston = require 'winston'
debug = (require 'debug')('Chatbot:api')

# attempts to retrieve the current security token
# calls the callback without parameters afterwards
fetchSecurityToken = (callback) ->
	debug "Fetching security token..."
	common.request.get config.host + '/index.php', (err, res, body) ->
		common.fatal 'Cannot fetch security token:', err if err?
		common.fatal 'Unable to find security token in source' unless [_, config.securityToken] = body.match /var SECURITY_TOKEN = '([a-f0-9]{40})';/
		debug "Done, Security token is: #{config.securityToken}"
		callback?()

# attempts to login the user, will save the userID in config.userID
# calls the callback without parameters afterwards
sendLoginRequest = (callback) ->
	debug "Logging in as #{config.username}..."
	common.request.post config.host + '/index.php/Login/', 
	form: 
		username: config.username
		password: config.password
		t: config.securityToken
	, (err, res, body) ->
		common.fatal 'Cannot send login request', err if err?
		common.fatal 'Login unsuccessful' if (not [_, userID] = body.match /WCF\.User\.init\((\d+), '/) or (config.userID = parseInt userID) is 0
		winston.info 'Logged in as userID', config.userID
		
		callback?()

# attempts to join the room with the given roomID
# calls the callback without parameters if everything was successful
# and with a string as the first parameter when something failed
joinRoom = (roomID, callback) ->
	debug "Joining room #{roomID}"
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'join'
		className: 'chat\\data\\room\\RoomAction'
		'parameters[roomID]': roomID
		t: config.securityToken
	, (err, res, body) ->
		data = (JSON.parse body).returnValues
		
		if data.errorMessage?
			if data.fieldName is 'roomID'
				winston.error "Room is invalid"
				callback 'invalid' if callback?
			else
				winston.error "Unexpected error while joining", data
				process.exit 1
		else
			debug "Done, room title is #{data.title}"
			callback?()

# retrieves the roomlist and calls the callback with the roomList as
# first parameter afterwards
getRoomList = (callback) ->
	debug "Fetching roomlist..."
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'getRoomList'
		className: 'chat\\data\\room\\RoomAction'
		t: config.securityToken
	, (err, res, body) ->
		roomList = (JSON.parse body).returnValues
		debug "Found #{roomList.length} rooms"
		callback roomList if callback?

# Leaves the chat
# calls the callback without parameters afterwards
leaveChat = (callback) ->
	winston.info "Leaving chat..."
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'leave'
		className: 'chat\\data\\room\\RoomAction'
		t: config.securityToken
	, -> callback?()

# Fetches new messages and calls the callback with the retrieved data object
fetchMessages = (callback) ->
	common.request.get config.host + '/index.php/NewMessages/', (err, res, body) ->
		try
			data = JSON.parse body
		catch e
			winston.error "Invalid JSON returned by NewMessages", body
			process.exit 1
		
		callback data if callback?

# Permanently fetches messages with a delay of half a second between requests
recursiveFetchMessages = (callback) ->
	fetchMessages (data) ->
		callback data if callback
		setTimeout ->
			recursiveFetchMessages callback
		, 5e2

# sends a message with `message` as the content and the given
# smiley status and calls the callback without any parameters afterwards
sendMessage = (message, enableSmilies = yes, callback) ->
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'send'
		className: 'chat\\data\\message\\MessageAction'
		'parameters[text]': message
		'parameters[enableSmilies]': if enableSmilies then 1 else 0
		t: config.securityToken
	, -> callback?()

# replies (i.e. whispers to the sender) to the given message. See `sendMessage`
replyTo = (message, reply, enableSmilies = yes, callback) -> sendMessage "/whisper #{message.username}, #{reply}", enableSmilies, callback

module.exports =
	fetchSecurityToken: fetchSecurityToken
	sendLoginRequest: sendLoginRequest
	joinRoom: joinRoom
	getRoomList: getRoomList
	leaveChat: leaveChat
	fetchMessages: fetchMessages
	recursiveFetchMessages: recursiveFetchMessages
	sendMessage: sendMessage
	replyTo: replyTo
