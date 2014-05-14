module Fluent
  class TypetalkOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('typetalk', self)

    config_param :client_id, :string
    config_param :client_secret, :string
    config_param :topic_id, :integer
    config_param :flush_interval, :time, :default => 1

    config_param :message, :string
    config_param :out_keys, :string, :default => ""
    config_param :time_key, :string, :default => 'time'
    config_param :time_format, :string, :default => nil
    config_param :tag_key, :string, :default => 'tag'

    attr_reader :typetalk

    # Define `log` method for v0.10.42 or earlier
    # see http://blog.livedoor.jp/sonots/archives/36150373.html
    unless method_defined?(:log)
      define_method("log") { $log }
    end

    def initialize
      super
      require 'socket'
    end

    def configure(conf)
      super
      @typetalk = Typetalk.new(conf['client_id'], conf['client_secret'])
      @hostname = Socket.gethostname

      @out_keys = @out_keys.split(',')

      begin
        @message % (['1'] * @out_keys.length)
      rescue ArgumentError
        raise Fluent::ConfigError, "string specifier '%s' and out_keys specification mismatch"
      end

      if @time_format
        f = @time_format
        tf = Fluent::TimeFormatter.new(f, true) # IRC notification is formmatted as localtime only...
        @time_format_proc = tf.method(:format)
        @time_parse_proc = Proc.new {|str| Time.strptime(str, f).to_i }
      else
        @time_format_proc = Proc.new {|time| time.to_s }
        @time_parse_proc = Proc.new {|str| str.to_i }
      end

    end

    def start
      super
    end

    def shutdown
      super
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each do |(tag,time,record)|
        begin
          send_message(tag, time, record)
        rescue => e
          log.error("out_typetalk:", :error_class => e.class, :error => e.message)
        end
      end
    end

    def send_message(tag, time, record)
      message = evaluate_message(tag, time, record)
      @typetalk.post(@topic_id, message)
    end

    def evaluate_message(tag, time, record)

      values = out_keys.map do |key|
        case key
        when @time_key
          @time_format_proc.call(time)
        when @tag_key
          tag
        when "$hostname"
          @hostname
        else
          record[key].to_s
        end
      end

      (message % values).gsub(/\\n/, "\n")
    end

  end

  class Typetalk

    USER_AGENT = "fluent-plugin-typetalk Ruby/#{RUBY_VERSION}"

    def initialize(client_id, client_secret)
      require 'net/http'
      require 'uri'
      require 'json'

      @client_id = client_id
      @client_secret = client_secret

      @http = Net::HTTP.new('typetalk.in', 443)
      @http.use_ssl = true
    end

    def post(topic_id, message)
      check_token()
      $log.debug("Typetalk access_token : #{@access_token}")

      res = @http.post(
        "/api/v1/topics/#{topic_id}",
        "message=#{message}",
        { 'Authorization' => "Bearer #{@access_token}", 'User-Agent' => USER_AGENT }
      )

      # todo: handling 429
      unless res and res.is_a?(Net::HTTPSuccess)
        msg = ""
        unless res.body.nil?
          json = JSON.parse(res.body)
          msg = json.fetch('errors', [])[0].fetch('message',"")
        end
        raise TypetalkError, "failed to post, msg: #{msg}, code: #{res.code}"
      end

    end

    def check_token

      if @access_token.nil?
        update_token()
      elsif Time.now >= @expires
        update_token(true)
      end

    end

    def update_token(refresh = false)
      params = "client_id=#{@client_id}&client_secret=#{@client_secret}"
      unless refresh
        params << "&grant_type=client_credentials&scope=topic.post"
      else
        params << "&grant_type=refresh_token&refresh_token=#{@refresh_token}"
      end

      res = @http.post(
        "/oauth2/access_token",
        params,
        { 'User-Agent' => USER_AGENT }
      )

      if res.is_a?(Net::HTTPUnauthorized)
        raise TypetalkError, "invalid credentials used. check client_id and client_secret in your configuration."
      end

      unless res.is_a?(Net::HTTPSuccess)
        raise TypetalkError, "unexpected error occured in getting access_token, code: #{res && res.code}"
      end

      json = JSON.parse(res.body)
      @expires = Time.now + json['expires_in'].to_i
      @refresh_token = json['refresh_token']
      @access_token = json['access_token']
    end

  end

  class TypetalkError < RuntimeError; end

end
