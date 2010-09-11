###########################################################################
#
# RailscastsDownloader 2.0
#
# Copyright (C) 2009 Miquel Oliete <ktalanet@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.
#
###########################################################################

require 'rss/2.0'
require 'sqlite3'

class Railscast

  	GIGA_SIZE = 1073741824.0
	MEGA_SIZE = 1048576.0
	KILO_SIZE = 1024.0


	attr_reader :title, :url, :length

	def initialize(title, url, length)
		@title 	= title
		@url 	= url
		@length = format(length, 2)
	end

	private

		###
		#
		###
		def format(size, precision)
		    case
				when size == 1 		then "1 Byte"
				when size < KILO_SIZE  	then "%d Bytes" % size
				when size < MEGA_SIZE 	then "%.#{precision}f KB" % (size / KILO_SIZE)
				when size < GIGA_SIZE 	then "%.#{precision}f MB" % (size / MEGA_SIZE)
				else "%.#{precision}f GB" % (size / GIGA_SIZE)
			end
		end

end


class RailscastsDownloader

	RAILS_CAST_FEED_URL = 'http://feeds2.feedburner.com/railscasts'
	RAILS_CAST_DB = 'RailscastsDownloader.db'

	###
	#
	###
	def initialize(url=RAILS_CAST_FEED_URL)
		@source = url
		@db = SQLite3::Database.new(RAILS_CAST_DB)

	end


	###
	#
	###
	def download_casts(restart=true)

		if (restart)
			downloaded_episodes = get_downloaded_episodes()
		else
			downloaded_episodes = Array.new()
		end


		# Getting casts list
		puts "Getting casts from rss (#{@source})."
		puts ""
		list = get_casts_list()

		list.each do |cast|
			local_filename = cast.url.split('/').at(-1)
			if (downloaded_episode?(local_filename))
				puts local_filename
				puts "Episode named #{local_filename} already downloaded."
				puts ""
				next
			end

			puts "Downloading #{cast.title} (#{cast.url} - #{cast.length})"
			content = Net::HTTP.get(URI.parse(cast.url))

			puts "Saving file #{local_filename}."
			file = File.open(local_filename, 'w')
			file.write(content)
			file.close()
			puts ""
			downloaded_episodes << local_filename

			puts "Adding downloaded episode to restart database."
			insert_downloaded_episode_to_restart_db(local_filename)
		end

	end

	private

		###
		#
		###
		def get_downloaded_episodes()
			return @db.execute( "select episode from rails_casts" )
		end

		###
		#
		###
		def downloaded_episode?(episode_name)
			count = @db.get_first_value('select count(*) from rails_casts where episode = ?', episode_name)

			return (count && count.to_i() > 0)
		end

		###
		#
		###
		def insert_downloaded_episode_to_restart_db(downloaded_episode_name)
			@db.execute('insert into rails_casts values(?)', downloaded_episode_name)
		end


		###
		#
		###
		def get_casts_list()

			casts = Array.new()

			# Reading rss content.
			content = ''
			open(@source) do |s| 
				content = s.read 
			end


			# Parsing rss data.
			rss = RSS::Parser.parse(content, false)

			# Getting railscast files.
			rss.channel.items.reverse.each do |item|
				casts << Railscast.new(item.title, item.enclosure.url, item.enclosure.length)
			end

			return casts

		end

end

case(ARGV.length)
	when 0
		restart = true
	when 1 
		restart = (ARGV[0] == true) ? true : false
	else
		# Error
		puts('Error in parameters. Syntax')
		puts('	RailscastsDownloader [true|false]')
		puts('')
		Process.exit!(1)
end


rcd = RailscastsDownloader.new()
rcd.download_casts(restart)
