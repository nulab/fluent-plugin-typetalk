module Fluent
    class TypetalkOutput < Fluent::BufferedOutput
        Fluent::Plugin.register_output('typetalk', self)

    end
end
