#encoding: UTF-8

require 'digest/md5'

class File
	def each_chunk(chunk_size = 1024 * 1024)
		yield read(chunk_size) until eof?
	end
end

def md5(data = '')
	return Digest::MD5.hexdigest(data)
end

def get_html_content(requrl)
	str = ''
	begin
		open(requrl) { |f|
			f.each_line { |line|
				str += line
			}
		}
	rescue OpenURI::HTTPError => ex
		return "err|#{ex}"
	end

	return str
end