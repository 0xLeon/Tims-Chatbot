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

handle = (message, callback) ->
	if message.message.substring(0, 1) isnt '?'
		# ignore messages that don't start with a question mark
		do callback if callback?
		return
	
	text = (message.message.substring 1).split /\s/
	[ command, parameters ] = [ text.shift(), text.join ' ' ]
	
	switch command
		when "shutdown"
			api.leaveChat -> process.exit 0
		when "load"
			handlers.loadHandler parameters, (err) ->
				if err?
					api.sendMessage "Failed to load module #{parameters}", no, callback
				else
					api.sendMessage "Loaded module #{parameters}", no, callback
		when "unload"
			handlers.unloadHandler parameters, (err) ->
				if err?
					api.sendMessage "Failed to unload module #{parameters}", no, callback
				else
					api.sendMessage "Unloaded module #{parameters}", no, callback
		else
			winston.debug "[OpServ] Ignoring unknown command", command
			do callback if callback?
unload = (callback) ->
	console.log "OPServ says goodbye"
	do callback if callback?
	
module.exports =
	handle: handle
	unload: unload
