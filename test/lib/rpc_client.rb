require "websocket-client-simple"
require "msgpack/rpc/client"

class RpcClient
  include MessagePack::Rpc::Client

  class ErrorReturn < StandardError
    def initialize(data)
      super("error return")
      @data = data
    end

    attr_reader :data
  end

  def initialize(url)
    @url  = url
    @ws   = nil
    @hook = {}
    @que  = Queue.new
  end

  def connect
    raise("already opened") if @ws

    @ws = WebSocket::Client::Simple.connect(@url)

    hook = @hook
    que  = @que
    this = self

    @ws.on :message do |msg|
      this.receive_stream(msg.data)
    end

    @ws.on :open do
      hook[:connect].() if hook.include?(:connect)
      que << :open
    end

    @ws.on :close do |e|
      hook[:close].(e) if hook.include?(:close)
    end

    @ws.on :error do |e|
      hook[:error].(e) if hook.include?(:error)
    end

    que.deq
  end

  def send_data(data)
    @ws.send(data, :type => :binary)
  end
  private :send_data

  def call(meth, *args)
    super(meth, *args) {|*res| @que << res}

    res = @que.deq
    raise ErrorReturn.new(res[1]) if res[1]

    return res[0]
  end

  def close
    @ws.close
  end

  def on(type, &b)
    @hook[type] = b
  end
end
