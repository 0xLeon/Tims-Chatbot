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
crypto = require 'crypto'
config = require '../config'
handlers = require '../handlers'
api = require '../api'
winston = require 'winston'
debug = (require 'debug')('Chatbot:handlers:opserv')
db = require '../db'
{ __, __n } = require '../i18n'

frontend = require '../frontend'

commands = 
	shutdown: (callback) ->
		api.leaveChat ->
			callback?()
			process.exit 0
	load: (callback, parameters) -> handlers.loadHandler parameters, callback
	unload: (callback, parameters) -> handlers.unloadHandler parameters, callback
	purge: (callback, parameters) -> handlers.purgeHandler parameters, callback
	loaded: (callback) -> callback handlers.getLoadedHandlers() if callback?

frontend.get '/opserv/shutdown', (req, res) -> commands.shutdown -> res.send 200, 'OK'
frontend.get '/opserv/load/:module', (req, res) -> 
	commands.load (err) -> 
		if err?
			res.send 503, err
		else
			req.flash 'success', __("Successfully loaded %1$s", req.params.module)
			res.redirect '/'
	, req.params.module
frontend.get '/opserv/unload/:module', (req, res) -> 
	commands.unload (err) -> 
		if err?
			res.send 503, err
		else
			req.flash 'success', __("Successfully unloaded %1$s", req.params.module)
			res.redirect '/'
	, req.params.module
frontend.get '/opserv/loaded', (req, res) ->
	commands.loaded (handlers) -> res.send 200, handlers.join ', '


adminKey = null
db.get "SELECT COUNT(*) AS count FROM user_to_permission WHERE permission = ?", 'opserv.setPermission', (err, row) ->
	if err?
		winston.error "Error while checking whether permissions exist", err
	else
		if row.count is 0
			crypto.randomBytes 20, (ex, buf) ->
				adminKey = (buf.toString 'hex')[0..20]
				console.log __("There is no user with the opserv.setPermission permission. Use the following command to receive it:")
				console.log "	?sesame #{adminKey}"

handleMessage = (message, callback) ->
	if message.sender is config.userID
		# Chatbot should not control itself via opserv
		callback?()
		return
	
	if message.message[0] isnt '?'
		# ignore messages that don't start with a question mark
		callback?()
		return
	
	[ command, parameters... ] = message.message[1..].split /\s/
	parameters = parameters.join ' '
	
	switch command
		when "shutdown"
			db.checkPermissionByMessage message, 'opserv.shutdown', (hasPermission) ->
				if hasPermission
					do commands.shutdown
				else
					callback?()
		when "loaded"
			db.checkAnyPermissionByMessage message, [ 'opserv.load', 'opserv.unload' ], (hasPermission) ->
				if hasPermission
					commands.loaded (handlers) ->
						api.replyTo message, __("These handlers are loaded: %s", handlers.join ', '), no, callback
				else
					callback?()
		when "load"
			db.checkPermissionByMessage message, 'opserv.load', (hasPermission) ->
				if hasPermission
					commands.load (err) ->
						api.replyTo message, (if err? then __("Failed to load module “%s”", parameters) else __("Loaded module %s", parameters)), no, callback
					, parameters
				else
					callback?()
		when "unload"
			db.checkPermissionByMessage message, 'opserv.unload', (hasPermission) ->
				if hasPermission
					commands.unload (err) ->
						api.replyTo message, (if err? then __("Failed to unload module “%s”", parameters) else __("Unloaded module %s", parameters)), no, callback
					, parameters
				else
					callback?()
		when "purge"
			db.checkPermissionByMessage message, 'opserv.purge', (hasPermission) ->
				if hasPermission
					commands.purge (err) ->
						api.replyTo message, (if err? then __("Failed to purge configuration of module “%s”", parameters) else __("Purged configuration of module %s", parameters)), no, callback
					, parameters
				else
					callback?()
		when "sesame"
			if parameters is adminKey
				adminKey = null
				db.givePermissionToUserID message.sender, 'opserv.setPermission', (rows) ->
					api.replyTo message, __("You received the “opserv.setPermission” permission. Have fun!"), no, callback
			else
				callback?()
		when "setPermission"
			db.checkPermissionByMessage message, 'opserv.setPermission', (hasPermission) ->
				if hasPermission
					[ username, permission... ] = parameters.split /,/
					
					db.getUserByUsername username.trim(), (err, user) ->
						if user?
							db.hasPermissionByUserID user.userID, permission.join('').trim(), (alreadyHasPermission) ->
								if alreadyHasPermission
									api.replyTo message, __("“%2$s” already has got the permission %1$s", permission, username), no, callback
								else
									db.givePermissionToUserID user.userID, permission.join('').trim(), (rows) ->
										api.replyTo message, __("Gave %1$s to “%2$s”", permission, username), no, callback
						else
							api.replyTo message, __("Could not find user with username “%s”", username), no, callback
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
		when "removePermission"
			db.checkPermissionByMessage message, 'opserv.setPermission', (hasPermission) ->
				if hasPermission
					[ username, permission... ] = parameters.split /,/
					
					db.getUserByUsername username.trim(), (err, user) ->
						if user?
							db.hasPermissionByUserID user.userID, permission.join('').trim(), (alreadyHasPermission) ->
								if alreadyHasPermission
									db.removePermissionFromUserID user.userID, permission.join('').trim(), (rows) ->
										api.replyTo message, __("Removed %1$s from “%2$s”", permission, username), no, callback
								else
									api.replyTo message, __("“%2$s” does not have the permission %1$s", permission, username), no, callback
						else
							api.replyTo message, __("Could not find user with username “%s”", username), no, callback
				else
					callback?()
		when "getPermissions"
			db.checkAnyPermissionByMessage message, [ 'opserv.setPermission', 'opserv.getPermissions' ], (hasPermission) ->
				if hasPermission
					[ username ] = parameters.split /,/
					
					db.getUserByUsername username.trim(), (err, user) ->
						if user?
							db.getPermissionsByUserID user.userID, (rows) ->
								api.replyTo message, __('“%1$s” (%2$d) has got these permissions: %3$s', user.lastUsername, user.userID, (row.permission for row in rows).join ', '), no, callback
						else
							api.replyTo message, __("Could not find user with username “%s”", parameters), no, callback
				else
					callback?()
		else
			debug "Ignoring unknown command #{command}"
			callback?()

unload = (callback) -> common.fatal "panic() - Going nowhere without my opserv"

module.exports =
	handleMessage: handleMessage
	handleUser: (user, callback) -> callback?()
	unload: unload
