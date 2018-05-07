require 'fy/codegen'
{
  gram_escape
} = require 'gram3'
# fallback debug
# gram_escape ?= (t)->
  # ret = JSON.stringify t
  # ret = ret.substr 1, ret.length-2
  # ret = ret.replace "'", "\\'"
  # "'#{ret}'"

module.exports = (col)->
  return if col.chk_file __FILE__
  bp = col.autogen 'gram_main', (ret)->
    ret.hash.expected_token = "stmt_plus"
    ret.hash.compiled_gram_path = "_compiled_gram.gen.coffee"
    ret.compile_fn = ()->
      if !@hash._injected
        throw new Error "Can't compile gram_main. Must be injected"
      
      gram_list = [
        # не определился куда...
        '''
        q("const", "#num_const")                          .mx("ult=deep ti=pass")
        q("const", "#str_const")                          .mx("ult=deep ti=pass")
        q("rvalue","#const")                              .mx("priority=#{base_priority} ult=deep  ti=pass")
        q("stmt",  "#rvalue")                             .mx("ult=deep ti=pass")
        q("rvalue", "#lvalue")                            .mx("priority=#{base_priority} tail_space=$1.tail_space ult=deep  ti=pass")
        
        '''
      ]
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
        
      for child in @child_list
        child.compile()
        if child.gram_list
          gram_list.append child.gram_list
      
      show_diff = '''
      show_diff = (a,b)->
        ### !pragma coverage-skip-block ###
        if a.rule != b.rule
          perr "RULE mismatch"
          perr "a="
          perr a.rule
          perr "b="
          perr b.rule
          return
        if a.value != b.value
          perr "a=#{a.value}"
          perr "b=#{b.value}"
          return
        if a.mx_hash.hash_key != b.mx_hash.hash_key
          perr "a=#{a.value}|||#{a.value_view}"
          perr "b=#{b.value}|||#{b.value_view}"
          perr "a.hash_key = #{a.mx_hash.hash_key}"
          perr "b.hash_key = #{b.mx_hash.hash_key}"
          return
        js_a = JSON.stringify a.mx_hash
        js_b = JSON.stringify b.mx_hash
        if js_a != js_b
          perr "a=#{a.value}|||#{a.value_view}"
          perr "b=#{b.value}|||#{b.value_view}"
          perr "a.mx_hash = #{js_a}"
          perr "b.mx_hash = #{js_b}"
          return
        if a.value_array.length != b.value_array.length
          perr "list length mismatch #{a.value_array.length} != #{b.value_array.length}"
          perr "a=#{a.value}|||#{a.value_view}"
          perr "b=#{b.value}|||#{b.value_view}"
          perr "a=#{a.value_array.map((t)->t.value).join ","}"
          perr "b=#{b.value_array.map((t)->t.value).join ","}"
          return
        for i in [0 ... a.value_array.length]
          show_diff a.value_array[i], b.value_array[i]
        return
      '''
      ret.hash.cont = """
        module = @
        mod = require #{JSON.stringify './'+ret.hash.compiled_gram_path.replace '.coffee', ''}
        @_parser = parser = new mod.Parser
        #{show_diff}
        @_parse = (tok_res, opt={})->
          gram_res = parser.go tok_res
          if gram_res.length == 0
            throw new Error \"Parsing error. No proper combination found\"
          if gram_res.length != 1
            [a,b] = gram_res
            show_diff a,b
            ### !pragma coverage-skip-block ###
            throw new Error \"Parsing error. More than one proper combination found \#{gram_res.length}\"
          gram_res
        
        @parse = (tok_res, opt, on_end)->
          try
            gram_res = module._parse tok_res, opt
          catch e
            return on_end e
          on_end null, gram_res
      """
      
      ret.hash.cont_gen = """
        #!/usr/bin/env iced
        ### !pragma coverage-skip-block ###
        require \"fy\"
        {Gram_scope} = require \"gram3\"
        fs = require 'fs'
        g = new Gram_scope
        g.expected_token = #{JSON.stringify ret.hash.expected_token}
        {_tokenizer} = require \"./tok.gen.coffee\"
        do ()->
          for v in _tokenizer.parser_list
            g.extra_hash_key_list.push v.name
          
        q = (a, b)->g.rule a,b
        base_priority = -9000
        #{join_list gram_list}
        
        fs.writeFileSync #{JSON.stringify ret.hash.compiled_gram_path}, g.compile()
        """#"
      return
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_space_scope', /^gram_space_scope$/, (ret)->
    ret.compile_fn = ()->
      ret.gram_list = [
        '''
        q('block', '#indent #stmt_plus #dedent')          .mx("priority=#{base_priority} ult=block ti=block")
        
        '''#'
      ]
    ret
  
    ret
  bp = col.autogen 'gram_id', /^gram_id$/, (ret)->
    ret.compile_fn = ()->
      ret.gram_list = [
        '''
        q("lvalue", "#tok_identifier")                    .mx("priority=#{base_priority} tail_space=$1.tail_space ult=id ti=id")
        
        '''
      ]
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_int_family', /^gram_int_family$/, (ret)->
    ret.hash.dec = true
    # ret.hash.oct_unsafe = true # 0777
    ret.hash.oct = true
    ret.hash.hex = true
    ret.hash.bin = true
    ret.compile_fn = ()->
      ret.gram_list =[]
      if ret.hash.dec
        ret.gram_list.push 'q("num_const", "#tok_decimal_literal")            .mx("ult=const ti=const type=int")'
      # if ret.hash.oct_unsafe
        # ret.gram_list.push 'q("num_const", "#tok_octal_literal")              .mx("ult=const ti=const type=int")'
      if ret.hash.oct
        ret.gram_list.push 'q("num_const", "#tok_octal_literal")              .mx("ult=const ti=const type=int")'
      if ret.hash.hex
        ret.gram_list.push 'q("num_const", "#tok_hexadecimal_literal")        .mx("ult=const ti=const type=int")'
      if ret.hash.bin
        ret.gram_list.push 'q("num_const", "#tok_binary_literal")             .mx("ult=const ti=const type=int")'
      ret.gram_list.push ''
      return
    ret
  
  bp = col.autogen 'gram_float_family', /^gram_float_family$/, (ret)->
    ret.compile_fn = ()->
      ret.gram_list = [
        'q("num_const", "#tok_float_literal")              .mx("ult=const ti=const type=float")'
        ''
      ]
      return
    ret
  
  bp = col.autogen 'gram_str_family', /^gram_str_family$/, (ret)->
    ret.hash.sq = true
    ret.hash.dq = true
    ret.hash.sq_heredoc = true
    ret.hash.dq_heredoc = true
    ret.compile_fn = ()->
      ret.gram_list =[]
      
      if ret.hash.sq
        ret.gram_list.push 'q("str_const", "#tok_string_sq")                      .mx("ult=const ti=const type=string")'
      if ret.hash.dq
        ret.gram_list.push 'q("str_const", "#tok_string_dq")                      .mx("ult=const ti=const type=string")'
      
      ret.gram_list.push ''
      return
    ret
  
  bp = col.autogen 'gram_at', /^gram_at$/, (ret)->
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_bin_op', /^gram_bin_op$/, (ret)->
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
    ret.hash.assign       = true
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
    ret.hash.space_fix  = false

    ret.hash.priority_hash =
      '//' : 4
      '%%' : 4
      '**' : 4
      
      '*'  : 5
      '/'  : 5
      '%'  : 5
      
      '+'  : 6
      '-'  : 6
      
      '<<' : 7
      '>>' : 7
      '>>>': 7
      
      'instanceof': 8
      
      '<'  : 9
      '>'  : 9
      '<=' : 9
      '>=' : 9
      '!=' : 9
      '==' : 9
      '<>' : 9
      
      '&'  : 10
      '|'  : 10
      '^'  : 10
      
      '&&' : 11
      '||' : 11
      '^^' : 11
      'and': 11
      'or' : 11
      'xor': 11
      
      '='  : 12
    
    ret.hash.l_assoc_hash =
      '**' : true
    
    ret.hash.r_assoc_hash = {}
    for v in "// %% * / % + - << >> >>> instanceof != == && || ^^ and or xor".split /\s+/g
      ret.hash.r_assoc_hash[v] = true
    
    
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
      # no priority
      # op_list.append ".. ..."         .split /\s+/g if ret.hash.ranger
      # op_list.append "."              .split /\s+/g if ret.hash.access
      # op_list.append "::"             .split /\s+/g if ret.hash.static_access
      op_list.append "="              .split /\s+/g if ret.hash.assign
      for v in "instanceof in of is isnt".split /\s+/g
        op_list.push v if ret.hash[v]
      
      op_list.append ret.hash.extra_list
      for v in ret.hash.ban_list
        op_list.remove v
      
      if ret.hash.assign
        for v in ret.hash.assign_list
          if op_list.has v
            op_list.push "#{v}="
            ret.hash.priority_hash["#{v}="] = ret.hash.priority_hash["="]
        
        # extra ban after assign_list
        for v in ret.hash.ban_list
          op_list.remove v
      
      ret.gram_list = []
      for op in op_list
        str_op = JSON.stringify(gram_escape op)
        priority = ret.hash.priority_hash[op] or ret.hash.default_priority
        
        assoc_aux = ""
        if ret.hash.r_assoc_hash[op]
          assoc_aux = " right_assoc=1"
        if ret.hash.l_assoc_hash[op]
          assoc_aux = " left_assoc=1"
        
        q  = """q("bin_op", #{str_op})"""#"
        mx = """.mx("priority=#{priority} tail_space=$1.tail_space #{assoc_aux}")"""#"
        ret.gram_list.push "#{q.ljust 50}#{mx.ljust 50}#"
      
      if !ret.hash.space_fix
        ret.gram_list.push """
          q("rvalue",  "#rvalue #bin_op #rvalue")           .mx("priority=#bin_op.priority ult=bin_op ti=bin_op")   .strict("$1.priority<#bin_op.priority  $3.priority<#bin_op.priority")
          q("rvalue",  "#rvalue #bin_op #rvalue")           .mx("priority=#bin_op.priority ult=bin_op ti=bin_op")   .strict("$1.priority<#bin_op.priority  $3.priority==#bin_op.priority #bin_op.left_assoc")
          q("rvalue",  "#rvalue #bin_op #rvalue")           .mx("priority=#bin_op.priority ult=bin_op ti=bin_op")   .strict("$1.priority==#bin_op.priority $3.priority<#bin_op.priority  #bin_op.right_assoc")
          
        """#"
      else
        # варианты
        # a+b
        # a + b
        # a+ b
        ret.gram_list.push """
          q("rvalue",  "#rvalue #bin_op #rvalue")           .mx("priority=#bin_op.priority ult=bin_op ti=bin_op")   .strict("$1.priority<#bin_op.priority  $3.priority<#bin_op.priority  !!$1.tail_space<=!!$2.tail_space")
          q("rvalue",  "#rvalue #bin_op #rvalue")           .mx("priority=#bin_op.priority ult=bin_op ti=bin_op")   .strict("$1.priority<#bin_op.priority  $3.priority==#bin_op.priority !!$1.tail_space<=!!$2.tail_space #bin_op.left_assoc")
          q("rvalue",  "#rvalue #bin_op #rvalue")           .mx("priority=#bin_op.priority ult=bin_op ti=bin_op")   .strict("$1.priority==#bin_op.priority $3.priority<#bin_op.priority  !!$1.tail_space<=!!$2.tail_space #bin_op.right_assoc")
          
        """#"
      return
    
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_pre_op', (ret)->
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
    ret.hash.default_priority = 1
    ret.hash.priority_hash =
      "void"  : 15
      "new"   : 15
      "delete": 15
    
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
      
      ret.gram_list = []
      for op in op_list
        aux_tail = ""
        if op in ["+", "-"]
          aux_tail = " !$1.tail_space"
        str_op = JSON.stringify(gram_escape op)
        priority = ret.hash.priority_hash[op] or ret.hash.default_priority
        
        q  = """q("pre_op", #{str_op})"""#"
        mx = """.mx("priority=#{priority}")"""#"
        strict = ""
        if aux_tail
          strict = """.strict("#{aux_tail}")"""
        ret.gram_list.push "#{q.ljust 50}#{mx.ljust 50}#{strict.ljust 50}"
      
      ret.gram_list.push """
        q("rvalue",  "#pre_op #rvalue")                   .mx("priority=#pre_op.priority ult=pre_op ti=pre_op")   .strict("#rvalue[1].priority<=#pre_op.priority")
        
      """#"
      
      return
    
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_post_op', (ret)->
    ret.hash.inc    = true # ++ --
    ret.hash.is_not_null = true # ?
    
    ret.hash.ban_list   = [] # если надо убить какой-то отдельный оператор
    ret.hash.extra_list = [] # если надо добавить какой-то отдельный оператор
    ret.hash.default_priority = 1
    ret.hash.priority_hash = {}
    
    ret.compile_fn = ()->
      op_list = []
      op_list.append "++ --".split /\s+/g if ret.hash.inc
      op_list.push "[QUESTION]" if ret.hash.is_not_null
      
      op_list.append ret.hash.extra_list
      for v in ret.hash.ban_list
        op_list.remove v
      
      ret.gram_list = []
      for op in op_list
        str_op = JSON.stringify(gram_escape op)
        priority = ret.hash.priority_hash[op] or ret.hash.default_priority
        
        q  = """q("post_op", #{str_op})"""#"
        mx = """.mx("priority=#{priority}")"""#"
        ret.gram_list.push "#{q.ljust 50}#{mx.ljust 50}"
      
      ret.gram_list.push """
        q("rvalue",  "#rvalue #post_op")                  .mx("priority=#post_op.priority ult=post_op ti=post_op").strict("#rvalue[1].priority<#post_op.priority !#rvalue.tail_space")
        
      """#"
      
      return
    
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_index_access', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      # NOTE мы можем так сделать поскольку у нас не выделена операция assign, и она с rvalue
      # q("lvalue",  "#lvalue [ #rvalue ]")               .mx("priority=#{base_priority} ult=index_access ti=index_access").strict("$1.priority==#{base_priority}")
      ret.gram_list.push '''
        q("rvalue",  "#rvalue '[' #rvalue ']'")               .mx("priority=#{base_priority} ult=index_access ti=index_access").strict("$1.priority==#{base_priority}")
        
      '''
      
    ret
  bp = col.autogen 'gram_bracket', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q("rvalue",  "'(' #rvalue ')'")                       .mx("priority=#{base_priority} ult=bracket ti=pass")
        
      '''
      
    ret
  
  bp = col.autogen 'gram_inline_comment', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = [
        '''
        q('stmt', '#tok_inline_comment')                  .mx("ult=comment ti=pass")
        
        '''#'
      ]
    ret
  
  bp = col.autogen 'gram_multiline_comment', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = [
        '''
        q('stmt', '#tok_multiline_comment')               .mx("ult=comment ti=pass")
        
        '''#'
      ]
    ret
  
  bp = col.autogen 'gram_stmt', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = [
        '''
        q('stmt_plus', '#stmt')                           .mx("ult=deep_scope ti=pass")
        q('stmt_plus', '#stmt #stmt_plus')                .mx("ult=deep_scope").strict("$1.eol")
        q('stmt_plus', '#stmt #eol #stmt_plus')           .mx("ult=deep_scope ti=stmt_plus_last eol_pass=1")
        
        '''#'
      ]
      return
    ret
  
  # дает {} : и string
  bp = col.autogen 'gram_hash', (ret)->
    ret.hash.key_int          = true
    ret.hash.key_float        = true
    ret.hash.key_string       = true
    ret.hash.key_bracket_expr = false
    ret.hash.skip_bracket     = false
    ret.hash.multiline        = true
    ret.hash.skip_comma_multiline = true
    ret.hash.trailing_comma   = true
    ret
  
  bp = col.autogen 'gram_array', (ret)->
    ret.hash.key_int          = true
    ret.hash.multiline        = true
    ret.hash.skip_comma_multiline = true
    ret
  
  bp = col.autogen 'gram_comment', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = [
        '''
        q('stmt', '#tok_inline_comment')                  .mx("ult=comment ti=pass")
        q('stmt', '#tok_multiline_comment')               .mx("ult=comment ti=pass")
        
        '''#'
      ]
      return
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_type', (ret)->
    ret.hash.nest = true
    ret.hash.field = true
    ret.compile_fn = ()->
      ret.gram_list = []
      
      aux_nest = ""
      if ret.hash.nest
        aux_nest = " #type_nest?"
        ret.gram_list.push '''
          q('type_list', '#type')
          q('type_list', '#type "," #type_list')
          q('type_nest', '"<" #type_list ">"')
        '''#'
        
      aux_field = ""
      if ret.hash.field
        aux_field = " #type_field?"
        ret.gram_list.push '''
          q('type_field_kv', '#tok_identifier ":" #type')
          q('type_field_kv_list', '#type_field_kv')
          q('type_field_kv_list', '#type_field_kv "," #type_field_kv_list')
          q('type_field', '"{" #type_field_kv_list "}"')
        '''#'
      str = "q('type', '#tok_identifier#{aux_nest}#{aux_field}')"
      ret.gram_list.push """
        #{str.ljust 50}.mx("ult=type_name ti=pass")
        
        """#"
      
      return
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_var_decl', (ret)->
    ret.hash.require_list = ['gram_type']
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('stmt', 'var #tok_identifier ":" #type')          .mx("ult=var_decl ti=var_decl")
        
      '''#'
      return
    ret
  
  bp = col.autogen 'gram_macro', (ret)->
    ret.hash.token = 'stmt'
    ret.hash.aux_mx = ''
    ret.compile_fn = ()->
      ret.gram_list = []
      token = JSON.stringify ret.hash.token
      aux_mx = ret.hash.aux_mx
      if aux_mx
        aux_mx += " "
      ret.gram_list.push """
        q(#{token}, '#tok_identifier #block')               .mx("#{aux_mx}ult=macro ti=macro eol=1")
        q(#{token}, '#tok_identifier #rvalue #block')       .mx("#{aux_mx}ult=macro ti=macro eol=1")
        
      """#"
      return
  
  bp = col.autogen 'gram_if', (ret)->
    ret.hash.postfix = false
    ret.hash.unless  = false
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push """
        q('stmt', 'if #rvalue #block #if_tail_stmt?')                       .mx("ult=if ti=if eol=1")
        q('if_tail_stmt', 'else if #rvalue #block #if_tail_stmt?')          .mx("ult=else_if ti=else_if eol=1")
        q('if_tail_stmt', 'elseif|elsif|elif #rvalue #block #if_tail_stmt?').mx("ult=else_if ti=else_if eol=1")
        q('if_tail_stmt', 'else #block')                                    .mx("ult=else ti=else eol=1")
      """
      if ret.hash.postfix
        ret.gram_list.push """
          q('stmt', '#stmt if #rvalue')       .mx("ult=if_postfix ti=if_postfix eol=1")
        """
      
      ret.gram_list.push ""
      return
  
  bp = col.autogen 'gram_switch', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push """
        q('stmt', 'switch #rvalue #indent #switch_tail_stmt #dedent')   .mx("ult=switch ti=switch eol=1")
        q('switch_tail_stmt', 'when #rvalue #block #switch_tail_stmt?') .mx("ult=switch_when ti=switch_when eol=1")
        q('switch_tail_stmt', 'else #block')                            .mx("ult=switch_else ti=switch_else eol=1")
      """
      ret.gram_list.push ""
      return
  
  bp = col.autogen 'gram_for_range', (ret)->
    ret.hash.allow_step = true
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('ranger', "'..'")                                 .mx("ult=macro ti=macro eol=1")
        q('ranger', "'...'")                                .mx("ult=macro ti=macro eol=1")
        q('stmt', 'for #tok_identifier in "[" #rvalue #ranger #rvalue "]" #block').mx("ult=for_range ti=macro eol=1")
      '''#'
      if ret.hash.allow_step
        ret.gram_list.push '''
          q('stmt', 'for #tok_identifier in "[" #rvalue #ranger #rvalue "]" by #rvalue #block').mx("ult=for_range ti=macro eol=1")
        '''#'
      ret.gram_list.push ""
      return
  
  bp = col.autogen 'gram_for_col', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('stmt', 'for #tok_identifier                   in #rvalue #block').mx("ult=for_col ti=macro eol=1")
        q('stmt', 'for #tok_identifier "," #tok_identifier in #rvalue #block').mx("ult=for_col ti=macro eol=1")
        
      '''#'
      return
  
  bp = col.autogen 'gram_field_access', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('lvalue', '#rvalue "." #tok_identifier')          .mx("priority=#{base_priority} ult=field_access ti=macro tail_space=#tok_identifier.tail_space").strict("$1.priority==#{base_priority}")
        
      '''#'
      return
    
  
  bp = col.autogen 'gram_fn_call', (ret)->
    ret.hash.allow_bracketless = false
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('fn_call_arg_list', '#rvalue')
        q('fn_call_arg_list', '#rvalue "," #fn_call_arg_list')
        q('rvalue', '#rvalue "(" #fn_call_arg_list? ")"')     .mx("priority=#{base_priority} ult=fn_call").strict("$1.priority==#{base_priority}")
      '''#'
      if ret.hash.allow_bracketless
        ret.gram_list.push '''
          q('rvalue', '#rvalue #fn_call_arg_list')        .mx("priority=#{base_priority} ult=fn_call").strict("$1.priority==#{base_priority} $1.tail_space")
        '''#'
      ret.gram_list.push ""
      return
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_fn_decl', (ret)->
    # ret.hash.arrow = true
    ret.hash.fat_arrow = true # LATER
    ret.hash.closure = false
    ret.hash.require_list = ['gram_type', 'gram_fn_call']
    
    ret.compile_fn = ()->
      ret.gram_list = []
      # TODO default value
      # q('rvalue', '( #fn_decl_arg_list? ) ":" #type ->').mx("ult=closure")
      ret.gram_list.push '''
        q('fn_decl_arg', '#tok_identifier ":" #type')
        q('fn_decl_arg_list', '#fn_decl_arg')
        q('fn_decl_arg_list', '#fn_decl_arg "," #fn_decl_arg_list')
        q('stmt', '#tok_identifier "(" #fn_decl_arg_list? ")" ":" #type "->"').mx('ult=fn_decl')
        q('stmt', '#tok_identifier "(" #fn_decl_arg_list? ")" ":" #type "->" #block').mx('ult=fn_decl eol=1')
        q('stmt', '#tok_identifier "(" #fn_decl_arg_list? ")" ":" #type "->" #rvalue').mx('ult=fn_decl')
        
        q('stmt', '#return #rvalue?')                     .mx('ult=return ti=return')
        
      '''#'
      if ret.hash.closure
        ret.gram_list.push '''
        q('rvalue', '"(" #fn_decl_arg_list? ")" ":" #type "=>"').mx("priority=#{base_priority} ult=cl_decl")
        q('rvalue', '"(" #fn_decl_arg_list? ")" ":" #type "=>" #block').mx("priority=#{base_priority} ult=cl_decl eol=1")
        q('rvalue', '"(" #fn_decl_arg_list? ")" ":" #type "=>" #rvalue').mx("priority=#{base_priority} ult=cl_decl")
        
      '''#'
      
      return
    ret
  # ###################################################################################################
  
  bp = col.autogen 'gram_class_decl', /^gram_class_decl$/, (ret)->
    ret.hash.require_list = ['gram_fn_decl', 'gram_var_decl']
    
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('stmt', 'class #tok_identifier')                .mx('ult=class_decl')
        q('stmt', 'class #tok_identifier #block')         .mx('ult=class_decl eol=1')
        
      '''#'
      
      return
    ret
  
  bp = col.autogen 'gram_require', (ret)->
    # ret.hash.require_list = ['gram_const_string']
    ret.hash.single_quote = true
    ret.hash.double_quote = true
    ret.hash.single_heredoc = false
    ret.hash.double_heredoc = false
    ret.hash.backtick_quote = false
    ret.hash.coffee_interpolation = false
    
    ret.compile_fn = ()->
      ret.gram_list = []
      if ret.hash.single_quote
        ret.gram_list.push '''
          q('stmt', 'require #tok_string_sq')                .mx('ult=require')
          
        '''#'
      if ret.hash.double_quote
        ret.gram_list.push '''
          q('stmt', 'require #tok_string_dq')                .mx('ult=require')
          
        '''#'
      
      return
    ret
  
  # todo string (single/double)
  # todo string interpolate
  # todo multiline string+interpolate
  # todo regex
  # todo here regex +interpolate