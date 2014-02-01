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

winston = require 'winston'

module.exports =
	fatal: (message, err) ->
		if err?
			winston.error message, err
		else
			winston.error message
		process.exit 1
	messageTypes:
		NORMAL: 0,
		JOIN: 1,
		LEAVE: 2,
		AWAY: 3,
		BACK: 4,
		MODERATE: 5,
		ME: 6,
		WHISPER: 7,
		INFORMATION: 8,
		CLEAR: 9,
		TEAM: 10,
		GLOBALMESSAGE: 11,
		ATTACHMENT: 12
