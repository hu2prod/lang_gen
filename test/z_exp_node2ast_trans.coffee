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
  
  describe 'simple', ()->
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
  
  describe 'fn_decl', ()->
    it 'a():void->', ()->
      assert.equal run("a():void->"), "a = ()->\n  "
    
    it 'a(b:int):void->', ()->
      assert.equal run("a(b:int):void->"), "a = (b)->\n  "
    
    it 'a(b:int, c:float):void->', ()->
      assert.equal run("a(b: int, c: float):void->"), "a = (b, c)->\n  "
    
    it 'a(b:int):int->b', ()->
      assert.equal run("a(b: int):int->b"), "a = (b)->\n  b"
    
    it 'a(b:int):int->\n  b', ()->
      assert.equal run("a(b: int):int->\n  b"), "a = (b)->\n  b"
  
  describe 'class_decl', ()->
    it 'class a', ()->
      assert.equal run("class a"), "class a\n  "
    
    it 'class a class b', ()->
      assert.equal run("""
        class a
        class b
        """), """
        class a
          
        class b
          
        """
    
    it 'class a var b : int', ()->
      assert.equal run("class a\n  var b : int"), "class a\n  b : 0"
    
    it 'class a var b : int class b var b : int', ()->
      assert.equal run("""
        class a
          var b : int
        class b
          var b : int
        """), """
        class a
          b : 0
        class b
          b : 0
        """