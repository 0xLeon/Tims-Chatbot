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

app = do express
app.set 'views', "#{__dirname}/views"
app.set 'view engine', 'ejs'
app.use (require 'connect-assets')
	production: true
	buildDir: 'derp'

app.get '/', (req, res) ->
	res.render 'index',
		config: config

app.get '/shutdown', (req, res) ->
	api.leaveChat ->
		res.send 200, 'OK'
		process.exit 0

listen = ->
	app.listen config.port, config.ip

module.exports =
	listen: listen
