module Fluent
  class TypetalkOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('typetalk', self)

    def initialize
      super
      # require 'something'
    end

    def configure(conf)
      super
    end

    def start
      super
      # init
    end

    def shutdown
      super
      # destroy
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      # write records
    end
  end
end
