#encoding: UTF-8

class Server < EM::Connection
	include EM::HttpServer

	class << self; attr_accessor :counter end
	def post_init
		super
	end

	def receive_data data
		@port = ''
		@ip = ''
		begin
			@port, @ip = Socket.unpack_sockaddr_in(get_peername)
		rescue
		end
		super
	end

	def process_error_response
		@resp.status = 404
		@resp.headers['Content-Type'] = 'application/json'
		@resp.content = JSON.generate({ 'error' => 'not_found', 'reason' => 'document not found' })
		@resp.send_response
	end

	def process_http_request
		@resp = EventMachine::DelegatedHttpResponse.new(self)
		url = @http_request_uri
		@hash = md5(url)

		if $logFile != Time.new.strftime('%y%m%d%H.log')
			$logFile = Time.new.strftime('%y%m%d%H.log')
			$logger.setFile($logPath + $logFile)
		end

		if url.include?('.ico') || url.include?('favicon')
			process_error_response
			return
		end

		$logger.info "<#{@ip}:#{@port}> New http request: #{url}"

		# Exception 01 : `npm find` 실행한 경우, 그냥 실제 서버랑 연결시켜준다
		if url[0, 6] == '/-/all'
			@resp.status = 200
			@resp.content_type 'application/json'
			@resp.content = ''

			Net::HTTP.start("registry.npmjs.org") do |http|
				begin
					http.request_get(url) do |resp|
						resp.read_body do |segment|
							@resp.content += segment
						end
					end
				ensure
					@resp.send_response
					return
				end
			end
		end

		if url.include?('..') || url.include?('//')
			process_error_response
			return
		end
		isBinary = url.include?('/-/')

		url_split = url[1, url.size].split('/')
		unless url[0]
			process_error_response
			return
		end

		if url[-1] == '/'
			process_error_response
			return
		end

		# 캐시가 존재하면
		if File.exists?($infoPath + @hash) && File.exists?($cachePath + @hash)
			$logger.info "<#{@ip}:#{@port}> Cache exists: #{@hash} (#{url})"

			# 바이너리 파일이면 그냥 주고(버전별로 관리되므로), 그냥 파일이면 최신인지 확인하고 준다
			if isBinary
				fileSize = File.size?($cachePath + @hash)
				a = url.split('/')
				@resp.status = 200
				@resp.headers['Content-Disposition'] = 'attachment; filename=' + a[a.size - 1]
				@resp.headers['Content-Length'] = fileSize
				@resp.headers['Transfer-Encoding'] = 'binary'

				content = ''
				open($cachePath + @hash, 'rb') do |f|
					f.each_chunk() do |chunk|
						content += chunk
					end
				end

				$logger.info "<#{@ip}:#{@port}> Get BINARY cache: #{@hash} (#{url})"
				@resp.content = content
				@resp.send_response
			else # 바이너리 파일이 아니면 일단 최신인지 확인하고.. 최신이면 그냥 주고, 아니면 파일 업데이트 후 준다
				# 조건: 파일이 6시간 이상 변경되지 않은 경우
				inf = File.open($infoPath + @hash, 'r:UTF-8')
				info = JSON.parse(inf.read)
				inf.close

				content = ''
				if info["mdtime"] < Time.now.to_i - (3600 * 6)
					content = get_html_content('http://registry.npmjs.org' + url)
					if content[0, 3] == 'err'
						$logger.warn "<#{@ip}:#{@port}> NPM registry error: #{@hash} (#{url})"
						process_error_response
						return
					end

					save = true
					data = JSON.parse(content)
					save = false if data.has_key? 'error'
					content = content.gsub('http://registry.npmjs.org', 'http://' + $serverUrl)
					content = Base64.encode64(content)

					unless save
						process_error_response
						return
					end
				end

				if content == '' && Cache.instance.cache_exists(@hash)
					cache = Cache.instance.get_cache(@hash)
					$logger.info "<#{@ip}:#{@port}> Load memcache: #{@hash} (#{url})"
				else
					file = File.open($cachePath + @hash, 'r:UTF-8')
					cache = file.read
					file.close

					Cache.instance.set_cache(@hash, cache)
				end

				if content != '' && cache != content
					cache = File.open($cachePath + @hash, 'w:UTF-8')
					cache.write(content)
					cache.close

					$logger.info "<#{@ip}:#{@port}> Cache updated: #{@hash} (#{url})"
					cache = content

					info["mdtime"] = Time.new.to_i
					inf = File.open($infoPath + @hash, 'w')
					inf.write(JSON.generate(info))
					inf.close

					Cache.instance.delete_cache(@hash) if Cache.instance.cache_exists(@hash)
					Cache.instance.set_cache(@hash, cache)
				elsif content != '' && cache == content
					$logger.info "<#{@ip}:#{@port}> Cache is up-to-date: #{@hash} (#{url})"

					info["mdtime"] = Time.new.to_i
					inf = File.open($infoPath + @hash, 'w')
					inf.write(JSON.generate(info))
					inf.close
				end

				$logger.info "<#{@ip}:#{@port}> Get JSON cache: #{@hash} (#{url})"
				begin
					cache = Base64.decode64(cache)
				rescue
					p cache
				end


				@resp.status = 200
				@resp.content_type 'application/json'
				@resp.content = cache
				@resp.send_response
				return
			end
		else # 존재하지 않으면
			# 두가지로 또 나뉘는데 이번엔 바이너리 파일이냐 아니냐..
			unless isBinary # 일단 바이너리파일이 아니면
				content = get_html_content('http://registry.npmjs.org' + url)
				if content[0, 3] == 'err'
					$logger.warn "<#{@ip}:#{@port}> NPM registry error: #{@hash} (#{url})"
					process_error_response
					return
				end

				save = true
				data = Array.new

				begin
					data = JSON.parse(content)
				rescue
					process_error_response
					return
				end
				save = false if data.has_key? 'error'
				content = content.gsub('http://registry.npmjs.org', 'http://' + $serverUrl)

				if save
					cc = File.open($cachePath + @hash, 'w:UTF-8')
					cc.write(Base64.encode64(content))
					cc.close

					info_data = {
						"filename" => url,
						"filename_md5" => @hash,
						"mdtime" => Time.new.to_i
					}

					info = File.open($infoPath + @hash, 'w:UTF-8')
					info.write(JSON.generate(info_data))
					info.close

					$logger.info "<#{@ip}:#{@port}> New JSON cache: #{@hash} (#{url})"
				end

				@resp.status = save ? 200 : 404
				@resp.content_type 'application/json'
				@resp.content = content
				@resp.send_response
				return
			else # 바이너리 파일이면
				begin
					open("http://registry.npmjs.org#{url}") { |f|
						
					}
				rescue OpenURI::HTTPError => ex
					$logger.warn "<#{@ip}:#{@port}> NPM registry error: #{@hash} (#{url})"
					process_error_response
					return
				end

				Net::HTTP.start("registry.npmjs.org") do |http|
					f = File.open($cachePath + @hash, 'wb')

					begin
						http.request_get(url) do |resp|
							resp.read_body do |segment|
								f.write(segment)
							end
						end
					ensure
						f.close()
					end
				end

				info_data = {
					"filename" => url,
					"filename_md5" => @hash,
					"mdtime" => Time.new.to_i
				}

				info = File.open($infoPath + @hash, 'w')
				info.write(JSON.generate(info_data))
				info.close
				$logger.info "<#{@ip}:#{@port}> New BINARY cache: #{@hash} (#{url})"

				fileSize = File.size?($cachePath + @hash)
				a = url.split('/')

				@resp.status = 200
				@resp.headers['Content-Disposition'] = 'attachment; filename=' + a[a.size - 1]
				@resp.headers['Content-Length'] = fileSize
				@resp.headers['Transfer-Encoding'] = 'binary'

				content = ''
				open($cachePath + @hash, 'rb') do |f|
					f.each_chunk() do |chunk|
						content += chunk
					end
				end

				@resp.content = content
				@resp.send_response
			end
		end
	end
end