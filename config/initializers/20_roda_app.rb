class InfoSigRodaApp < Roda

  plugin :multi_route
  plugin :basic_auth
  plugin :json

  route do |r|

    # sidekiq admin
    r.on "sidekiq" do
      r.run Sidekiq::Web
    end

    r.multi_route
  end

end
