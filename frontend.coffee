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

express = require 'express'
config = require './config'
api = require './api'
handlers = require './handlers'
winston = require 'winston'
db = require './db'

winston.info "Loading HTTP frontend"
app = do express
app.set 'views', "#{__dirname}/views"
app.set 'view engine', 'ejs'
app.use (require 'connect-assets')
	production: true
	buildDir: 'derp'

app.use express.basicAuth (user, pass, callback) ->
	db.getUserByUsername user, (err, user) ->
		if err?
			callback err
		else
			callback null, user?.password is pass


app.get '/', (req, res) ->
	api.getRoomList (roomList) ->
		res.render 'index',
			config: config
			roomList: roomList
			loadedHandlers: do handlers.getLoadedHandlers

app.get '/join/:id', (req, res) ->
	unless /^[1-9][0-9]*$/.test req.params.id
		res.send 400, 'Bad request'
		return
	api.joinRoom req.params.id, (err) ->
		if err?
			res.send 503, err
		else
			res.send 200, 'OK'

listen = ->
	app.listen config.port, config.ip
	winston.info "Frontend listening on #{config.ip}:#{config.port}"

removeRoute = (name) ->
	app.routes.get.splice k, 1 for v, k in app.routes.get when v.path is name if app.routes.get?
	app.routes.post.splice k, 1 for v, k in app.routes.post when v.path is name if app.routes.post?

module.exports =
	listen: listen
	get: (path, callback) => app.get path, callback
	post: (path, callback) => app.post path, callback
	removeRoute: removeRoute
