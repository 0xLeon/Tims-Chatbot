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

fetchSecurityToken = (callback) ->
	common.request.get config.host + '/index.php', (err, res, body) ->
		common.fatal 'Cannot fetch security token:', err if err?
		common.fatal 'Unable to find security token in source' unless [_, config.securityToken] = body.match /var SECURITY_TOKEN = '([a-f0-9]{40})';/
		do callback if callback?
		
sendLoginRequest = (callback) ->
	common.request.post config.host + '/index.php/Login/', 
	form: 
		username: config.username
		password: config.password
		t: config.securityToken
	, (err, res, body) ->
		common.fatal 'Cannot send login request', err if err?
		common.fatal 'Login unsuccessful' if (not [_, userID] = body.match /WCF\.User\.init\((\d+), '/) or (config.userID = parseInt userID) is 0
		console.log 'Logged in as userID', config.userID
		
		do callback if callback?

joinRoom = (roomID, callback) ->
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'join'
		className: 'chat\\data\\room\\RoomAction'
		'parameters[roomID]': roomID
		t: config.securityToken
	, (err, res, body) ->
		console.log body
		
		do callback if callback?

getRoomList = (callback) ->
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'getRoomList'
		className: 'chat\\data\\room\\RoomAction'
		t: config.securityToken
	, (err, res, body) ->
		roomList = JSON.parse body
		
		callback roomList.returnValues if callback?

leaveChat = (callback) ->
	common.request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'leave'
		className: 'chat\\data\\room\\RoomAction'
		t: config.securityToken
	, -> do callback if callback?

fetchMessages = (callback) ->
	common.request.get config.host + 'index.php/NewMessages/', (err, res, body) ->
		data = JSON.parse body
		console.log data
		
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

module.exports =
	fetchSecurityToken: fetchSecurityToken
	sendLoginRequest: sendLoginRequest
	joinRoom: joinRoom
	getRoomList: getRoomList
	leaveChat: leaveChat
	fetchMessages: fetchMessages
	recursiveFetchMessages: recursiveFetchMessages
	sendMessage: sendMessage
