class Sequel::Model

  def self.delegate_attributes *attrs
    if attrs.last.is_a?(Hash)
      options = attrs.pop
    else
      options = {}
    end

    attrs.each do |attr|
      delegate attr, options
      delegate "#{attr}=", options
    end
  end

  dataset_module do
    def random
      order(Sequel.lit('RANDOM()'))
    end
  end

end
