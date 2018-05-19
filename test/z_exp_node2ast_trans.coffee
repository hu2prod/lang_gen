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
    ast_g= ast_gen ast[0],
      require : (path)->
        # MOCK as eval (for simplier testing)
        tok1 = _tokenize path
        ast1 = _parse tok1, mode_full:true
        [ast1[0]]
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
    
    # не реализована
    # it '+1', ()->
    #   assert.equal run("+1"), "+1"
    
    it '1+2', ()->
      assert.equal run("1+2"), "(1 + 2)"
    
    it '1 + 2', ()->
      assert.equal run("1 + 2"), "(1 + 2)"
    
    it '1+ 2', ()->
      assert.equal run("1+ 2"), "(1 + 2)"
    
    # а вот так нельзя
    # it '1 +2', ()->
    #   assert.equal run("1 +2"), "(1 + 2)"
    
    it '1+2*3', ()->
      assert.equal run("1+2*3"), "(1 + (2 * 3))"
    
    it '(1+2)*3', ()->
      assert.equal run("(1+2)*3"), "((1 + 2) * 3)"
    
    it '1.0', ()->
      assert.equal run("1.0"), "1.0"
    
    it '1.0+2.0', ()->
      assert.equal run("1.0+2.0"), "(1.0 + 2.0)"
    
    it 'true', ()->
      assert.equal run("true"), "true"
    
    it '!true', ()->
      assert.equal run("!true"), "!(true)"
    
    it 'true && false', ()->
      assert.equal run("true && false"), "(true && false)"
    
    it 'true and false', ()->
      assert.equal run("true and false"), "(true && false)"
    
    it 'a++', ()->
      assert.equal run("var a:int\na++"), "(a)++"
    
    it 'a', ()->
      assert.equal run("var a:int\n(a)"), "a"
    
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
    
    it 'var a : string; a[1]', ()->
      assert.equal run("var a:string\na[1]"), "(a)[1]"
    
    it 'var a : string; var b : string; a[1]', ()->
      assert.equal run("""
        var a:string
        var b:string
        b = a[1]
        """), "(b = (a)[1])"
    
    it 'var a : array<int>; a[1]', ()->
      assert.equal run("var a:array<int>\na[1]"), "(a)[1]"
    
    it 'var a : hash<int>;var b:string; a[b]', ()->
      assert.equal run("""
        var a:hash<int>
        var b:string
        a[b]
        """), "(a)[b]"
    
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
    it 'if 1 2 else 3', ()->
      assert.equal run(t = """
        if 1
          2
        else
          3
        """), t
    it 'if 1 2 else if 3 4', ()->
      assert.equal run(t = """
        if 1
          2
        else if 3
          4
        """), """
        if 1
          2
        else if 3
          4
        """
    it 'if 1 2 elseif 3 4', ()->
      assert.equal run(t = """
        if 1
          2
        elseif 3
          4
        """), """
        if 1
          2
        else if 3
          4
        """
    it 'if 1 2 elsif 3 4', ()->
      assert.equal run(t = """
        if 1
          2
        elsif 3
          4
        """), """
        if 1
          2
        else if 3
          4
        """
    it 'if 1 2 elif 3 4', ()->
      assert.equal run(t = """
        if 1
          2
        elif 3
          4
        """), """
        if 1
          2
        else if 3
          4
        """
    it '2 if 1', ()->
      assert.equal run(t = """
        2 if 1
        """), """
        if 1
          2
        """
    
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
      it 'if', ()->
        assert.throws ()-> run("""
          if
            2
          """)
      it 'loop', ()->
        assert.throws ()-> run("""
          loop 1
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
  
  describe 'this', ()->
    it '@.a', ()->
      assert.equal run("""
        var this:struct{a:int}
        @.a
        """), """
        (this).a
        """
    it '@a', ()->
      assert.equal run("""
        var this:struct{a:int}
        @a
        """), """
        (this).a
        """
  
  describe 'loop', ()->
    it 'loop break', ()->
      assert.equal run("""
        loop
          break
        """), """
        loop
          break
        """
    
    it 'loop break continue', ()->
      assert.equal run("""
        loop
          break
          continue
        """), """
        loop
          break
          continue
        """
  
  describe 'while', ()->
    it 'while true 1', ()->
      assert.equal run("""
        while true
          1
        """), """
        while true
          1
        """
  
  # switch is NOT working now
  describe 'switch', ()->
    it 'switch 1 when 2 3 else 4', ()->
      assert.equal run("""
        switch 1
          when 2
            3
        """), """
        switch 1
          when 2
            3
        """
    
    it 'switch 1 when 2 3 else 4', ()->
      assert.equal run("""
        switch 1
          when 2
            3
          else
            4
        """), """
        switch 1
          when 2
            3
          else
            4
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
      
      it 'fn call with []', ()->
        assert.equal run("""
          b():array<int> ->
            
          b()[0]
          """), """
          b = ()->
            
          ((b)())[0]
          """
      
      it 'a.b fn call', ()->
        assert.equal run("""
          class A
            b(arg:int):void->
          var a:A
          var c:int
          a.b c
          """), """
          class A
            b : (arg)->
              
          
          ((a).b)(c)
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
      
      describe 'array', ()->
        it 'constructor', ()->
          assert.equal run("""
            var a : array<int>
            a.new()
            """), """
            (a) = []
            """
        
        it 'sort_i', ()->
          assert.equal run("""
            var a : array<int>
            fn(a:int,b:int):int->
              return a-b
            a.sort_i(fn)
            """), """
            fn = (a, b)->
              return ((a - b))
            ((a).sort)(fn)
            """
      
      it 'constructor', ()->
        assert.equal run("""
          class C1
            a():void->
              
          var a : C1
          a.new()
          """), """
          class C1
            a : ()->
              
          
          (a) = new C1
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
  
  # describe 'require', ()->
    # it 'require \'1\'', ()->
      # assert.equal run("require '1'"), "1"
  
  describe 'closure', ()->
    it 'var a; a = ():void=>', ()->
      assert.equal run("""
        var a : function<void>
        a = ():void=>
          
        """), """
        (a = ()->
          )
        """
  
  describe 'struct_init', ()->
    it 'a:1', ()->
      assert.equal run("""
        a:1
        """), '''
        {"a": 1}
        '''
    it '\'a\':1', ()->
      assert.equal run("""
        'a':1
        """), '''
        {"a": 1}
        '''
    it '"a":1', ()->
      assert.equal run('''
        "a":1
        '''), '''
        {"a": 1}
        '''
    it 'a:1,b:2', ()->
      assert.equal run('''
        a:1,b:2
        '''), '''
        {"a": 1, "b": 2}
        '''
    it 'a:1,b:2,c:3', ()->
      assert.equal run('''
        a:1,b:2,c:3
        '''), '''
        {"a": 1, "b": 2, "c": 3}
        '''
    
    it '{}', ()->
      assert.equal run('''
        {}
        '''), '''
        {}
        '''
    it '{a:1}', ()->
      assert.equal run('''
        {a:1}
        '''), '''
        {"a": 1}
        '''
    it '{a:1,b:2}', ()->
      assert.equal run('''
        {a:1,b:2}
        '''), '''
        {"a": 1, "b": 2}
        '''
    it '{a:1,b:2,c:3}', ()->
      assert.equal run('''
        {a:1,b:2,c:3}
        '''), '''
        {"a": 1, "b": 2, "c": 3}
        '''
    
    it 'c = a:1', ()->
      assert.equal run('''
        var c : struct{a:int}
        c = a:1
        '''), '''
        (c = {"a": 1})
        '''
    it 'c = a:1,b:2', ()->
      assert.equal run('''
        var c : struct{a:int,b:int}
        c = a:1,b:2
        '''), '''
        (c = {"a": 1, "b": 2})
        '''
    it 'c = a:1,b:2,c:3', ()->
      assert.equal run('''
        var c : struct{a:int,b:int,c:int}
        c = a:1,b:2,c:3
        '''), '''
        (c = {"a": 1, "b": 2, "c": 3})
        '''
    
    it 'var c : struct{}', ()->
      assert.equal run('''
        var c : struct{}
        '''), ''
    
    it 'var c : struct{} c = {}', ()->
      assert.equal run('''
        var c : struct{}
        c = {}
        '''), '''
        (c = {})
        '''
    it 'var c : struct{a:int} c = {}', ()->
      assert.throws ()->
        run '''
          var c : struct{a:int}
          c = {}
          '''
    it 'c = {a:1}', ()->
      assert.equal run('''
        var c : struct{a:int}
        c = {a:1}
        '''), '''
        (c = {"a": 1})
        '''
    it 'c = {a:1,b:2}', ()->
      assert.equal run('''
        var c : struct{a:int,b:int}
        c = {a:1,b:2}
        '''), '''
        (c = {"a": 1, "b": 2})
        '''
    it 'c = {a:1,b:2,c:3}', ()->
      assert.equal run('''
        var c : struct{a:int,b:int,c:int}
        c = {a:1,b:2,c:3}
        '''), '''
        (c = {"a": 1, "b": 2, "c": 3})
        '''
    
    it 'c =\n a:1', ()->
      assert.equal run('''
        var c : struct{a:int}
        c =
          a:1
        '''), '''
        (c = {"a": 1})
        '''
    it 'c =\n a:1\nb:1', ()->
      assert.equal run('''
        var c : struct{a:int,b:int}
        c =
          a:1
          b:1
        '''), '''
        (c = {"a": 1, "b": 1})
        '''
    it 'c =\n a:1,\nb:1', ()->
      assert.equal run('''
        var c : struct{a:int,b:int}
        c =
          a:1,
          b:1
        '''), '''
        (c = {"a": 1, "b": 1})
        '''
    it 'c =\n a:1,b:1', ()->
      assert.equal run('''
        var c : struct{a:int,b:int}
        c =
          a:1,b:1
        '''), '''
        (c = {"a": 1, "b": 1})
        '''
    
    it 'c a:1', ()->
      assert.equal run('''
        var c : function<void,struct{a:int}>
        c a:1
        '''), '''
        (c)({"a": 1})
        '''
    
    it 'c a:1,b:1', ()->
      assert.equal run('''
        var c : function<void,struct{a:int,b:int}>
        c a:1,b:1
        '''), '''
        (c)({"a": 1, "b": 1})
        '''
  
  
