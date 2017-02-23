###
# Roses handler
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
debug = (require 'debug')('Chatbot:handlers:roses')
db = require '../db'
{ __, __n } = require '../i18n'

queries = { }

onLoad = (callback) ->
	db.serialize ->
		db.run "CREATE TABLE IF NOT EXISTS roses (
			userID INT(10),
			spendable INT(10) DEFAULT 3,
			received INT(10) DEFAULT 0,
			lastJoin INT(10) DEFAULT 0,
			joins INT(10) DEFAULT 0,
			PRIMARY KEY(userID)
		);"
		
		queries['addUser'] = db.prepare "INSERT OR IGNORE INTO roses (userID) VALUES(?)"
		queries['getByID'] = db.prepare "SELECT * FROM roses WHERE userID = ?"
		queries['joinSet'] = db.prepare "UPDATE roses SET spendable = ?, lastJoin = ?, joins = ? WHERE userID = ?"
		queries['rose'] = db.prepare "UPDATE roses SET spendable = ?, received = ? WHERE userID = ?"
		
		callback?()
		
handleMessage = (message, callback) ->
	# Don't match our own messages
	if message.sender is config.userID
		callback?()
		return
		
	if message.type is common.messageTypes.JOIN
		queries['addUser'].run message.sender, (err) ->
			if err?
				callback? err
				return
				
			queries['getByID'].get message.sender, (err, row) ->
				if err?
					callback? err
					return
					
				unless row?
					callback?()
					return
					
				time = Math.floor Date.now() / 1000
				
				if time - row.lastJoin > 86400
					row.lastJoin = time
					row.joins++
					
					if row.joins >= 5
						row.joins = 0
						row.spendable++
						
					queries['joinSet'].run row.spendable, row.lastJoin, row.joins, message.sender, (err) ->
						if err?
							debug "[Join] #{err}"
							callback?()
						else if row.joins is 0
							api.replyTo message, __("You have got %1$s to send to someone. Use “!rose username” to send a rose to someone.", __n("%1$d rose", "%1$d roses", row.spendable)), no, callback
						else
							callback?()
				else
					callback?()
	else if message.message[0] is '!'
		text = message.message[1..].split /\s/
		[ command, parameters ] = [ text.shift(), text.join ' ' ]
		
		switch command
			when 'rose'
				usernames = parameters.split /,/
					.map (item) ->
						item.trim()
					.filter (item) ->
						item isnt ''
						
				if usernames.length == 0
					api.replyTo message, __("No valid username given."), no, callback
					return
					
				if usernames.length > 10
					api.replyTo message, __("You must not enter more than 10 usernames in one command!"), no, callback
					return
				
				async.eachSeries usernames, (username, callback) ->
					db.getUserByUsername username, (err, user) ->
						unless user?
							api.replyTo message, __("Unknown user “%1$s”.", username), no
						else
							sender = {}
							receiver = {}
							
							async.series [
								(callback) -> queries['addUser'].run user.userID,  (err, row) ->
									if err?
										debug "[Rose] #{err}"
										
									callback?()
								(callback) -> queries['getByID'].get message.sender, (err, row) ->
									if err?
										debug "[Rose] #{err}"
									else
										sender = row
										
									callback?()
								(callback) -> queries['getByID'].get user.userID, (err, row) ->
									if err?
										debug "[Rose] #{err}"
									else
										receiver = row
										
									callback?()
							], ->
								if sender?.userID? and receiver?.userID? and sender.spendable > 0
									async.series [
										(callback) -> queries['rose'].run sender.spendable - 1, sender.received, sender.userID, (err, row) ->
											if err?
												debug "[Rose] #{err}"
												
											callback?()
										(callback) -> queries['rose'].run receiver.spendable, receiver.received + 1, receiver.userID, (err, row) ->
											if err?
												debug "[Rose] #{err}"
												
											callback?()
									], ->
										api.replyTo message, __("You’ve sent a rose to %1$s!", user.lastUsername), no
										api.sendMessage "/whisper #{user.lastUsername}, " + __("%1$s sent you a rose!", message.username), no, callback
								else unless sender?.userID?
									api.replyTo message, __("You don’t have any roses!"), no, callback
								else unless receiver?.userID?
									# This SHOULD not happen
									debug "[Rose] Receiver not found?"
									callback?()
				, callback
			when 'roses'
				[ username ] = parameters.split /,/
				username = if username.trim() isnt '' then username.trim() else message.username
				
				db.getUserByUsername username, (err, user) ->
					if user?
						queries['getByID'].get user.userID, (err, row) ->
							if err?
								debug "[Roses] #{err}"
								callback? err
								return
								
							unless row?
								callback?()
								return
								
							if username is message.username
								api.replyTo message, __("You have received %1$s and can spend %2$s", __n("%1$d rose", "%1$d roses", row.received), __n("%1$d rose", "%1$d roses", row.spendable)), no, callback
							else
								api.replyTo message, __("%1$s has received %2$s", username, __n("%1$d rose", "%1$d roses", row.received)), no, callback
					else
						callback?()
			else
				callback?()
	else
		# Not our business
		callback?()
		
unload = (callback) ->
	async.each Object.keys(queries || {}), (key, next) ->
		queries[key].finalize -> delete queries[key]; next?()
	, callback
	
purge = (callback) ->
	db.runHuppedQuery "DROP TABLE roses;", (err) ->
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
