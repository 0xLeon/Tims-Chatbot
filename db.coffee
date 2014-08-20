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

config = require './config'
winston = require 'winston'
debug = (require 'debug')('Chatbot:db')
api = require './api'
{ __, __n } = require './i18n'

sqlite = require 'sqlite3'
do sqlite.verbose if process.env.DEBUG

db = new sqlite.Database config.database

do ->
	# This monkey patches sqlite.Database.prepare to support “hupped queries”
	# Hupped queries will finalize all open prepared statements and reprepare them
	# afterwards.
	# Hupped queries are primarily meant to be used for queries that DROP TABLEs as
	# table dropping only succeeds when no query is open.
	# The name is inspired by unix daemons reloading their configuration once they
	# encounter a SIGHUP signal
	
	i = 0
	queries = {}
	oldPrepare = db.prepare
	db.prepare = (sql, parameters..., callback) ->
		myID = i++
		parameters.unshift sql
		
		query = null
		
		# (re)prepares the query
		hup = (callback) ->
			# copy parameters array
			tmp = do parameters.slice
			
			# append the given callback
			tmp.push callback
			
			# prepare the query
			query = oldPrepare.apply db, tmp
			
		hup callback
		
		returnValue =
			bind: (parameters...) -> query.bind.apply query, parameters
			reset: (parameters...) -> query.reset.apply query, parameters
			finalize: (parameters...) ->
				# remove query cache
				delete queries[myID]
				query.finalize.apply query, parameters
			run: (parameters...) -> query.run.apply query, parameters
			get: (parameters...) -> query.get.apply query, parameters
			all: (parameters...) -> query.all.apply query, parameters
			each: (parameters...) -> query.each.apply query, parameters
			hup: hup
			
		queries[myID] = returnValue
		
		return returnValue
	
	db.runHuppedQuery = (sql, parameters..., callback) ->
		do db.serialize
		
		# 1st finalize all open queries
		for queryID, query of queries
			query.finalize()
			queries[queryID] = query
			
		parameters.unshift sql
		parameters.push ->
			# 3rd reprepare all queries that were previously open
			for queryID, query of queries
				query.hup()
			do db.parallelize
			callback?()
		
		# 2nd run our hup’d query
		db.run.apply db, parameters

# creates default tables
db.serialize ->
	db.run "CREATE TABLE IF NOT EXISTS bot (
		key VARCHAR(255),
		value MEDIUMTEXT,
		PRIMARY KEY(key)
	);"
	db.run "CREATE TABLE IF NOT EXISTS users (
		userID INT(10),
		lastUsername VARCHAR(255) DEFAULT '',
		lastSeen INT(10),
		password CHAR(20) DEFAULT NULL,
		PRIMARY KEY(userID)
	);"
	db.run "CREATE TABLE IF NOT EXISTS user_to_permission (
		userID INT(10),
		permission VARCHAR(255),
		PRIMARY KEY(userID, permission),
		FOREIGN KEY(userID) REFERENCES users(userID)
	);"
	db.run "INSERT OR IGNORE INTO bot (key, value) VALUES (?, ?);", 'firstStart', Date.now()

process.on 'exit', ->
	debug 'Closing database'
	do db.close

# retrieves a user by the given username and calls the callback with the retrieved row
do ->
	query = db.prepare "SELECT * FROM users WHERE lastUsername = ?"
	db.getUserByUsername = (username, callback) -> query.get username, callback

# retrieves all permissions the given user has
do ->
	query = db.prepare "SELECT permission FROM user_to_permission WHERE userID = ?"
	db.getPermissionsByUserID = (userID, callback) ->
		query.all userID, (err, rows) ->
			if err?
				winston.error "Error while checking permissions", err
			else
				callback rows

# checks whether the user with the given userID has the given permission
# and calls the callback with a boolean as the first parameter
do ->
	query = db.prepare "SELECT COUNT(*) AS count FROM user_to_permission WHERE userID = ? AND permission = ?"
	db.hasPermissionByUserID = (userID, permission, callback) ->
		query.get userID, permission, (err, row) ->
			if err?
				winston.error "Error while checking permissions", err
			else
				callback row.count > 0

# Gives the permission to the user with the given userID
do ->
	query = db.prepare "INSERT OR IGNORE INTO user_to_permission (userID, permission) VALUES (?, ?)"
	db.givePermissionToUserID = (userID, permission, callback) ->
		query.run userID, permission, (err, row) ->
			if err?
				winston.error "Error while giving permission", err
			else
				callback?()

# Removes the permission from the user with the given userID
do ->
	query = db.prepare "DELETE FROM user_to_permission WHERE userID = ? AND permission = ?"
	db.removePermissionFromUserID = (userID, permission, callback) ->
		query.run userID, permission, (err, row) ->
			if err?
				winston.error "Error while giving permission", err
			else
				callback?()

# See `hasPermissionByUserID`, additionally whispers the user if he lacks permissions
db.checkPermissionByMessage = (message, permission, callback) ->
	db.hasPermissionByUserID message.sender, permission, (result) ->
		if result
			callback yes
		else
			api.replyTo message, __("Permission denied. You lack the required permission: „%1$s“", permission), no, -> callback no

# Check whether the user with the given userID has all the given permissions
db.hasAllPermissionsByUserID = (userID, permissions, callback) ->
	db.get "SELECT COUNT(*) AS count FROM user_to_permission WHERE userID = ? AND permission IN (#{('?' for [0...permissions.length]).join(',')})", userID, permissions..., (err, row) ->
		if err?
			winston.error "Error while checking permissions", err
		else
			callback row.count is permissions.length

# Check whether the user with the given userID has any of the given permissions
db.hasAnyPermissionByUserID = (userID, permissions, callback) ->
	db.get "SELECT COUNT(*) AS count FROM user_to_permission WHERE userID = ? AND permission IN (#{('?' for [0...permissions.length]).join(',')})", userID, permissions..., (err, row) ->
		if err?
			winston.error "Error while checking permissions", err
		else
			callback row.count > 0

# See `hasAllPermissionsByUserID`, additionally whispers the user if he lacks permissions
db.checkAllPermissionsByMessage = (message, permissions, callback) ->
	db.hasAllPermissionsByUserID message.sender, permissions, (result) ->
		if result
			callback yes
		else
			api.replyTo message, __("Permission denied. You lack some of the required permissions: %1$s", permissions.join ', '), no, -> callback no

# See `hasAnyPermissionsByUserID`, additionally whispers the user if he lacks permissions
db.checkAnyPermissionByMessage = (message, permissions, callback) ->
	db.hasAnyPermissionByUserID message.sender, permissions, (result) ->
		if result
			callback yes
		else
			api.replyTo message, __("Permission denied. You lack all the required permissions: %1$s", permissions.join ', '), no, -> callback no


module.exports = db
