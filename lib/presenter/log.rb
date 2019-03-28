module Presenter
  class Log
    include Functional
    def call r
      request = r.params
      rv = yield
      response = rv
      rv
    ensure
      InfoSig.log.debug(
        request:  request,
        response: response
      )
    end
  end
end