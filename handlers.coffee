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
debug = (require 'debug')('Chatbot:handlers')
async = require 'async'

loadedHandlers = {}
loadHandlers = ->
	winston.info "Loading message handlers"
	for name in [ 'opserv', 'core' ]
		loadHandler name, (err) ->
			return unless err?
			common.fatal "panic() - Going nowhere without my #{name}"
		
	async.each config.handlers, loadHandler, (err) ->
		winston.info "Finished loading handlers"

loadHandler = (name, callback) ->
	debug "Loading handler: #{name}"
	
	unless /^[a-z]+$/.test name
		winston.warn "Trying to load invalid named handler", name
		callback? "invalid"
		return
		
	if loadedHandlers[name]?
		winston.warn "Trying to load loaded handler", name
		
		callback? "loaded"
	else
		try
			loadedHandlers[name] = require './handlers/' + name
			if loadedHandlers[name].handleMessage? and loadedHandlers[name].handleUser?
				callback?()
			else
				winston.error "Invalid handler, unloading:", name
				unloadHandler name
				callback? "invalid"
		catch e
			winston.error "Failed to compile handler “#{name}”: #{e.message}"
			callback? "compile"

unloadHandler = (name, callback) ->
	if name in [ 'core', 'opserv' ]
		winston.warn "Trying to unload", name
		callback? "permissionDenied"
		return
		
	winston.debug 'Unloading handler:', name
	if loadedHandlers[name]?
		if loadedHandlers[name].unload?
			loadedHandlers[name].unload -> callback?()
		else
			callback?()
		
		delete loadedHandlers[name]
	else
		winston.warn "Trying to unload unloaded handler", name
		callback? "notLoaded"

getLoadedHandlers = -> k for k of loadedHandlers

# calls handleMessage of each handler and calls the callback after every handler handled it
handleMessage = (message, callback) ->
	async.applyEach (v.handleMessage for k, v of loadedHandlers), message, callback

# calls handleUser of each handler and calls the callback after every handler handled it
handleUser = (user, callback) ->
	async.applyEach (v.handleUser for k, v of loadedHandlers), user, callback


module.exports =
	loadHandlers: loadHandlers
	loadHandler: loadHandler
	unloadHandler: unloadHandler
	getLoadedHandlers: getLoadedHandlers
	handleMessage: handleMessage
	handleUser: handleUser
