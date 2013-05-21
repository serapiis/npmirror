#encoding: UTF-8

# 루비젬
require 'rubygems'

# 루비 라이브러리
require 'socket'
require 'net/http'
require 'uri'
require 'fileutils'
require 'date'
require 'base64'

# 외부 라이브러리
require 'json'
require 'open-uri'
require 'eventmachine'
require 'evma_httpserver'
require 'rainbow'

require './func.rb'
require './server.rb'
require './logr.rb'
require './memcache.rb'

# 사용할 전역변수
$rbPath = Dir.getwd + '/'
$cachePath = $rbPath + '/cache/'
$infoPath = $rbPath + '/info/'
$logPath = $rbPath + '/logs/'
$log = nil
$loggerFile = nil
$logger = nil
$serverUrl = ''

# 캐시 경로가 있는지 확인하고 없으면 생성한다
unless File.exists?($cachePath)
	FileUtils.mkdir_p $cachePath
	FileUtils.chmod 0777, $cachePath
end

# 해시 데이터를 저장할 경로가 있는지 확인하고 없으면 생성한다
unless File.exists?($infoPath)
	FileUtils.mkdir_p $infoPath
	FileUtils.chmod 0777, $infoPath
end

# 로그 경로가 있는지 확인하고 없으면 생성한다
unless File.exists?($logPath)
	FileUtils.mkdir_p $logPath
	FileUtils.chmod 0777, $logPath
end

# 변수 초기화
$logFile = Time.new.strftime('%y%m%d%H.log')
$logger = Logger.new($logPath + $logFile)
$serverUrl = "121.170.25.185:8080"

# EventMachine 기본이 SELECT I/O 를 사용한다는데..
# 버전 업데이트되면서 바뀌었는지 잘 몰라서 일단..
EM::epoll
EM::kqueue

# 이벤트머신 실행
EM::run do
	# 인터럽 신호가 발생한 경우
	Signal.trap("INT") do
		begin
			$logger.file.close
		rescue
		end
		EventMachine.stop
	end
	Signal.trap("TERM") do 
		begin
			$logger.file.close
		rescue
		end
		EventMachine.stop
	end

	# 서버 실행
	EM::start_server '0.0.0.0', 8080, Server
	$logger.info 'NPMIRROR'.color(:yellow) + ' Server listening on port ' + '8080'.color(:magenta)
end