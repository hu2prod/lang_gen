require 'fy/codegen'

module.exports = (col)->
  return if col.chk_file __FILE__
  bp = col.autogen 'tok_main', /^tok_main$/, (ret)->
    ret.hash.tab_to_2space= false
    ret.hash.dedent_fix   = true
    ret.hash.remove_start_eol = true
    ret.hash.remove_end_eol = true
    ret.hash.empty_fix    = true
    ret.compile_fn = ()->
      if !@hash._injected
        throw new Error "Can't compile tok_main. Must be injected"
      # require
      present_module_list = []
      for child in @child_list
        present_module_list.upush child.name
      require_module_list = []
      for child in @child_list
        continue if !child.hash.require_list
        for v in child.hash.require_list
          require_module_list.upush v if !present_module_list.has v
      
      for v in require_module_list
        @inject ()->
          col.gen v
      
      spec_list = []
      parser_list = []
      for child in @child_list
        child.compile()
        if child.parser_list
          parser_list.append child.parser_list
        if child.spec_list
          spec_list.append child.spec_list
      
      for v,k in parser_list
        parser_list[k] = """
          tokenizer.parser_list.push(#{v})
          """
      
      pre_jl = []
      post_jl = []
      if ret.hash.tab_to_2space
        pre_jl.push """
          str = str.replace /\\t/, '  '
          """
      if ret.hash.dedent_fix
        pre_jl.push '''
          str += "\\n" # dedent fix
          '''
      if ret.hash.remove_start_eol
        pre_jl.push '''
          str = str.replace(/^\\s+/, '')
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
        {Token_parser, Tokenizer, Node} = require 'gram3'
        module = @
        tokenizer = new Tokenizer
        #{join_list spec_list}
        #{join_list parser_list}
        
        
        @_tokenizer = tokenizer

        @_tokenize = (str, opt={})->
          last_space = 0 # HARDCODE
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
    ret.spec_list = [
      '''
      last_space = 0
      tokenizer = new Tokenizer
      tokenizer.parser_list.push (new Token_parser 'Xdent', /^\\n/, (_this, ret_value, q)->
        _this.text = _this.text.substr 1 # \\n
        _this.line++
        _this.pos = 0
        
        reg_ret = /^([ \\t]*\\n)*/.exec(_this.text)
        _this.text = _this.text.substr reg_ret[0].length
        _this.line += reg_ret[0].split('\\n').length - 1
        
        tail_space_len = /^[ \\t]*/.exec(_this.text)[0].length
        _this.text = _this.text.substr tail_space_len
        _this.pos += tail_space_len
        
        if tail_space_len != last_space
          while last_space < tail_space_len
            node = new Node
            node.mx_hash.hash_key = 'indent'
            ret_value.push [node]
            last_space += 2
          
          while last_space > tail_space_len
            indent_change_present = true
            node = new Node
            node.mx_hash.hash_key = 'dedent'
            ret_value.push [node]
            last_space -= 2
        else
          # return if _this.ret_access.last()?[0].mx_hash.hash_key == 'eol' # do not duplicate
          node = new Node
          node.mx_hash.hash_key = 'eol'
          ret_value.push [node]
          
        last_space = tail_space_len
      )
      '''#'
    ]
    ret
  bp = col.autogen 'tok_id', /^tok_id$/, (ret)->
    ret.hash.fix_return = true
    ret.compile_fn = ()->
      if ret.hash.fix_return
        ret.parser_list = [
          """
          new Token_parser 'tok_identifier', /^[_\$a-z][_\$a-z0-9]*/i, (_this, ret_proxy, v)->
            if v.value == 'return'
              v.mx_hash.hash_key = 'return'
            ret_proxy.push [v]
            return
          
          """
        ]
      else
        ret.parser_list = [
          "new Token_parser 'tok_identifier', /^[_\$a-z][_\$a-z0-9]*/i"
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
    
    ret.compile_fn = ()->
      aux_sign = ""
      if ret.hash.sign
        aux_sign = "[-+]?"
      ret.parser_list = []
      if ret.hash.dec
        if ret.hash.oct_unsafe
          ret.parser_list.push "new Token_parser 'tok_decimal_literal', /^#{aux_sign}(0|[1-9][0-9]*)/"
        else
          ret.parser_list.push "new Token_parser 'tok_decimal_literal', /^#{aux_sign}[0-9]+/"
      if ret.hash.oct
        ret.parser_list.push "new Token_parser 'tok_octal_literal', /^0o[0-7]+/i"
      if ret.hash.oct_unsafe
        ret.parser_list.push "new Token_parser 'tok_octal_literal', /^0[0-7]+/"
      if ret.hash.hex
        ret.parser_list.push "new Token_parser 'tok_hexadecimal_literal', /^0x[0-9a-f]+/i"
      if ret.hash.bin
        ret.parser_list.push "new Token_parser 'tok_binary_literal', /^0b[01]+/i"
      return
    ret
  
  bp = col.autogen 'tok_float_family', /^tok_float_family$/, (ret)->
    ret.hash.sign = false
    ret.hash.miss_start_zero = false
    ret.hash.miss_last_zero  = true
    ret.hash.exp = true
    
    ret.compile_fn = ()->
      aux_sign = ""
      if ret.hash.sign
        aux_sign = "[-+]?"
      ret.parser_list = []
      
      start = "\\d+"
      start = "\\d*" if ret.hash.miss_start_zero
      end   = "\\d+"
      end   = "(?!\\.)\\d*" if ret.hash.miss_last_zero
      main  = "#{start}\\.#{end}"
      exp_payload = "(?:e[+-]?\\d+)"
      main += "#{exp_payload}?" if ret.hash.exp
      
      ret.parser_list.push "new Token_parser 'tok_float_literal', /^#{aux_sign}#{main}/i"
      if ret.hash.exp
        ret.parser_list.push "new Token_parser 'tok_float_literal', /^#{aux_sign}\\d+#{exp_payload}/i"
      return
    
    ret
  
  bp = col.autogen 'tok_at', /^tok_at$/, (ret)->
    ret.compile_fn = ()->
      ret.parser_list = []
      ret.parser_list.push "new Token_parser 'tok_at', /^@/"
      return
    ret
  
  bp = col.autogen 'tok_comma', /^tok_comma$/, (ret)->
    ret.compile_fn = ()->
      ret.parser_list = []
      ret.parser_list.push "new Token_parser 'tok_comma', /^,/"
      return
    ret
  
  bp = col.autogen 'tok_bracket_round', /^tok_bracket_round$/, (ret)->
    ret.compile_fn = ()->
      ret.parser_list = []
      ret.parser_list.push "new Token_parser 'tok_bracket_round', /^[()]/"
      return
    ret
  
  bp = col.autogen 'tok_bracket_curve', /^tok_bracket_curve$/, (ret)->
    ret.compile_fn = ()->
      ret.parser_list = []
      ret.parser_list.push "new Token_parser 'tok_bracket_curve', /^[{}]/"
      return
    ret
  
  bp = col.autogen 'tok_bracket_square', /^tok_bracket_square$/, (ret)->
    ret.compile_fn = ()->
      ret.parser_list = []
      ret.parser_list.push "new Token_parser 'tok_bracket_square', /^[\\[\\]]/"
      return
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
    ret.hash.assign     = true # =
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
      op_list.append "^^"             .split /\s+/g if ret.hash.logic_ext
      op_list.append "and or xor"     .split /\s+/g if ret.hash.logic_text
      op_list.append "& | ^"          .split /\s+/g if ret.hash.bit
      op_list.append "== != < <= > >=".split /\s+/g if ret.hash.cmp
      op_list.append "<>"             .split /\s+/g if ret.hash.cmp_ext
      op_list.append ".. ..."         .split /\s+/g if ret.hash.ranger
      op_list.append "."              .split /\s+/g if ret.hash.access
      op_list.append "::"             .split /\s+/g if ret.hash.static_access
      op_list.append "="              .split /\s+/g if ret.hash.assign
      op_list.append "?="             .split /\s+/g if ret.hash.assign_check
      for v in "instanceof in of is isnt".split /\s+/g
        op_list.push v if ret.hash[v]
      
      op_list.append ret.hash.extra_list
      for v in ret.hash.ban_list
        op_list.remove v
      
      if ret.hash.assign
        for v in ret.hash.assign_list
          if op_list.has v
            op_list.push "#{v}="
      
      # extra ban after assign_list
      for v in ret.hash.ban_list
        op_list.remove v
      
      op_list.sort (a,b)->-(a.length-b.length)
      
      for v,k in op_list
        op_list[k] = RegExp.escape v
      
      body = op_list.join '|'
      ret.parser_list = [
        "new Token_parser 'tok_bin_op', /^(#{body})/"
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
    ret.hash.is_not_null = false
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
      op_list.append "?"    .split /\s+/g if ret.hash.is_not_null
      for v in "not new delete void typeof".split /\s+/g
        op_list.push v if ret.hash[v]
      
      op_list.append ret.hash.extra_list
      for v in ret.hash.ban_list
        op_list.remove v
      
      op_list.sort (a,b)->-(a.length-b.length)
      
      for v,k in op_list
        op_list[k] = RegExp.escape v
      
      body = op_list.join '|'
      ret.parser_list = [
        "new Token_parser 'tok_un_op', /^(#{body})/"
      ]
      return
    
    ret
  
  bp = col.autogen 'tok_index_access', /^tok_index_access$/, (ret)->
    ret.hash.require_list = ['tok_bracket_square']
    ret.compile_fn = ()->
      return
    ret
  
  bp = col.autogen 'tok_inline_comment', /^tok_inline_comment$/, (ret)->
    ret.hash.delimiter = "#"
    ret.compile_fn = ()->
      ret.parser_list = [
        "new Token_parser 'tok_inline_comment', /^#{RegExp.escape ret.hash.delimiter}.*/"
      ]
      return
    ret
  
  bp = col.autogen 'tok_multiline_comment', /^tok_multiline_comment$/, (ret)->
    ret.hash.a = "###"
    ret.hash.b = "###"
    ret.hash.body = "[^#][^]*?"
    ret.compile_fn = ()->
      ret.parser_list = [
        "new Token_parser 'tok_multiline_comment', /^#{RegExp.escape ret.hash.a}#{ret.hash.body}#{RegExp.escape ret.hash.b}/"
      ]
      return
    
    ret
  
  # дает {} : и string
  bp = col.autogen 'tok_hash', /^tok_hash$/, (ret)->
    ret.hash.require_list = ['tok_pair_delimiter']
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
  
  bp = col.autogen 'tok_var_decl', /^tok_var_decl$/, (ret)->
    ret.hash.require_list = ['tok_pair_delimiter', 'tok_bracket_curve']
    ret
  
  bp = col.autogen 'tok_fn_decl', /^tok_fn_decl$/, (ret)->
    ret.hash.require_list = ['tok_pair_delimiter', 'tok_bracket_round', 'tok_comma']
    ret.compile_fn = ()->
      ret.parser_list = []
      ret.parser_list.push "new Token_parser 'tok_fn_arrow', /^(->|=>)/"
      return
    ret
  
  bp = col.autogen 'tok_pair_delimiter', /^tok_pair_delimiter$/, (ret)->
    ret.compile_fn = ()->
      ret.parser_list = [
        "new Token_parser 'tok_pair_delimiter', /^:/"
      ]
      return
    ret
  
  bp = col.autogen 'tok_string', /^tok_string$/, (ret)->
    ret.hash.single_quote = true
    ret.hash.double_quote = true
    ret.hash.single_heredoc = false
    ret.hash.double_heredoc = false
    ret.hash.backtick_quote = false
    ret.hash.coffee_interpolation = false
    ret.compile_fn = ()->
      ret.parser_list = []
      string_regex_craft = ///
          \\[^xu] |               # x and u are case sensitive while hex letters are not
          \\x[0-9a-fA-F]{2} |     # Hexadecimal escape sequence
          \\u(?:
            [0-9a-fA-F]{4} |      # Unicode escape sequence
            \{(?:
              [0-9a-fA-F]{1,5} |  # Unicode code point escapes from 0 to FFFFF
              10[0-9a-fA-F]{4}    # Unicode code point escapes from 100000 to 10FFFF
            )\}
          )
      ///.toString().replace(/\//g,'')
      single_quoted_regex_craft = ///
        (?:
          [^\\] |
          #{string_regex_craft}
        )*?
      ///.toString().replace(/\//g,'')
      double_quoted_regexp_craft = ///
        (?:
          [^\\#] |
          \#(?!\{) |
          #{string_regex_craft}
        )*?
      ///.toString().replace(/\//g,'')
      if ret.hash.single_quote
        ret.parser_list.push "new Token_parser 'tok_string_sq', /^'#{single_quoted_regex_craft}'/"
      if ret.hash.double_quote
        ret.parser_list.push "new Token_parser 'tok_string_dq', /^:\"#{double_quoted_regexp_craft}\"/"
      return
    ret
  
  # todo string (single/double)
  # todo string interpolate
  # todo multiline string+interpolate
  # todo regex
  # todo here regex +interpolate