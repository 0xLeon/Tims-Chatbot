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

sqlite = (require 'sqlite3').verbose()

db = new sqlite.Database config.database

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
		key CHAR(40) DEFAULT NULL,
		PRIMARY KEY(userID)
	);"
	db.run "CREATE TABLE IF NOT EXISTS user_to_permission (
		userID INT(10),
		permission VARCHAR(255),
		PRIMARY KEY(userID, permission),
		FOREIGN KEY(userID) REFERENCES users(userID)
	);"
	do ->
		stmt = db.prepare "INSERT OR IGNORE INTO bot (key, value) VALUES (?, ?);"
		stmt.run 'firstStart', Date.now()
		do stmt.finalize

process.on 'exit', ->
	winston.debug 'Closing database'
	do db.close

module.exports = db
