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
common = require '../common'
api = require '../api'
async = require 'async'
crypto = require 'crypto'
config = require '../config'
{ __, __n } = require '../i18n'

addUser = db.prepare "INSERT OR IGNORE INTO users (lastUsername, lastSeen, userID) VALUES (?, ?, ?);";
updateUser = db.prepare "UPDATE users SET lastUsername = ?, lastSeen = ? WHERE userID = ?" 

userQueue = {}

setInterval ->
	_queue = userQueue
	userQueue = {}
	
	async.each (v for k, v of _queue), (user, callback) ->
		addUser.run user.username, user.timestamp, user.userID
		updateUser.run user.username, user.timestamp, user.userID
		do callback
, 5e3

handleMessage = (message, callback) ->
	userQueue[message.sender] =
		username: message.username
		timestamp: Date.now()
		userID: message.sender
	
	if message.message.substring(0, 1) isnt '*'
		# ignore messages that don't start with an asterisk
		callback?()
		return
	
	text = (message.message.substring 1).split /\s/
	[ command, parameters ] = [ text.shift(), text.join ' ' ]
	
	switch command
		when 'getPassword'
			if config.enableFrontend
				crypto.randomBytes 20, (ex, buf) ->
					token = (buf.toString 'hex').substring 0, 20
					db.run "UPDATE users SET password = ? WHERE userID = ?", token, message.sender
					
					api.replyTo message, __("Your password is: %s", token), no, callback
			else
				callback?()
		when 'about'
			api.replyTo message, __("This is Tim’s Chatbot.\nIt is licensed under the terms of the GNU Affero General Public License. You can obtain a copy of the Chatbot at https://github.com/wbbaddons/Tims-Chatbot."), no, callback
		when 'getStats'
			db.checkPermissionByMessage message, 'core.getStats', (hasPermission) ->
				if hasPermission
					api.replyTo message, __("Statistics:\nUp since: #{config.upSince} (#{process.uptime()} seconds)\nMemory Usage: #{process.memoryUsage().rss / 1024} KiB"), no, callback
				else
					callback?()
		else
			callback?()

handleUser = (user, callback) ->
	userQueue[user.userID] =
		username: user.username
		timestamp: Date.now()
		userID: user.userID
	
	callback?()

unload = (callback) -> common.fatal "panic() - Going nowhere without my core"

module.exports =
	handleMessage: handleMessage
	handleUser: handleUser
	unload: unload
