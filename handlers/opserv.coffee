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

common = require '../common'
config = require '../config'
handlers = require '../handlers'
api = require '../api'
winston = require 'winston'
db = require '../db'

frontend = require '../frontend'

commands = 
	shutdown: (callback) ->
		api.leaveChat ->
			do callback if callback?
			process.exit 0
	load: (callback, parameters) -> handlers.loadHandler parameters, callback
	unload: (callback, parameters) -> handlers.unloadHandler parameters, callback
	loaded: (callback) -> callback handlers.getLoadedHandlers() if callback?

frontend.get '/opserv/shutdown', (req, res) -> commands.shutdown -> res.send 200, 'OK'
frontend.get '/opserv/load/:module', (req, res) -> 
	commands.load (err) -> 
		if err?
			res.send 503, err
		else
			res.send 200, 'OK'
	, req.params.module
frontend.get '/opserv/unload/:module', (req, res) -> 
	commands.unload (err) -> 
		if err?
			res.send 503, err
		else
			res.send 200, 'OK'
	, req.params.module
frontend.get '/opserv/loaded', (req, res) ->
	commands.loaded (handlers) -> res.send 200, handlers.join ', '

handleMessage = (message, callback) ->
	if message.message.substring(0, 1) isnt '?'
		# ignore messages that don't start with a question mark
		do callback if callback?
		return
	
	text = (message.message.substring 1).split /\s/
	[ command, parameters ] = [ text.shift(), text.join ' ' ]
	
	switch command
		when "shutdown"
			do commands.shutdown
		when "loaded"
			commands.loaded (handlers) ->
				api.sendMessage "These handlers are loaded: #{handlers.join ', '}", no, callback
		when "load"
			commands.load (err) ->
				if err?
					api.sendMessage "Failed to load module #{parameters}", no, callback
				else
					api.sendMessage "Loaded module #{parameters}", no, callback
			, parameters
		when "getPermissions"
			db.hasPermissionByUserID message.sender, 'opserv.getPermissions', (err, permission) ->
				return unless permission > 0
				
				db.getUserByUsername parameters, (err, user) ->
					if user?
						api.sendMessage "#{user.lastUsername} (#{user.userID}) has the following permissions: ", no, callback
					else
						api.sendMessage "Could not find user #{parameters}", no, callback
		when "unload"
			commands.unload (err) ->
				if err?
					api.sendMessage "Failed to unload module #{parameters}", no, callback
				else
					api.sendMessage "Unloaded module #{parameters}", no, callback
			, parameters
			
		else
			winston.debug "[OpServ] Ignoring unknown command", command
			do callback if callback?

unload = (callback) ->
	winston.error "panic() - Going nowhere without my opserv"
	process.exit 1

module.exports =
	handleMessage: handleMessage
	handleUser: (user, callback) -> do callback if callback?
	unload: unload
