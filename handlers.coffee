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

common = require './common'
config = require './config'
winston = require 'winston'
async = require 'async'

loadedHandlers = {}
loadHandlers = ->
	winston.info "Loading message handlers"
	loadHandler 'opserv'
	async.each config.handlers, loadHandler, (err) ->
		winston.info "Finished loading handlers"
loadHandler = (name, callback) ->
	winston.debug 'Loading handler:', name
	if loadedHandlers[name]?
		winston.warn "Trying to load loaded handler", #{name}
	else
		loadedHandlers[name] = require './handlers/' + name
		unless loadedHandlers[name].handle?
			winston.error "Invalid handler, unloading:", name
			unloadHandler name
	
	do callback if callback?

unloadHandler = (name, callback) ->
	unless loadedHandlers[name]?
		winston.warn "Trying to unload unloaded handler", name
		do callback if callback?
	else
		if loadedHandlers[name].unload?
			loadedHandlers[name].unload -> do callback if callback?
		else
			do callback if callback?
		
		delete loadedHandlers[name]
handle = (message, callback) ->
	async.applyEach (v.handle for k, v of loadedHandlers), message, ->
		console.log "Everyone handled", message.message
		callback()
		
module.exports =
	loadHandlers: loadHandlers
	loadHandler: loadHandler
	unloadHandler: unloadHandler
	handle: handle
