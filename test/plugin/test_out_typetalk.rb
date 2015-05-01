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

  CONFIG_THROTTLE = %[
    type typetalk
    client_id 123456
    client_secret secret
    topic_id 1
    message notice : %s
    out_keys message
    interval 5
    limit 1
  ]

  CONFIG_NO_THROTTLE = %[
    type typetalk
    client_id 123456
    client_secret secret
    topic_id 1
    message notice : %s
    out_keys message
    interval 0
    limit 0
  ]

  CONFIG_TRUNCATE = %[
    type typetalk
    client_id 123456
    client_secret secret
    topic_id 1
    message %s
    out_keys message
    truncate_message true
  ]


  def create_driver(conf = CONFIG, tag = 'test')
    Fluent::Test::OutputTestDriver.new(Fluent::TypetalkOutput, tag).configure(conf)
  end

  def test_configure
    d = create_driver()
    assert_equal '123456', Typetalk.config.client_id
    assert_equal 'secret', Typetalk.config.client_secret
    assert_equal 60, d.instance.instance_variable_get(:@interval)
    assert_equal 10, d.instance.instance_variable_get(:@limit)
    assert_equal true, d.instance.instance_variable_get(:@need_throttle)
  end

  def test_configure_no_throttle
    d = create_driver(CONFIG_NO_THROTTLE)
    assert_equal false, d.instance.instance_variable_get(:@need_throttle)
  end

  def test_write
    d = create_driver()
    mock(d.instance.typetalk).post_message(1, 'notice : test1')
    d.emit({'message' => 'test1'})
    d.run()
  end

  def test_template
    d = create_driver(CONFIG, 'warn')
    d.instance.message = "notice : %s [%s]"
    d.instance.out_keys = ["message", "time"]
    mock(d.instance.typetalk).post_message(1, "notice : test1 [1399910738]")

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
      raise Typetalk::InvalidRequest, {status:400, headers:{}, body:'{"error":"invalid_client", "error_description":""}'}.to_json
    }
    stub(d.instance.log).error {|name, params|
      assert_equal "out_typetalk:", name
      assert_equal Fluent::TypetalkError, params[:error_class]
      assert_equal "failed to post, msg: invalid_client, code: 400", params[:error]
    }
    d.emit({'message' => 'test1'})
    d.run()
  end

  def test_post_message_maxlength_error
    d = create_driver()
    stub(d.instance.typetalk).post_message(1, 'notice : test1') {
      raise Typetalk::InvalidRequest, {status:400, headers:{}, body:'{"errors":[{"field":"message", "name":"error.maxLength", "message":"Maximum length is 4,096 characters."}]}'}.to_json
    }
    stub(d.instance.log).error {|name, params|
      assert_equal "out_typetalk:", name
      assert_equal Fluent::TypetalkError, params[:error_class]
      assert_equal "failed to post, msg: message : Maximum length is 4,096 characters., code: 400", params[:error]
    }
    d.emit({'message' => 'test1'})
    d.run()
  end

  def test_post_message_notfound_error
    d = create_driver()
    stub(d.instance.typetalk).post_message(1, 'notice : test1') {
      raise Typetalk::NotFound, {status:404, headers:{}, body:'{"errors":[]}'}.to_json
    }
    stub(d.instance.log).error {|name, params|
      assert_equal "out_typetalk:", name
      assert_equal Fluent::TypetalkError, params[:error_class]
      assert_equal "failed to post, msg: , code: 404", params[:error]
    }
    d.emit({'message' => 'test1'})
    d.run()
  end

  def test_oauth2_error
    d = create_driver()
    stub(d.instance.typetalk).post_message(1, 'notice : test1') {
      raise Typetalk::InvalidRequest, {status:400, headers:'{"www-authenticate": "Bearer error=\"invalid_scope\""}', body:""}.to_json
    }
    stub(d.instance.log).error {|name, params|
      assert_equal "out_typetalk:", name
      assert_equal Fluent::TypetalkError, params[:error_class]
      assert_equal "failed to post, msg: Bearer error=\"invalid_scope\", code: 400", params[:error]
    }
    d.emit({'message' => 'test1'})
    d.run()
  end

  def test_throttle
    d = create_driver(CONFIG_THROTTLE)
    mock(d.instance.typetalk).post_message(1, 'notice : test1')
    mock(d.instance.typetalk).post_message(1, 'notice : test3')
    stub(d.instance.log).error {|name, params|
      assert_equal "out_typetalk:", name
      assert_equal "number of posting message within 5.0(sec) reaches to the limit 1", params[:error]
    }
    d.emit({'message' => 'test1'})
    d.emit({'message' => 'test2'})
    sleep 5
    d.emit({'message' => 'test3'})
    d.run()
  end

  def test_truncate
    d = create_driver(CONFIG_TRUNCATE)
    mock(d.instance.typetalk).post_message(1, '1')
    mock(d.instance.typetalk).post_message(1, '1'*4095)
    mock(d.instance.typetalk).post_message(1, '1'*4091 + ' ...')
    d.emit({'message' => '1'})
    d.emit({'message' => '1'*4095}) # not truncated
    d.emit({'message' => '1'*4096}) # should be truncated
    d.run()
  end

end
