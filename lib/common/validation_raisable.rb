module ValidationRaisable
  extend ActiveSupport::Concern

  class ValidationError < StandardError; end

  included do
    # this needs to be expressed as a string, or ruby will do funny things with the constant lookup tables
    # and will proclaim SomeClass::ValidationError to be actually a ValidationRaisable::ValidationError,
    # but we prefer the context of the class to be preserved in the exception (ie SomeClass::ValidationError)
    self.class_eval 'class ValidationError < ValidationRaisable::ValidationError; end'
  end


  module ClassMethods
    def validation_error message
      raise self::ValidationError.new(message)
    end
  end

  def validation_error *args, &block
    self.class.validation_error *args, &block
  end


end