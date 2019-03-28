class Hash

  def deep_fix_utf8(arg = self)
    case arg
    when Hash
      Hash[arg.map do |k,v|
        [ fix_utf8_for_element(k), deep_fix_utf8(v) ]
      end]
    else
      fix_utf8_for_element(arg)
    end
  end

private

  def fix_utf8_for_element(arg)
    if arg.is_a? String
      rv = arg.frozen? ? arg.dup : arg
      rv.force_encoding('UTF-8')
    else
      arg
    end
  rescue Exception => e
    "invalid UTF-8 byte sequence"
  end

end
