module Fluent
  class TypetalkOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('typetalk', self)

    config_param :client_id, :string
    config_param :client_secret, :string
    config_param :topic_id, :integer
    config_param :template, :string, :default => "<%= tag %> at <%= Time.at(time).localtime %>\n<%= record.to_json %>"
    config_param :flush_interval, :time, :default => 1

    attr_reader :typetalk

    # Define `log` method for v0.10.42 or earlier
    # see http://blog.livedoor.jp/sonots/archives/36150373.html
    unless method_defined?(:log)
      define_method("log") { $log }
    end

    def initialize
      super
      require 'erb'
    end

    def configure(conf)
      super
      @typetalk = Typetalk.new(conf['client_id'], conf['client_secret'])
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
      message = ERB.new(@template).result(binding)
      @typetalk.post(@topic_id, message)
    end

  end

  class Typetalk

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
        { 'Authorization' => "Bearer #{@access_token}" }
      )

      # todo: handling 429
      unless res and res.is_a?(Net::HTTPSuccess)
        raise TypetalkError, "failed to post to typetalk.in, code: #{res && res.code}"
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
        params
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
