class Stubber

  def initialize record_new = :never
    @stubs = []
    @record_new = record_new

    if record_new == :always
      WebMock.allow_net_connect!
      InfoSig.log.log_level = :debug
      @load_stubs = false
    elsif record_new == :never
      @load_stubs = true
    elsif record_new == :only_new
      InfoSig.log.log_level = :debug
      @load_stubs = true
    else
      raise "unrecognized value of record_new #{record_new}"
    end
  end

  def [] lambda
    if @load_stubs
      lambda.call
    else
      # niente
    end
  end

  def call
    if @load_stubs
      yield
    else
      # niente
    end
  end

end