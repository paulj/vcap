require 'fileutils'

class Nginx

    def self.resource_dir
        File.join(File.dirname(__FILE__) , 'resources')
    end

    def self.prepare(dir)
        FileUtils.cp_r(resource_dir,dir)
        output = %x[cd #{dir}; tar xzf resources/nginx-1.0.5.tar.gz -C ./app]
        raise "Could not unpack Nginx: #{output}" unless $? == 0
    end

end
