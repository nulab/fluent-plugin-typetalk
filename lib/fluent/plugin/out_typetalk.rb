module Fluent
  class TypetalkOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('typetalk', self)

    config_param :client_id, :string
    config_param :client_secret, :string
    config_param :topic_id, :integer
    config_param :template, :string, :default => "<%= tag %> at <%= Time.at(time).localtime %>\n<%= record.to_json %>"
    config_param :flush_interval, :time, :default => 1

    attr_reader :typetalk

    def initialize
      super
      require 'net/https'
      require 'uri'
      require 'json'
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
          $log.error("Typetalk Error:", :error_class => e.class, :error => e.message)
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
      @client_id = client_id
      @client_secret = client_secret
    end

    def post(topic_id, message)
      http = Net::HTTP.new('typetalk.in', 443)
      http.use_ssl = true
      res = http.post(
        '/oauth2/access_token',
        "client_id=#{@client_id}&client_secret=#{@client_secret}&grant_type=client_credentials&scope=topic.post"
      )
      json = JSON.parse(res.body)
      access_token = json['access_token']

      http.post(
        "/api/v1/topics/#{topic_id}",
        "message=#{message}",
        { 'Authorization' => "Bearer #{access_token}" }
      )

#      req = Net::HTTP::Post.new("/api/v1/topics/#{topic_id}")
#      req['Authorization'] = "Bearer #{access_token}"
#      req.set_form_data({:message=>message})
#      http.request(req)
      
    end

    def get_token


    end



  end

end
