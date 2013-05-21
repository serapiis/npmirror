#encoding: UTF-8

# TODO. 5분간 메모리에 캐시시키기
# 싱글톤(Singleton)으로 작동해야되고, 전역변수에 할당시켜서 두면 될듯
# 바이너리는 절대 캐싱하지 않음!!
class Cache
	@@instance = nil

	def initialize
		@data = Hash.new
	end

	def self.instance
		if @@instance == nil
			@@instance = new
		end

		return @@instance
	end

	def cache_exists(id)
		update
		return @data.has_key?(id)
	end

	def get_cache(id)
		update
		return nil unless cache_exists(id)

		return @data[id]['data']
	end

	def set_cache(id, value)
		update
		return nil if cache_exists(id)
		
		@data[id] = Hash.new
		@data[id]['time'] = Time.new.to_i
		@data[id]['data'] = value
	end

	def delete_cache(id)
		update
		return nil unless cache_exists(id)

		@data.delete(key)
	end

	def update
		return nil if @data.size == 0

		@data.each do | key, value |
			if value['time'] < Time.new.to_i - (60 * 5)
				@data.delete(key)
			end
		end
	end

	private_class_method :new
	private :update
end