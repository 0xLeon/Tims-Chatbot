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

db = require '../db'
async = require 'async'

addUser = db.prepare "INSERT OR IGNORE INTO users (lastUsername, lastSeen, userID) VALUES (?, ?, ?);";
updateUser = db.prepare "UPDATE users SET lastUsername = ?, lastSeen = ? WHERE userID = ?" 

userQueue = {}

setInterval ->
	_queue = userQueue
	userQueue = {}
	console.log _queue
	
	async.each (v for k, v of _queue), (user, callback) ->
		addUser.run user.username, user.timestamp, user.userID
		updateUser.run user.username, user.timestamp, user.userID
		do callback
	, ->
		console.log "Processed queue", _queue
, 5e3

handleMessage = (message, callback) ->
	userQueue[message.sender] =
		username: message.username
		timestamp: Date.now()
		userID: message.sender
	
	do callback if callback?

handleUser = (user, callback) ->
	userQueue[user.userID] =
		username: user.username
		timestamp: Date.now()
		userID: user.userID
	
	do callback if callback?

unload = (callback) ->
	winston.error "panic() - Going nowhere without my core"
	process.exit 1

module.exports =
	handleMessage: handleMessage
	handleUser: handleUser
	unload: unload