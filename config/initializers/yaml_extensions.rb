module YAML

  def self.load_erb_file file_path
    load(ERB.new(File.read(file_path)).result)
  end

end