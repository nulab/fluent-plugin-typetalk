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
    template <%= record.to_json %>
  ]

  def create_driver(conf = CONFIG, tag = 'test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::TypetalkOutput, tag).configure(conf)
  end

  def test_configure
    d = create_driver()
    assert_equal d.instance.typetalk.instance_variable_get(:@client_id), '123456'
    assert_equal d.instance.typetalk.instance_variable_get(:@client_secret), 'secret'
  end

  def test_write
    d = create_driver()
    stub(d.instance.typetalk).post(1, '{"message":"test1"}')
    d.emit({'message' => 'test1'})
    d.run()
  end

  def test_template
    d = create_driver(CONFIG, 'warn')
    d.instance.template = "<%= tag %> at <%= Time.at(time).localtime %>\n<%= record.to_json %>"
    stub(d.instance.typetalk).post(1, "warn at 2014-05-13 01:05:38 +0900\n{\"message\":\"test1\"}")

    ENV["TZ"]="Asia/Tokyo"
    t = Time.strptime('2014-05-13 01:05:38', '%Y-%m-%d %T')
    d.emit({'message' => 'test1'}, t)
    d.run()
  end

end