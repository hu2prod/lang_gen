assert = require 'assert'
coffee_gen = require('ast2coffee').gen
ast_gen    = require('../src/exp_node2ast_trans').gen

describe 'exp_node2ast_trans section', ()->
  _tokenize = null
  _parse = null
  tokenize = null
  parse = null
  run = (str)->
    tok = _tokenize str
    ast = _parse tok
    ast_g= ast_gen ast[0]
    ast_g.validate()
    coffee_gen ast_g
  
  it 'init gen_sfa', ()->
    require '../gen_sfa.coffee'
    {_tokenize, tokenize} = require('../tok.gen.coffee')
    {_parse, parse}    = require('../gram.gen.coffee')
  
  it '1', ()->
    assert.equal run("1"), "1"
  
  it 'var a : int', ()->
    assert.equal run("var a:int"), ""
  
  it 'var a : int;a', ()->
    assert.equal run("var a:int\na"), "a"
  
  # not properly validated
  describe 'throws', ()->
    it 'a', ()->
      assert.throws ()-> run("a")