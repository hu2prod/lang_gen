assert = require 'assert'
require 'shelljs/global'

mod = require '../src/index.coffee'

describe 'index section', ()->
  it 'mixin constructor', ()->
    rm '*gen.coffee'