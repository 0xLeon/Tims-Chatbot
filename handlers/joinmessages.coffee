###
# Join messages for Tims Chat 3
#
# This handler provides simple join messages.
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
debug = (require 'debug')('Chatbot:handlers:joinMessages')
db = require '../db'
{ __, __n } = require '../i18n'

getQuery = setQuery = delQuery = null

onLoad = (callback) ->
	db.serialize ->
		db.run "CREATE TABLE IF NOT EXISTS joinMessages (
			userID INT(10),
			value MEDIUMTEXT,
			PRIMARY KEY(userID)
		);"
		
		getQuery = db.prepare "SELECT joinMessages.value, users.* FROM users LEFT JOIN joinMessages ON users.userID = joinMessages.userID WHERE users.lastUsername = ?"
		setQuery = db.prepare "INSERT OR REPLACE INTO joinMessages (userID, value) VALUES (?, ?)"
		delQuery = db.prepare "DELETE FROM joinMessages WHERE userID = ?"
		
handleMessage = (message, callback) ->
	# Don't match our own messages
	if message.sender is config.userID
		callback?()
		return
		
	if message.message[0] is '!'
		text = message.message[1..].split /\s/
		[ command, parameters ] = [ text.shift(), text.join ' ' ]
		
		switch command
			when 'quote'
				[ username ] = parameters.split /,/
				username = message.username unless username? and username
				
				getQuery.get username, (err, row) ->
					if err? or not row?.value?
						debug "Error: #{err}"
						
						if username is message.username
							api.replyTo message, __("You currently don't have a quote set."), no, callback
						else
							api.replyTo message, __("User “%1$s” has no quote set.", username), no, callback
					else
						api.replyTo message, __("[%1$s] %2$s", username, row.value), yes, callback
			when 'setquote'
				setQuery.run message.sender, parameters, (err) ->
					if err?
						debug "Error"
						api.replyTo message, __("User %1$s has no quote set.", row.users.lastUsername), no, callback
					else
						api.replyTo message, __("Your quote has been set to: “%1$s”", parameters), yes, callback
			when 'delquote'
				callback?()
			when 'forcequote'
				callback?()
			when 'wipequote'
				callback?()
			else
				callback?()
	else
		# Not our business
		callback?()
		
unload = (callback) ->
	async.parallel [
		(callback) -> getQuery.finalize -> getQuery = null; callback?()
		(callback) -> setQuery.finalize -> setQuery = null; callback?()
		(callback) -> delQuery.finalize -> delQuery = null; callback?()
	], callback
	
purge = (callback) ->
	db.runHuppedQuery "DROP TABLE joinMessages;", (err) ->
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
