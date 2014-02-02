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

fetchSecurityToken = (callback) ->
	winston.debug "Fetching security token..."
	common.request.get config.host + '/index.php', (err, res, body) ->
		common.fatal 'Cannot fetch security token:', err if err?
		common.fatal 'Unable to find security token in source' unless [_, config.securityToken] = body.match /var SECURITY_TOKEN = '([a-f0-9]{40})';/
		winston.debug "Done, Security token is:", config.securityToken
		do callback if callback?
		
sendLoginRequest = (callback) ->
	winston.debug "Logging in as #{config.username}..."
	common.request.post config.host + '/index.php/Login/', 
	form: 
		username: config.username
		password: config.password
		t: config.securityToken
	, (err, res, body) ->
		common.fatal 'Cannot send login request', err if err?
		common.fatal 'Login unsuccessful' if (not [_, userID] = body.match /WCF\.User\.init\((\d+), '/) or (config.userID = parseInt userID) is 0
		winston.info 'Logged in as userID', config.userID
		
		do callback if callback?

joinRoom = (roomID, callback) ->
	winston.debug "Joining room #{roomID}"
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
			winston.debug "Done, room title is", data.title
			do callback if callback?

getRoomList = (callback) ->
	winston.debug "Fetching roomlist..."
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'getRoomList'
		className: 'chat\\data\\room\\RoomAction'
		t: config.securityToken
	, (err, res, body) ->
		roomList = (JSON.parse body).returnValues
		winston.info "Found #{roomList.length} rooms"
		callback roomList if callback?

leaveChat = (callback) ->
	winston.info "Leaving chat..."
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'leave'
		className: 'chat\\data\\room\\RoomAction'
		t: config.securityToken
	, -> do callback if callback?

fetchMessages = (callback) ->
	common.request.get config.host + 'index.php/NewMessages/', (err, res, body) ->
		data = JSON.parse body
		
		callback data if callback?
		
recursiveFetchMessages = (callback) ->
	fetchMessages (data) ->
		callback data if callback
		setTimeout ->
			recursiveFetchMessages callback
		, 5e2

sendMessage = (message, enableSmilies = yes, callback) ->
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'send'
		className: 'chat\\data\\message\\MessageAction'
		'parameters[text]': message
		'parameters[enableSmilies]': if enableSmilies then 1 else 0
		t: config.securityToken
	, -> do callback if callback?

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
