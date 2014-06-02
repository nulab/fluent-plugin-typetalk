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
    message notice : %s
    out_keys message
  ]

  def create_driver(conf = CONFIG, tag = 'test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::TypetalkOutput, tag).configure(conf)
  end

  def test_configure
    d = create_driver()
    assert_equal '123456', Typetalk.config.client_id
    assert_equal 'secret', Typetalk.config.client_secret
  end

  def test_write
    d = create_driver()
    stub(d.instance.typetalk).post_message(1, 'notice : test1')
    d.emit({'message' => 'test1'})
    d.run()
  end

  def test_template
    d = create_driver(CONFIG, 'warn')
    d.instance.message = "notice : %s [%s]"
    d.instance.out_keys = ["message", "time"]
    stub(d.instance.typetalk).post_message(1, "notice : test1 [1399910738]")

    ENV["TZ"]="Asia/Tokyo"
    t = Time.strptime('2014-05-13 01:05:38', '%Y-%m-%d %T')
    d.emit({'message' => 'test1'}, t)
    d.run()
  end

  def test_post_message_unauthorized_error
    d = create_driver()
    stub(d.instance.typetalk).post_message(1, 'notice : test1') {
      raise Typetalk::Unauthorized, {status:401, headers:{}, body:''}.to_json
    }
    stub(d.instance.log).error {|name, params|
      assert_equal "out_typetalk:", name
      assert_equal Fluent::TypetalkError, params[:error_class]
      assert_equal "invalid credentials used. check client_id and client_secret in your configuration.", params[:error]
    }
    d.emit({'message' => 'test1'})
    d.run()
  end

  def test_post_message_invalid_request_error
    d = create_driver()
    stub(d.instance.typetalk).post_message(1, 'notice : test1') {
      raise Typetalk::InvalidRequest, {status:400, headers:{}, body:'{"error":"invalid_client","error_description":""}'}.to_json
    }
    stub(d.instance.log).error {|name, params|
      assert_equal "out_typetalk:", name
      assert_equal Fluent::TypetalkError, params[:error_class]
      assert_equal "failed to post, msg: invalid_client, code: 400", params[:error]
    }
    d.emit({'message' => 'test1'})
    d.run()
  end

  def test_post_message_notfound_error
    d = create_driver()
    stub(d.instance.typetalk).post_message(1, 'notice : test1') {
      raise Typetalk::NotFound, {status:404, headers:{}, body:''}.to_json
    }
    stub(d.instance.log).error {|name, params|
      assert_equal "out_typetalk:", name
      assert_equal Fluent::TypetalkError, params[:error_class]
      assert_equal "failed to post, msg: , code: 404", params[:error]
    }
    d.emit({'message' => 'test1'})
    d.run()
  end

end
