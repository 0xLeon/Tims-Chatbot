###
# Dictionary for Tims Chat 3
#
# This handler provides a dictionary function.
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

common = require '../common'
config = require '../config'
handlers = require '../handlers'
api = require '../api'
async = require 'async'
winston = require 'winston'
debug = (require 'debug')('Chatbot:handlers:dictionary')
db = require '../db'
{ __, __n } = require '../i18n'

lookupQuery = addQuery = delQuery = listQuery = infoQuery = null

onLoad = (callback) ->
	db.serialize ->
		async.series [
			(callback) ->
				db.run "CREATE TABLE IF NOT EXISTS dictionary (
					key VARCHAR(255),
					value MEDIUMTEXT,
					userID INT(10),
					time INT(10),
					PRIMARY KEY(key)
				);", callback
				
			(callback) -> lookupQuery = db.prepare "SELECT value FROM dictionary WHERE key = ?", callback
			(callback) -> addQuery = db.prepare "INSERT OR REPLACE INTO dictionary (key, value, userID, time) VALUES (?, ?, ?, ?)", callback
			(callback) -> delQuery = db.prepare "DELETE FROM dictionary WHERE key = ?", callback
			(callback) -> listQuery = db.prepare "SELECT key FROM dictionary ORDER BY key ASC", callback
			(callback) -> infoQuery = db.prepare "SELECT dictionary.*, users.lastUsername FROM dictionary LEFT JOIN users ON dictionary.userID = users.userID WHERE key = ?", callback
		], callback
		
handleMessage = (message, callback) ->
	# Don't match our own messages
	if message.sender is config.userID
		callback?()
		return
		
	if message.message[0] is '-' # lookup key in dictionary
		key = message.message[1..].toLowerCase()
		
		lookupQuery.get key, (err, row) ->
			if err?
				debug "Error while checking key “#{key}”: #{err}"
			else if row?
				reply = "[#{key}] #{row.value}"

				if message.type is common.messageTypes.WHISPER
					api.replyTo message, reply, no, callback
				else
					api.sendMessage reply, no, message.roomID, callback
			else
				callback?()
	else if message.message[0] is '.' # check other dictionary commands
		text = message.message[1..].split /\s/
		[ command, parameters ] = [ text.shift(), text.join ' ' ]
		
		switch command
			when 'add'
				db.checkPermissionByMessage message, 'dictionary.add', (hasPermission) ->
					if hasPermission
						[ key, value... ] = parameters.split ' '
						key = key.toLowerCase()
						value = value.join(' ').trim()
						
						if value[0] is '?' # Nope
							return callback?()
							
						addQuery.run key, value, message.sender, Date.now(), (err) ->
							if err?
								debug "Error while adding key “#{key}” with value “#{value}”: #{err}"
								api.replyTo message, __("Failed while adding “%1$s” to dictionary.", key), no, callback
							else
								api.replyTo message, __("Successfully added “%1$s” to dictionary.", key), no, callback
					else
						callback?()
			when 'del'
				db.checkPermissionByMessage message, 'dictionary.del', (hasPermission) ->
					if hasPermission
						key = parameters.split(' ')[0].toLowerCase()
						
						delQuery.run key, (err) ->
							if err?
								debug "Error while deleting key “#{key}”: #{err}"
								api.replyTo message, __("Failed while deleting “%1$s” from dictionary.", key), no, callback
							else
								api.replyTo message, __("Successfully deleted “%1$s” from dictionary.", key), no, callback
					else
						callback?()
			when 'list'
				db.checkPermissionByMessage message, 'dictionary.list', (hasPermission) ->
					if hasPermission
						listQuery.all (err, rows) ->
							if err?
								debug "Error reading from database: #{err}"
							else if rows
								api.replyTo message, __("Saved entries: %1$s", (row.key for row in rows).join ', '), no, callback
							else
								callback?()
					else
						callback?()
			when 'info'
				db.checkPermissionByMessage message, 'dictionary.info', (hasPermission) ->
					if hasPermission
						key = parameters.split(' ')[0].toLowerCase()
						
						infoQuery.get key, (err, row) ->
							if err?
								debug "Error while getting info of key “#{key}”: #{err}"
								api.replyTo message, __("Failed getting info of “%1$s”.", key), no, callback
							else if not row?.key?
								api.replyTo message, __("Key “%1$s” not found.", key), no, callback
							else
								api.replyTo message, __("""
									Key: %1$s
									Value: %2$s
									User ID: %3$d
									Last known username: %4$s
									Time: %5$s
								""", key, row.value, row.userID, row.lastUsername, new Date(row.time).toISOString()), no, callback
					else
						callback?()
			else
				callback?()
	else
		# Not our business
		callback?()
		
unload = (callback) ->
	async.parallel [
		(callback) -> lookupQuery.finalize -> lookupQuery = null; callback?()
		(callback) -> addQuery.finalize -> addQuery = null; callback?()
		(callback) -> delQuery.finalize -> delQuery = null; callback?()
		(callback) -> listQuery.finalize -> listQuery = null; callback?()
		(callback) -> infoQuery.finalize -> infoQuery = null; callback?()
	], callback
	
purge = (callback) ->
	db.runHuppedQuery "DROP TABLE dictionary;", (err) ->
		if err?
			debug err
			callback? err
		else
			callback?()
			
module.exports =
	handleMessage: handleMessage
	handleUser: (user, callback) -> callback?()
	unload: unload
	onLoad: onLoad
	purge: purge
