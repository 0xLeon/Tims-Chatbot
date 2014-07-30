###
# YouTube handler (YouTube API v3)
#
# This handler resolves the titles of posted youtube links and
# posts them in Chat.
# 
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

api = require '../api'
async = require 'async'
common = require '../common'
config = require '../config'
db = require '../db'
debug = (require 'debug')('Chatbot:handlers:youtube')
handlers = require '../handlers'
winston = require 'winston'
{ __, __n } = require '../i18n'

lru = require('lru-cache')(1000) # Set LRU cache to 1000 entries maximum
regex = 'https?://(?:.+?\\.)?youtu(?:\\.be/|be\\.com/watch\\?(?:.*?&)??v=)([a-zA-Z0-9_-]+)'

onlyUnique = (value, index, self) -> self.indexOf(value) is index

handleMessage = (message, callback) ->
	# Don't match our own messages
	if message.sender isnt config.userID
		ids = message.message.match new RegExp regex, 'g'
		
		return callback?() if ids is null
		
		# Filter out duplicates – never trust users ;)
		ids = ids.filter onlyUnique
		
		async.each ids, (item, callback) ->
			id = item.match new RegExp regex
			
			# Check if RegEx matched correctly
			if id isnt null and id[1]?
				# Check if video ID has been cached already
				if not lru.get(id[1])?
					url = "https://www.googleapis.com/youtube/v3/videos?id=#{encodeURIComponent id[1]}&key=#{encodeURIComponent config.youtubeAPI.key}&part=snippet&prettyPrint=false"
					
					# See https://developers.google.com/youtube/v3/docs/standard_parameters#userIp
					if config.youtubeAPI.userIP? and config.youtubeAPI.userIP isnt ''
						url += "&userIp=#{encodeURIComponent config.youtubeAPI.userIP}"
						
					# See https://developers.google.com/youtube/v3/docs/standard_parameters#quotaUser
					if config.youtubeAPI.quotaUser? and config.youtubeAPI.quotaUser isnt ''
						url += "&quotaUser=#{encodeURIComponent config.youtubeAPI.quotaUser}"
						
					# Query Google’s YouTube API for the “video snippet”
					debug "Starting request of '#{url}'"
					common.request.get url, (err, res, body) ->
						try
							data = JSON.parse body
						catch e
							winston.error "Invalid JSON returned by YouTube: #{body}"
							callback?()
							
						if data.error?
							errorMessage = "[YouTube] [#{data.error.code}] #{data.error.message}\n"
							
							for error in data.error.errors
								for key, value of error
									errorMessage += "\t#{key}: #{value}\n"
								
							winston.error errorMessage
							callback?()
						else
							title = "[YouTube] (#{id[1]}): [#{data.items[0].snippet.channelTitle}] – #{data.items[0].snippet.title}"
							
							# Save data in cache
							lru.set id[1], title
							
							api.sendMessage title, no, callback
							
						debug "Request of '#{url}' finished"
						
				else
					# Just peek as we got the value earlier
					api.sendMessage lru.peek(id[1]), no, callback
			else
				callback?()
		, callback
	else
		callback?()
		
onLoad = (callback) ->
	if not config.youtubeAPI?.key? or config.youtubeAPI.key is ''
		error  = """[YouTube] To use this module you need an API key.
			Please consider creating a server API key at
			> https://console.developers.google.com <
			To do so create a new project, open "APIs" under "APIS & AUTH" afterwards and
			activate the "YouTube Data API v3". Now open "Credentials" under "APIS & AUTH".
			Create a server key under "Public API access". Now you should have an API key.
			Open up your "config.coffee" and add the following:
				youtubeAPI:
					key: 'YOUR_API_KEY'"""
		winston.error error
		
		throw new Error "YouTube API key not specified."
		
	callback?()
		
module.exports =
	handleMessage: handleMessage
	handleUser: (user, callback) -> callback?()
	unload: (callback) -> callback?()
	onLoad: onLoad
	
