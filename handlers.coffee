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
	for name in [ 'opserv', 'core' ]
		loadHandler name, (err) ->
			return unless err?
			winston.error "panic() - Going nowhere without my", name
			process.exit 1
		
	async.each config.handlers, loadHandler, (err) ->
		winston.info "Finished loading handlers"

loadHandler = (name, callback) ->
	winston.debug 'Loading handler:', name
	
	unless /^[a-z]+$/.test name
		winston.warn "Trying to load invalid named handler", name
		callback "invalid" if callback?
		return
		
	if loadedHandlers[name]?
		winston.warn "Trying to load loaded handler", name
		
		callback "loaded" if callback?
	else
		try
			loadedHandlers[name] = require './handlers/' + name
			if loadedHandlers[name].handle?
				do callback if callback?
			else
				winston.error "Invalid handler, unloading:", name
				unloadHandler name
				callback "invalid" if callback?
		catch e
			winston.error "Failed to compile handler", name, e.message
			callback "compile" if callback?

unloadHandler = (name, callback) ->
	if name in [ 'core', 'opserv' ]
		winston.warn "Trying to unload", name
		callback "permissionDenied" if callback?
		return
		
	winston.debug 'Unloading handler:', name
	unless loadedHandlers[name]?
		winston.warn "Trying to unload unloaded handler", name
		callback "notLoaded" if callback?
	else
		if loadedHandlers[name].unload?
			loadedHandlers[name].unload -> do callback if callback?
		else
			do callback if callback?
		
		delete loadedHandlers[name]

getLoadedHandlers = -> k for k of loadedHandlers

handle = (message, callback) ->
	async.applyEach (v.handle for k, v of loadedHandlers), message, callback


module.exports =
	loadHandlers: loadHandlers
	loadHandler: loadHandler
	unloadHandler: unloadHandler
	getLoadedHandlers: getLoadedHandlers
	handle: handle
