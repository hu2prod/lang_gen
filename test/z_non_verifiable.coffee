assert = require 'assert'
coffee_gen = require('ast2coffee').gen
ast_gen    = require('../src/exp_node2ast_trans').gen

describe 'non verifiable section', ()->
  _tokenize = null
  _parse = null
  tokenize = null
  parse = null
  run = (str)->
    tok = _tokenize str
    ast = _parse tok, mode_full:true
    ast_g= ast_gen ast[0],
      require : (path)->
        # MOCK as eval (for simplier testing)
        tok1 = _tokenize path
        ast1 = _parse tok1, mode_full:true
        [ast1[0]]
    
    coffee_gen ast_g
  it 'init', ()->
    {_tokenize, tokenize} = require('../tok.gen.coffee')
    {_parse, parse}    = require('../gram.gen.coffee')
  
  describe 'fn_decl', ()->
    it 'a()->', ()->
      assert.equal run("a()->"), "a = ()->\n  "
    it 'a(b)->', ()->
      assert.equal run("a(b)->"), "a = (b)->\n  "
    
  
  describe 'class_decl', ()->
  
  
