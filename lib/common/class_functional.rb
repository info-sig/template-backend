module ClassFunctional

  def [](*args, &block)
    call(*args, &block)
  end

  def method_call
    method(:call)
  end

  def as_proc
    method_call
  end

  def future *args, &block
    Concurrent::Future.execute{ call(*args, &block) }
  end

end