require 'fy/codegen'

module.exports = (col)->
  return if col.chk_file __FILE__
  bp = col.autogen 'tok_main', /^tok_main$/, (ret)->
    ret.hash.tab_to_2space= false
    ret.hash.dedent_fix   = true
    ret.hash.remove_end_eol = true
    ret.hash.empty_fix    = true
    ret.compile_fn = ()->
      if !@hash._injected
        throw new Error "Can't compile tok_main. Must be injected"
      parser_list = []
      for child in @child_list
        child.compile()
        if child.parser_list
          parser_list.append child.parser_list
      
      for v,k in parser_list
        parser_list[k] = """
          tokenizer.parser_list.push(#{v})
          """
      
      pre_jl = []
      post_jl = []
      if ret.hash.tab_to_2space
        pre_jl.push """
          str = str.replace /\t/, '  '
          """
      if ret.hash.dedent_fix
        pre_jl.push '''
          str += "\n" # dedent fix
          '''
      if ret.hash.remove_end_eol
        post_jl.push """
          while res.length && res.last()[0].mx_hash.hash_key == 'eol'
            res.pop()
          """
      if ret.hash.empty_fix
        post_jl.push """
          if res.length == 0
            node = new Node
            node.mx_hash.hash_key = 'empty'
            res.push [node]
          """
      
      ret.hash.cont = """
        require 'fy'
        {Token_parser, Tokenizer, Node} = require 'gram2'
        module = @
        tokenizer = new Tokenizer
        #{join_list parser_list}
        
        
        @_tokenizer = tokenizer

        @_tokenize = (str, opt={})->
          #{join_list pre_jl, '  '}
          res = tokenizer.go str
          #{join_list post_jl, '  '}
          res

        @tokenize = (str, opt, on_end)->
          try
            res = module._tokenize str, opt
          catch e
            return on_end e
          on_end null, res
        """
      return
    ret
  
  bp = col.autogen 'tok_space_scope', /^tok_space_scope$/, (ret)->
    ret
  bp = col.autogen 'tok_id', /^tok_id$/, (ret)->
    ret.compile_fn = ()->
      ret.parser_list = [
        "new Token_parser 'identifier', /^[_\$a-z][_\$a-z0-9]*/i"
      ]
      return
    ret
  # TODO number family
  bp = col.autogen 'tok_int_family', /^tok_int_family$/, (ret)->
    ret.hash.sign = false
    ret.hash.dec = true
    ret.hash.oct_unsafe = true # 0777
    ret.hash.oct = true
    ret.hash.hex = true
    ret.hash.bin = true
    ret
  
  bp = col.autogen 'tok_float_family', /^tok_float_family$/, (ret)->
    ret.hash.sign = false
    ret.hash.miss_start_zero = false
    ret.hash.exp = true
    ret
  
  bp = col.autogen 'tok_at', /^tok_at$/, (ret)->
    ret
  
  bp = col.autogen 'tok_bin_op', /^tok_bin_op$/, (ret)->
    ret.hash.arith      = true # + - * / %
    ret.hash.arith_ext  = true # ** // %%
    ret.hash.shift      = true # << >> >>>
    ret.hash.logic      = true # && ||
    ret.hash.logic_ext  = true # ^^
    ret.hash.logic_text = true # and or xor
    ret.hash.bit        = true # & | ^
    ret.hash.cmp        = true # == != < <= > >=
    ret.hash.cmp_ext    = true # <>
    ret.hash.ranger     = true # .. ...
    ret.hash.access     = true # .
    ret.hash.static_access= true # ::
    ret.hash.assign_check = false # ?=
    # js/coffee wierd stuff
    ret.hash.instanceof = false
    ret.hash.in         = false
    ret.hash.of         = false
    ret.hash.is         = false
    ret.hash.isnt       = false
    
    # список операторов, которые если разрешены, то для них автоматически будет создана операция op=
    ret.hash.assign_list= "+ - * / % ** // %% << >> >>> && || ^^ and or xor & | ^".split /\s+/g
    ret.hash.ban_list   = [] # если надо убить какой-то отдельный оператор
    ret.hash.extra_list = [] # если надо добавить какой-то отдельный оператор
    
    ret.compile_fn = ()->
      op_list = []
      op_list.append "+ - * / %"      .split /\s+/g if ret.hash.arith
      op_list.append "** // %%"       .split /\s+/g if ret.hash.arith_ext
      op_list.append "<< >> >>>"      .split /\s+/g if ret.hash.shift
      op_list.append "&& ||"          .split /\s+/g if ret.hash.logic
      op_list.append "::"             .split /\s+/g if ret.hash.logic_ext
      op_list.append "and or xor"     .split /\s+/g if ret.hash.logic_text
      op_list.append "& | ^"          .split /\s+/g if ret.hash.bit
      op_list.append "== != < <= > >=".split /\s+/g if ret.hash.cmp
      op_list.append "<>"             .split /\s+/g if ret.hash.cmp_ext
      op_list.append ".. ..."         .split /\s+/g if ret.hash.ranger
      op_list.append "."              .split /\s+/g if ret.hash.access
      op_list.append "::"             .split /\s+/g if ret.hash.static_access
      for v in "instanceof in of is isnt".split /\s+/g
        op_list.push v if ret.hash[v]
      
      op_list.append ret.hash.extra_list
      for v in ret.hash.ban_list
        op_list.remove v
      
      for v in ret.hash.assign_list
        if op_list.has v
          op_list.push "#{v}="
      
      # extra ban after assign_list
      for v in ret.hash.ban_list
        op_list.remove v
      
      for v,k in op_list
        op_list[k] = RegExp.escape v
      
      body = op_list.join '|'
      ret.parser_list = [
        "new Token_parser 'bin_op', /^(#{body})/"
      ]
      return
    
    ret
  
  bp = col.autogen 'tok_un_op', /^tok_un_op$/, (ret)->
    ret.hash.arith  = true # - +
    ret.hash.inc    = true # ++ --
    ret.hash.logic  = true # !
    ret.hash.bit    = true # ~
    ret.hash.not    = true
    ret.hash.new    = true
    ret.hash.delete = true
    # js/coffee wierd stuff
    ret.hash.void   = false
    ret.hash.typeof = false
    
    ret.hash.ban_list   = [] # если надо убить какой-то отдельный оператор
    ret.hash.extra_list = [] # если надо добавить какой-то отдельный оператор
    
    ret.compile_fn = ()->
      op_list = []
      op_list.append "+ -"  .split /\s+/g if ret.hash.arith
      op_list.append "++ --".split /\s+/g if ret.hash.inc
      op_list.append "!"    .split /\s+/g if ret.hash.logic
      op_list.append "~"    .split /\s+/g if ret.hash.bit
      for v in "not new delete void typeof".split /\s+/g
        op_list.push v if ret.hash[v]
      
      op_list.append ret.hash.extra_list
      for v in ret.hash.ban_list
        op_list.remove v
      
      for v,k in op_list
        op_list[k] = RegExp.escape v
      
      body = op_list.join '|'
      ret.parser_list = [
        "new Token_parser 'un_op', /^(#{body})/"
      ]
      return
    
    ret
  
  bp = col.autogen 'tok_inline_comment', /^tok_inline_comment$/, (ret)->
    ret.hash.delimiter = "#"
    ret.compile_fn = ()->
      ret.parser_list = [
        "new Token_parser 'inline_comment', /^#{RegExp.escape ret.hash.delimiter}.*/"
      ]
      return
    ret
  
  bp = col.autogen 'tok_multiline_comment', /^tok_multiline_comment$/, (ret)->
    ret.hash.a = "###"
    ret.hash.b = "###"
    ret.hash.body = "[^#][^]*?"
    ret.compile_fn = ()->
      ret.parser_list = [
        "new Token_parser 'multiline_comment', /^#{RegExp.escape ret.hash.a}#{ret.hash.body}#{RegExp.escape ret.hash.b}/"
      ]
      return
    
    ret
  
  bp = col.autogen 'tok_fn', /^tok_fn$/, (ret)->
    ret.hash.arrow = true
    ret.hash.fat_arrow = true
    ret
  
  # дает {} : и string
  bp = col.autogen 'tok_hash', /^tok_hash$/, (ret)->
    ret.hash.key_int          = true
    ret.hash.key_float        = true
    ret.hash.key_string       = true
    ret.hash.key_bracket_expr = false
    ret.hash.skip_bracket     = false
    ret.hash.multiline        = true
    ret.hash.skip_comma_multiline = true
    ret.hash.trailing_comma   = true
    ret
  
  bp = col.autogen 'tok_array', /^tok_array$/, (ret)->
    ret.hash.key_int          = true
    ret.hash.multiline        = true
    ret.hash.skip_comma_multiline = true
    ret
  
  bp = col.autogen 'tok_class', /^tok_class$/, (ret)->
    ret
  
  # todo string (single/double)
  # todo string interpolate
  # todo multiline string+interpolate
  # todo regex
  # todo here regex +interpolate