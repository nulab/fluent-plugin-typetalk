# coding: utf-8

require 'helper'

class TypetalkOutputTest < Test::Unit::TestCase
  
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    type typetalk
    client_id 123456
    client_secret secret
    topic_id 1
  ]

  def create_driver(conf = CONFIG, tag = 'test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::TypetalkOutput, tag).configure(conf)
  end

  def test_configure
    d = create_driver()
    assert_equal d.instance.typetalk.instance_variable_get(:@client_id), '123456'
    assert_equal d.instance.typetalk.instance_variable_get(:@client_secret), 'secret'
  end

#  def test_send_message
#    d = create_driver(<<-EOF)
#                      type typetalk
#                      client_id <your client_id>
#                      client_secret <your client_secret>
#                      topic_id <your topic>
#                      EOF
#    d.emit({'message' => 'test1'})
#    d.emit({'message' => 'test2日本語'})
#    d.run
#  end

end