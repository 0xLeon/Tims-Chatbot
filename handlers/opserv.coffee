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
{ __, __n } = require 'i18n'

frontend = require '../frontend'

commands = 
	shutdown: (callback) ->
		api.leaveChat ->
			callback?()
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
		callback?()
		return
	
	text = (message.message.substring 1).split /\s/
	[ command, parameters ] = [ text.shift(), text.join ' ' ]
	
	switch command
		when "shutdown"
			db.checkPermissionByMessage message, 'opserv.shutdown', (hasPermission) ->
				if permission
					do commands.shutdown
				else
					callback?()
		when "loaded"
			db.checkAnyPermissionByMessage message, [ 'opserv.load', 'opserv.unload' ], (hasPermission) ->
				if hasPermission
					commands.loaded (handlers) -> api.sendMessage __("These handlers are loaded: %s", handlers.join ', '), no, callback
				else
					callback?()
		when "load"
			commands.load (err) ->
				api.replyTo message, (if err? then __("Failed to load module %s", parameters) else __("Loaded module %s", parameters)), no, callback
			, parameters
		when "unload"
			commands.unload (err) ->
				api.replyTo message, (if err? then __("Failed to unload module %s", parameters) else __("Unloaded module %s", parameters)), no, callback
			, parameters
		when "setPermission"
			db.checkPermissionByMessage message, 'opserv.setPermission', (hasPermission) ->
				if hasPermission
					[ username, permission... ] = parameters.split /,/
					
					db.getUserByUsername username.trim(), (err, user) ->
						if user?
							db.givePermissionToUserID user.userID, permission.join('').trim(), (rows) ->
								api.replyTo message, __("Gave {{permission}} to “{{username}}”", { permission: permission, username: username }), no, callback
						else
							api.replyTo message, __("Could not find user “%s”", username), no, callback
				else
					# We trust you have received the usual lecture from the local System
					# Administrator. It usually boils down to these three things:
					#
					#    #1) Respect the privacy of others.
					#    #2) Think before you type.
					#    #3) With great power comes great responsibility.
					#
					# This incident will be reported.
					callback?()
		when "getPermissions"
			db.checkAnyPermissionByMessage message, [ 'opserv.setPermission', 'opserv.getPermissions' ], (hasPermission) ->
				if hasPermission
					db.getUserByUsername parameters, (err, user) ->
						if user?
							db.getPermissionsByUserID user.userID, (rows) ->
								api.replyTo message, __('“%1$s” (%2$s) has these permissions: %3$s', user.lastUsername, user.userID, (row.permission for row in rows).join ', '), no, callback
						else
							api.replyTo message, __("Could not find user “%s”", parameters), no, callback
				else
					callback?()
		else
			winston.debug "[OpServ] Ignoring unknown command", command
			callback?()

unload = (callback) ->
	winston.error "panic() - Going nowhere without my opserv"
	process.exit 1

module.exports =
	handleMessage: handleMessage
	handleUser: (user, callback) -> callback?()
	unload: unload
