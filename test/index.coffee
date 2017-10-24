assert = require 'assert'
require 'shelljs/global'

describe 'index section', ()->
  it 'test init', ()->
    rm '*gen.coffee'
  
  _tokenize = null
  _parse = null
  run = (str)->
    tok = _tokenize str
    ast = _parse tok
  
  it 'gen_sfa', ()->
    require '../gen_sfa.coffee'
    _tokenize = require('../tok.gen.coffee')._tokenize
    _parse    = require('../gram.gen.coffee')._parse
  
  str_list = """
    a
    +a
    a+b
    """.split /\n/g
  for str in str_list
    do (str)->
      it "parses '#{str}'", ()->
        run str
  
  # it 'test finish', ()->
    # rm '*gen.coffee'
  