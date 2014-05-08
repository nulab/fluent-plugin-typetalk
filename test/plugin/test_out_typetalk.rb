require 'helper'

class TypetalkOutputTest < Test::Unit::TestCase
  
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
  ]

  def create_driver(conf = CONFIG, tag = 'test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::TypetalkOutput, tag).configure(conf)
  end

  def test_configure
  end

  def test_write
    d = create_driver
  end

end