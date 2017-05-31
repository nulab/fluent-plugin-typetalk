require "bundler/setup"
$LOAD_PATH.unshift(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift(__dir__)

require 'test/unit'
require 'test/unit/rr'
require 'fluent/test'
require 'fluent/test/driver/output'
require 'fluent/test/helpers'
