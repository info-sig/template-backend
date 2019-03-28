class DummyWorker

  include Backgroundable
  include Backgroundable::Unique

  def call(what)
    InfoSig.log.info "WIIII :D #{what}"
    sleep 1
    InfoSig.log.info "DONE! #{what}"
  end
end
