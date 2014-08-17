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

debug = (require 'debug')('Chatbot:toys')
api = require '../api'
Random = require 'random-js'
{ __, __n } = require '../i18n'

mt = do Random.engines.mt19937
do mt.autoSeed

handleMessage = (message, callback) ->
	if message.message.substring(0, 1) isnt '!'
		# ignore messages that don't start with an exclamation mark
		callback?()
		return
		
	text = (message.message.substring 1).split /\s/
	[ command, parameters ] = [ text.shift(), text.join ' ' ]
	
	switch command
		when 'dice'
			if parameters isnt '' and parameters.match /\d+d\d+/
				[ dice, sides ] = parameters.split /d/
			else
				api.replyTo message, __("Your arguments were invalid!"), no, callback
				return
				
			sides = 6 if not sides? or sides is ''
			dice = 1 if not dice? or dice is ''
			
			if sides > 150
				api.replyTo message, __("The maximum number of sides is 150."), no, callback
				return
				
			if dice > 50
				api.replyTo message, __("The maximum number of dice is 50."), no, callback
				return
				
			api.sendMessage Random.dice(sides, dice)(mt).join(', '), yes, callback
			
		else
			callback?()
			
module.exports =
	handleMessage: handleMessage
	handleUser: (user, callback) -> callback?()
	unload: (callback) -> callback?()
