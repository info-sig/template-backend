require_relative 'config/environment'

# set CORS
# use Rack::Cors do
#   allow do
#     origins '*'
#     resource '*', :headers => :any, :methods => [:get, :post, :options, :put, :patch], :expose  => ['X-total-count', 'X-per-page']
#   end
# end

# set assets
use Rack::Static, :urls => ['/static',  '/favicon.ico'], :root => 'public', :index => 'index.html'

run InfoSigRodaApp.freeze.app
