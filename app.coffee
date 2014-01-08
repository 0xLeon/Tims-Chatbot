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
http = require 'http'
async = require 'async'
express = require 'express'
request = (require 'request')
request = request.defaults jar: new (require('tough-cookie').CookieJar)(null, false)

# Try to load config
try
	filename = "#{__dirname}/config"
	
	# configuration file was passed via `process.argv`
	filename = (require 'path').resolve process.argv[2] if process.argv[2]?
	
	#filename = fs.realpathSync filename
	
	console.log "Using config '#{filename}'"
	config = require filename
catch e
	console.error """Cannot load config: #{e}"""
	process.exit 1

fatal = (message, err) ->
	if err?
		console.log message, err
	else
		console.log message
	process.exit 1

securityToken = ''
userID = null

fetchSecurityToken = (callback) ->
	request.get config.host + '/index.php', (err, res, body) ->
		fatal 'Cannot fetch security token:', err if err?
		fatal 'Unable to find security token in source' unless [_, securityToken] = body.match /var SECURITY_TOKEN = '([a-f0-9]{40})';/
		do callback if callback?
		
sendLoginRequest = (callback) ->
	request.post config.host + '/index.php/Login/', 
	form: 
		username: config.username
		password: config.password
		t: securityToken
	, (err, res, body) ->
		fatal 'Cannot send login request', err if err?
		fatal 'Login unsuccessful' if (not [_, userID] = body.match /WCF\.User\.init\((\d+), '/) or (userID = parseInt userID) is 0
		console.log 'Logged in as userID', userID
		
		do callback if callback?

joinRoom = (roomID, callback) ->
	request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'join'
		className: 'chat\\data\\room\\RoomAction'
		'parameters[roomID]': roomID
		t: securityToken
	, (err, res, body) ->
		console.log body
		
		do callback if callback?

getRoomList = (callback) ->
	request.post config.host + '/index.php/AJAXProxy/',
	form:
		actionName: 'getRoomList'
		className: 'chat\\data\\room\\RoomAction'
		t: securityToken
	, (err, res, body) ->
		roomList = JSON.parse body
		
		callback roomList.returnValues if callback?

fetchMessages = (callback) ->
	request.get config.host + 'index.php/NewMessages/', (err, res, body) ->
		data = JSON.parse body
		console.log data
		
		callback data if callback?
		
recursiveFetchMessages = (callback) ->
	fetchMessages (data) ->
		callback data if callback
		setTimeout ->
			recursiveFetchMessages callback
		, 5e2
		
fetchSecurityToken ->
	sendLoginRequest ->
		# new session after login, refetch token
		fetchSecurityToken ->
			getRoomList (roomList) ->
				fatal 'No available rooms' if roomList.length is 0
				joinRoom roomList[0].roomID, ->
					do recursiveFetchMessages
