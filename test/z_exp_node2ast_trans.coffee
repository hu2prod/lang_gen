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
    ast = _parse tok, mode_full:true
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
    
    it '\\n1', ()->
      assert.equal run("\n1"), "1"
    
    it '1+2', ()->
      assert.equal run("1+2"), "(1 + 2)"
    
    it '1+2*3', ()->
      assert.equal run("1+2*3"), "(1 + (2 * 3))"
    
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
    
    it 'var a : int; a = 1 + 1', ()->
      assert.equal run("var a:int\na = 1 + 1"), "(a = (1 + 1))"
    
    # not properly validated
    describe 'throws', ()->
      it 'a', ()->
        assert.throws ()-> run("a")
      
      it '1&2.0', ()->
        assert.throws ()-> run("1&2.0")
      
      it 'a++ string', ()->
        assert.throws ()-> run("var a:string\na++")
  
  describe 'control flow', ()->
    it 'if 1 2', ()->
      assert.equal run(t = """
        if 1
          2
        """), t
    
    it 'for i in [1 .. 10] 0', ()->
      assert.equal run(t = """
        var i : int
        for i in [1 .. 10]
          0
        """), """
        for i in [1 .. 10]
          0
        """
    
    it 'for i in [1 .. 10] by 2 0', ()->
      assert.equal run(t = """
        var i : int
        for i in [1 .. 10] by 2
          0
        """), """
        for i in [1 .. 10] by 2
          0
        """
    
    it 'for v in a 0', ()->
      assert.equal run(t = """
        var v : string
        var a : array<string>
        for v in a
          0
        """), """
        for v in a
          0
        """
    
    it 'for k,v in a 0', ()->
      assert.equal run(t = """
        var k : int
        var v : string
        var a : array<string>
        for k,v in a
          0
        """), """
        for v,k in a
          0
        """
    
    it 'for v in a 0 hash', ()->
      assert.equal run(t = """
        var v : int
        var a : hash<int>
        for v in a
          0
        """), """
        for _skip,v of a
          0
        """
    
    it 'for k,v in a 0 hash', ()->
      assert.equal run(t = """
        var k : string
        var v : int
        var a : hash<int>
        for k,v in a
          0
        """), """
        for k,v of a
          0
        """
    describe 'throws', ()->
      it 'wtf 1 2', ()->
        assert.throws ()-> run("""
          wtf 1
            2
          """)
  
  describe 'field_access', ()->
    it 'var a : struct{a: int};a.a', ()->
      assert.equal run("""
        var a : struct{a: int}
        a.a
        """), """
        (a).a
        """
    
    it 'var a : struct{a: int};a.a', ()->
      assert.equal run("""
        var a : struct{a: int}
        var b : int
        b = a.a
        """), """
        (b = (a).a)
        """
    
    it 'var a : array<int>;a.push(1)', ()->
      assert.equal run("""
        var a : array<int>
        a.push(1)
        """), """
        ((a).push)(1)
        """
    
    describe 'throws', ()->
      it 'var a : struct{a: int};a.b', ()->
        assert.throws ()-> assert.equal run("""
          var a : struct{a: int}
          a.b
          """)
  
  describe 'loop', ()->
    it 'loop break', ()->
      assert.equal run("""
        loop
          break
        """), """
        loop
          break
        """
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
    
    describe 'fn_call', ()->
      it 'simple', ()->
        assert.equal run("""
          b():void ->
            
          b()
          """), """
          b = ()->
            
          (b)()
          """
      
      it 'int', ()->
        assert.equal run("""
          b(a:int):void ->
            
          b(1)
          """), """
          b = (a)->
            
          (b)(1)
          """
      
      it 'int, int', ()->
        assert.equal run("""
          b(a:int, c:int):void ->
            
          b(1, 2)
          """), """
          b = (a, c)->
            
          (b)(1, 2)
          """
      
      it 'ret assign', ()->
        assert.equal run("""
          b():int ->
            
          var a : int
          a = b()
          """), """
          b = ()->
            
          (a = (b)())
          """
      
    describe 'fn return', ()->
      it 'void return', ()->
        assert.equal run("""
          b():void ->
            return
          
          """), """
          b = ()->
            return
          """
  
      it 'int return', ()->
        assert.equal run("""
          b():int ->
            return 1
          
          """), """
          b = ()->
            return (1)
          """
      describe 'throws', ()->
        it 'void return but decl int', ()->
          assert.throws ()-> run("""
            b():int ->
              return
            
            """)
    
        it 'int return but decl void', ()->
          assert.throws ()-> run("""
            b():void ->
              return 1
            
            """)
  
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
    
    it 'class a var b : int sp', ()->
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
    it 'complex1', ()->
      assert.equal run("""
        class World
          var agent_list : array<float>
          a():int->
          b():int->
          c():int->
        class Test1
          a():void->
            0
          b():void->
          c():void->

        """), """
        class World
          agent_list : []
          a : ()->
            
          b : ()->
            
          c : ()->
            
          constructor : ()->
            @agent_list = []

        class Test1
          a : ()->
            0
          b : ()->
            
          c : ()->
            
        
        """
    describe 'throws', ()->
      it 'class C1 var a: int;var a : C2;', ()->
        assert.throws ()-> run("""
          class C1
            var a : int
          var a : C2
          """)
    
    it 'class C1;var a : C1;var b : C1;a = b', ()->
      assert.equal run("""
        class C1
        var a : C1
        var b : C1
        a = b
        """), """
        class C1
          
        
        (a = b)
        """
    
    it 'class C1;var a : C1;var b : C1;a == b', ()->
      assert.equal run("""
        class C1
        var a : C1
        var b : C1
        a == b
        """), """
        class C1
          
        
        (a == b)
        """
    
    describe 'field_access', ()->
      it 'class C1 var a: int;var a : C1;a.a', ()->
        assert.equal run("""
          class C1
            var a : int
          var a : C1
          a.a
          """), """
          class C1
            a : 0
          
          (a).a
          """
      
      it 'fn_call', ()->
        assert.equal run("""
          class C1
            a():void->
              
          var a : C1
          a.a()
          """), """
          class C1
            a : ()->
              
          
          ((a).a)()
          """
      
      it 'class C1 var a: int;b():void -> this.a', ()->
        assert.equal run("""
          class C1
            var a : int
            b():void -> this.a
          
          """), """
          class C1
            a : 0
            b : ()->
              (this).a
          
          """
      describe 'throws', ()->
        it 'class C1 var a: int;var a : C1;a.b', ()->
          assert.throws ()-> run("""
            class C1
              var a : int
            var a : C1
            a.b
            """)