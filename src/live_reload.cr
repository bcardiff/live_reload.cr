require "http"
require "json"
require "log"

module LiveReload
  VERSION = "0.1.0"

  Log = ::Log.for(self)

  SCRIPT = %(<script>document.write('<script src="http://' + (location.host || 'localhost').split(':')[0] + ':35729/livereload.js"></' + 'script>')</script>)

  # :nodoc:
  class Connection
    OFFICIAL_7 = "http://livereload.com/protocols/official-7"

    @hello_received = false

    def initialize(@ws : HTTP::WebSocket, @connections : ConnectionsRegistry)
      @connections.register(self)
    end

    def start
      @ws.on_message do |message|
        process message
      end

      send command: "hello" do |json|
        json.field "protocols" do
          json.array do
            json.string OFFICIAL_7
          end
        end
        json.field "serverName", "live_reload.cr"
      end
    end

    def process(message : String)
      json_message =
        begin
          JSON.parse(message)
        rescue
          close "Invalid JSON message"
          return
        end

      case json_message["command"].as_s?
      when nil
        close "Missing command"
      when "hello"
        if @hello_received
          close "'hello' command already received"
        else
          protocols = json_message["protocols"].as_a?.try(&.map(&.as_s?)).try(&.compact)
          if protocols && protocols.includes?(OFFICIAL_7)
            @hello_received = true
          else
            close "Unsuitable list of protocols"
          end
        end
      when "info"
        # Discard
      else
        Log.warn &.emit("Unsupported command", data: {message: message})
      end
    end

    def close(reason : String)
      @ws.close(:normal_closure, "Invalid JSON message") rescue nil
      @connections.remove(self)
    end

    def send(*, command : String, **args, & : JSON::Builder -> _)
      message = JSON.build do |json|
        json.object do
          json.field "command", command
          args.each do |key, value|
            json.field key, value
          end
          yield json
        end
      end

      begin
        @ws.send(message)
      rescue
        close("Unable to send message")
      end
    end
  end

  # :nodoc:
  class ConnectionsRegistry
    @connections = Array(Connection).new
    @connections_lock = Mutex.new

    def register(connection : Connection)
      @connections_lock.synchronize do
        @connections << connection
      end
    end

    def remove(connection : Connection)
      spawn do
        # spawn to allow calls to #remove while iterating them
        @connections_lock.synchronize do
          @connections.delete(connection)
        end
      end
    end

    def each(& : Connection ->)
      @connections_lock.synchronize do
        @connections.each do |connection|
          yield connection
        end
      end
    end
  end

  module Commands
    abstract def send(*, command : String, **args, & : JSON::Builder -> _)

    def send(*, command : String, **args)
      send(**args, command: command) do |json|
      end
    end

    def send_reload(path : String, liveCSS : Bool)
      send(command: "reload", path: path, liveCSS: liveCSS)
    end

    def send_alert(message : String)
      send(command: "alert", message: message)
    end
  end

  class Server
    include Commands

    property http_server : HTTP::Server
    getter address : Socket::Address

    def initialize
      @connections = ConnectionsRegistry.new
      @http_server = HTTP::Server.new([
        ScriptHandler.new,
        HTTP::WebSocketHandler.new do |ws, ctx|
          Connection.new(ws, @connections).start
        end,
      ])
      @address = @http_server.bind_tcp "0.0.0.0", 35729
    end

    def listen
      @http_server.listen
    end

    def send(*, command : String, **args, &block : JSON::Builder -> _)
      @connections.each &.send(**args, command: command, &block)
    end
  end

  class ScriptHandler
    include HTTP::Handler

    def call(context)
      if context.request.path == "/livereload.js"
        static_content = {{ read_file("#{__DIR__}/livereload-js.3.3.1/livereload.min.js") }}
        context.response.content_type = MIME.from_filename("livereload.js")
        context.response.content_length = static_content.size
        context.response << static_content
      else
        call_next(context)
      end
    end
  end
end
