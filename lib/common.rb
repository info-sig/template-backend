module InfoSig
  module Common

    def self.root
      @@root ||= File.expand_path(File.dirname(__FILE__)) + '/'
    end

    def self.require_in_module file_mask
      Dir[root + file_mask].sort.each {|file| require_relative file }
    end

    require_in_module './common/functional.rb'
    require_in_module './common/**/*.rb'
  end
end
