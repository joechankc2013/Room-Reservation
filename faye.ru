require 'faye'
require 'faye/websocket'
require 'yaml'
APP_CONFIG = YAML.load_file(File.expand_path('../config/config.yml', __FILE__))
FAYE_TOKEN = APP_CONFIG["push"]["token"]

class ServerAuth
  def incoming(message, callback)
    if message['channel'] !~ %r{^/meta/}
      if !message['ext'] || message['ext']['auth_token'] != FAYE_TOKEN
        message['error'] = 'Invalid authentication token.'
      end
    end
    callback.call(message)
  end
end

Faye::WebSocket.load_adapter('thin')
faye_server = Faye::RackAdapter.new(:mount => '/', :timeout => 45)
faye_server.add_extension(ServerAuth.new)
run faye_server