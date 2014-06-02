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
      require 'typetalk'
    end

    def configure(conf)
      super
      Typetalk.configure do |c|
        c.client_id = conf['client_id']
        c.client_secret = conf['client_secret']
        c.scope = 'topic.post'
        c.user_agent = "fluent-plugin-typetalk Ruby/#{RUBY_VERSION}"
      end
      @typetalk = Typetalk::Api.new
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
      begin
        @typetalk.post_message(@topic_id, message)
      rescue Typetalk::Unauthorized
        raise TypetalkError, "invalid credentials used. check client_id and client_secret in your configuration."
      rescue => e
        msg = ''
        res = JSON.parse(e.message) rescue {}
        unless res['body'].nil?
          body = JSON.parse(res['body']) rescue {}
          msg = body['error']
        end
        raise TypetalkError, "failed to post, msg: #{msg}, code: #{res['status']}"
      end
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

  class TypetalkError < RuntimeError; end

end
