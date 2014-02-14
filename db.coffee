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
api = require './api'

sqlite = (require 'sqlite3').verbose()

db = new sqlite.Database config.database

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
	winston.debug 'Closing database'
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

# See `hasPermissionByUserID`, additionally whispers the user if he lacks permissions
db.checkPermissionByMessage = (message, permission, callback) ->
	db.hasPermissionByUserID message.sender, permission, (result) ->
		if result
			callback yes
		else
			api.replyTo message, "Permission denied. You lack the required permission: #{permission}", no, -> callback no

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
			api.replyTo message, "Permission denied. You lack some of the required permissions: #{permissions.join ', '}", no, -> callback no

# See `hasAnyPermissionsByUserID`, additionally whispers the user if he lacks permissions
db.checkAnyPermissionByMessage = (message, permissions, callback) ->
	db.hasAnyPermissionByUserID message.sender, permissions, (result) ->
		if result
			callback yes
		else
			api.replyTo message, "Permission denied. You lack all the required permissions: #{permissions.join ', '}", no, -> callback no


module.exports = db
