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
    
    it '1+2', ()->
      assert.equal run("1+2"), "(1 + 2)"
    
    it '1.0', ()->
      assert.equal run("1.0"), "1.0"
    
    it '1.0+2.0', ()->
      assert.equal run("1.0+2.0"), "(1.0 + 2.0)"
    
    it 'true', ()->
      assert.equal run("true"), "true"
    
    it '!true', ()->
      assert.equal run("!true"), "!(true)"
    
    it 'a++', ()->
      assert.equal run("var a:int\na++"), "(a)++"
    
    it '#a', ()->
      assert.equal run("#a"), ""
    
    # BUG
    # it '###a###', ()->
      # assert.equal run("###a###"), ""
    
    it '###\\na###', ()->
      assert.equal run("###\na###"), ""
    
    it 'var a : int', ()->
      assert.equal run("var a:int"), ""
    
    it 'var a : int;a', ()->
      assert.equal run("var a:int\na"), "a"
    
    # not properly validated
    describe 'throws', ()->
      it 'a', ()->
        assert.throws ()-> run("a")
      
      it '1&2.0', ()->
        assert.throws ()-> run("1&2.0")
      
      it 'a++ string', ()->
        assert.throws ()-> run("var a:string\na++")
  
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
      assert.equal run("""
        a(b: int):int->
          b
        """), """
        a = (b)->
          b
        """
    
    it 'a():void->\n  # comment\nb():void->', ()->
      assert.equal run("""
        a():void->
          # comment
        b():void->
        """), """
        a = ()->
          
        b = ()->
          
        """
  
  describe 'class_decl', ()->
    it 'class a', ()->
      assert.equal run("class a"), """
        class a
          
        
        """
    
    it 'class a class b', ()->
      assert.equal run("""
        class a
        class b
        """), """
        class a
          
        
        class b
          
        
        """
    
    it 'class a class b sp', ()->
      assert.equal run("""
        class a
        
        class b
        """), """
        class a
          
        
        class b
          
        
        """
    
    it 'class a class b sp2', ()->
      assert.equal run("""
        class a
        
        
        class b
        """), """
        class a
          
        
        class b
          
        
        """
    
    it 'class a var b : int', ()->
      assert.equal run("""
        class a
          var b : int
        """), """
        class a
          b : 0
        
        """
    
    it 'class a var b : int var c: int', ()->
      assert.equal run("""
        class a
          var b : int
          var c : int
        """), """
        class a
          b : 0
          c : 0
        
        """
    
    it 'class a var b : int var c: int sp', ()->
      assert.equal run("""
        class a
          var b : int
          
          var c : int
        """), """
        class a
          b : 0
          c : 0
        
        """
    
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
    
    it 'class a var b : int class b var b : int sp', ()->
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
    
    it 'class a var b : int class b var b : int sp2', ()->
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