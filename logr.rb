#encoding: UTF-8

class Logger
	attr_accessor :file

	def initialize(file, log_level = 'info')
		@file = File.open(file, 'a+')

		log_level = log_level.upcase

		@@level = 0
		@@level = 0 if log_level == 'INFO'
		@@level = 1 if log_level == 'WARN'
		@@level = 2 if log_level == 'DEBUG'
	end

	def setFile(file)
		close
		@file = File.open(file, 'a+')
	end

	def close
		@file.close unless file == nil
	end

	def info(string) # 0
		print 'info', string
	end

	def warn(string) # 1
		print 'warn', string
	end

	def debug(string) # 2
		print 'debug', string
	end

	def print(level, string = '')
		level = level.upcase

		lv_color = :green
		lv_color = :green if level == 'INFO'
		lv_color = :magenta if level == 'WARN'
		lv_color = :red if level == 'DEBUG'

		str = " [#{level}]".color(lv_color) + " #{string}"

		prt = false
		prt = true if level == 'INFO' && @@level >= 0
		prt = true if level == 'WARN' && @@level >= 1
		prt = true if level == 'DEBUG' && @@level >= 2

		puts str if prt
		@file.write str + "\n"
	end

	private :print
end