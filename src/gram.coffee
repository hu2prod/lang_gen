require 'fy/codegen'
{
  gram_escape
} = require 'gram2'

module.exports = (col)->
  return if col.chk_file __FILE__
  bp = col.autogen 'gram_main', /^gram_main$/, (ret)->
    ret.hash.expected_token = "stmt_plus"
    ret.compile_fn = ()->
      if !@hash._injected
        throw new Error "Can't compile gram_main. Must be injected"
      
      gram_list = [
        # не определился куда...
        '''
        q("const", "#num_const")                          .mx("ult=deep ti=pass")
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
      
      gram_list.push """
        @_parse = (tok_res, opt={})->
          gram_res = g.go tok_res,
            expected_token : #{JSON.stringify ret.hash.expected_token}
            mode_full      : opt.mode_full or false
          if gram_res.length == 0
            throw new Error "Parsing error. No proper combination found"
          if gram_res.length != 1
            [a,b] = gram_res
            show_diff a,b
            ### !pragma coverage-skip-block ###
            throw new Error "Parsing error. More than one proper combination found \#{gram_res.length}"
          gram_res

        @parse = (tok_res, opt, on_end)->
          try
            gram_res = module._parse tok_res, opt
          catch e
            return on_end e
          on_end null, gram_res
        """#"
      
      ret.hash.cont = """
        require "fy"
        {Gram, show_diff} = require "gram2"
        module = @
        g = new Gram
        {_tokenizer} = require "./tok.gen.coffee"
        do ()->
          for v in _tokenizer.parser_list
            g.extra_hash_key_list.push v.name
          
        q = (a, b)->g.rule a,b
        base_priority = -9000
        #{join_list gram_list}
        """#"
      return
    ret
  
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
  
  bp = col.autogen 'gram_int_family', /^gram_int_family$/, (ret)->
    ret.hash.dec = true
    # ret.hash.oct_unsafe = true # 0777
    ret.hash.oct = true
    ret.hash.hex = true
    ret.hash.bin = true
    ret.compile_fn = ()->
      ret.gram_list =[]
      if ret.hash.dec
        ret.gram_list.push 'q("num_const", "#decimal_literal")                .mx("ult=const ti=const type=int")'
      # if ret.hash.oct_unsafe
        # ret.gram_list.push 'q("num_const", "#octal_literal")                  .mx("ult=const ti=const type=int")'
      if ret.hash.oct
        ret.gram_list.push 'q("num_const", "#octal_literal")                  .mx("ult=const ti=const type=int")'
      if ret.hash.hex
        ret.gram_list.push 'q("num_const", "#hexadecimal_literal")            .mx("ult=const ti=const type=int")'
      if ret.hash.bin
        ret.gram_list.push 'q("num_const", "#binary_literal")                 .mx("ult=const ti=const type=int")'
      ret.gram_list.push ''
      return
    ret
  
  bp = col.autogen 'gram_float_family', /^gram_float_family$/, (ret)->
    ret.compile_fn = ()->
      ret.gram_list = [
        'q("num_const", "#float_literal")                        .mx("ult=const ti=const type=float")'
        ''
      ]
      return
    ret
  
  bp = col.autogen 'gram_at', /^gram_at$/, (ret)->
    ret
  
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

    ret.hash.priority_hash =
      '='  : 3
      
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
        mx = """.mx("priority=#{priority}#{assoc_aux}")"""#"
        s  = """.strict("$1.hash_key==tok_bin_op")"""#"
        ret.gram_list.push "#{q.ljust 50}#{mx.ljust 50}#{s}"
      
      ret.gram_list.push """
        q("rvalue",  "#rvalue #bin_op #rvalue")           .mx("priority=#bin_op.priority ult=bin_op ti=bin_op func_decl=#rvalue[1].func_decl")   .strict("#rvalue[1].priority<#bin_op.priority #rvalue[2].priority<#bin_op.priority !#rvalue[1].func_decl")
        q("rvalue",  "#rvalue #bin_op #rvalue")           .mx("priority=#bin_op.priority ult=bin_op ti=bin_op func_decl=#rvalue[1].func_decl")   .strict("#rvalue[1].priority<#bin_op.priority #rvalue[2].priority==#bin_op.priority !#rvalue[1].func_decl #bin_op.left_assoc")
        q("rvalue",  "#rvalue #bin_op #rvalue")           .mx("priority=#bin_op.priority ult=bin_op ti=bin_op func_decl=#rvalue[1].func_decl")   .strict("#rvalue[1].priority==#bin_op.priority #rvalue[2].priority<#bin_op.priority !#rvalue[1].func_decl #bin_op.right_assoc")
        
      """#"
      # TODO
      return
    
    ret
  
  bp = col.autogen 'gram_pre_op', /^gram_pre_op$/, (ret)->
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
        s  = """.strict("$1.hash_key==tok_un_op#{aux_tail}")"""#"
        ret.gram_list.push "#{q.ljust 50}#{mx.ljust 50}#{s}"
      
      ret.gram_list.push """
        q("rvalue",  "#pre_op #rvalue")                   .mx("priority=#pre_op.priority ult=pre_op ti=pre_op")   .strict("#rvalue[1].priority<=#pre_op.priority")
        
      """#"
      
      return
    
    ret
  
  bp = col.autogen 'gram_post_op', /^gram_post_op$/, (ret)->
    ret.hash.inc    = true # ++ --
    
    ret.hash.ban_list   = [] # если надо убить какой-то отдельный оператор
    ret.hash.extra_list = [] # если надо добавить какой-то отдельный оператор
    ret.hash.default_priority = 1
    ret.hash.priority_hash = {}
    
    ret.compile_fn = ()->
      op_list = []
      op_list.append "++ --".split /\s+/g if ret.hash.inc
      
      op_list.append ret.hash.extra_list
      for v in ret.hash.ban_list
        op_list.remove v
      
      ret.gram_list = []
      for op in op_list
        str_op = JSON.stringify(gram_escape op)
        priority = ret.hash.priority_hash[op] or ret.hash.default_priority
        
        q  = """q("post_op", #{str_op})"""#"
        mx = """.mx("priority=#{priority}")"""#"
        s  = """.strict("$1.hash_key==tok_un_op")"""#"
        ret.gram_list.push "#{q.ljust 50}#{mx.ljust 50}#{s}"
      
      ret.gram_list.push """
        q("rvalue",  "#rvalue #post_op")                  .mx("priority=#post_op.priority ult=post_op ti=post_op").strict("#rvalue[1].priority<#post_op.priority !#rvalue.tail_space")
        
      """#"
      
      return
    
    ret
  
  bp = col.autogen 'gram_inline_comment', /^gram_inline_comment$/, (ret)->
    ret
  
  bp = col.autogen 'gram_multiline_comment', /^gram_multiline_comment$/, (ret)->
    ret
  
  bp = col.autogen 'gram_stmt', /^gram_stmt$/, (ret)->
    ret.compile_fn = ()->
      ret.gram_list = [
        '''
        q('stmt_plus', '#stmt')                           .mx("priority=#{base_priority} ult=deep_scope ti=pass")
        q('stmt_plus', '#stmt #stmt_plus')                .mx("priority=#{base_priority} ult=deep_scope").strict("$1.eol")
        q('stmt_plus', '#stmt_plus #eol #stmt')           .mx("priority=#{base_priority} ult=deep_scope ti=stmt_plus_last eol_pass=1")
        
        '''#'
      ]
      return
    ret
  
  # дает {} : и string
  bp = col.autogen 'gram_hash', /^gram_hash$/, (ret)->
    ret.hash.key_int          = true
    ret.hash.key_float        = true
    ret.hash.key_string       = true
    ret.hash.key_bracket_expr = false
    ret.hash.skip_bracket     = false
    ret.hash.multiline        = true
    ret.hash.skip_comma_multiline = true
    ret.hash.trailing_comma   = true
    ret
  
  bp = col.autogen 'gram_array', /^gram_array$/, (ret)->
    ret.hash.key_int          = true
    ret.hash.multiline        = true
    ret.hash.skip_comma_multiline = true
    ret
  
  bp = col.autogen 'gram_class', /^gram_class$/, (ret)->
    ret
  
  bp = col.autogen 'gram_type', /^gram_type$/, (ret)->
    ret.hash.nest = true
    ret.hash.field = true
    ret.compile_fn = ()->
      ret.gram_list = []
      
      aux_nest = ""
      if ret.hash.nest
        aux_nest = " #type_nest?"
        ret.gram_list.push '''
          q('type_list', '#type')
          q('type_list', '#type , #type_list')
          q('type_nest', '< #type_list >')
        '''#'
        
      aux_field = ""
      if ret.hash.field
        aux_field = " #type_field?"
        ret.gram_list.push '''
          q('type_field_kv', '#tok_identifier : #type')
          q('type_field_kv_list', '#type_field_kv')
          q('type_field_kv_list', '#type_field_kv , #type_field_kv_list')
          q('type_field', '{ #type_field_kv_list }')
        '''#'
      str = "q('type', '#tok_identifier#{aux_nest}#{aux_field}')"
      ret.gram_list.push """
        #{str.ljust 50}.mx("ult=type_name ti=pass")
        
        """#"
      
      return
    ret
  
  bp = col.autogen 'gram_var_decl', /^gram_var_decl$/, (ret)->
    ret.hash.require_list = ['gram_type']
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('stmt', 'var #tok_identifier : #type')          .mx("ult=var_decl ti=var_decl")
        
      '''#'
      return
    ret
  
  bp = col.autogen 'gram_fn_decl', /^gram_fn_decl$/, (ret)->
    # ret.hash.arrow = true
    ret.hash.fat_arrow = true # LATER
    ret.hash.require_list = ['gram_type']
    
    ret.compile_fn = ()->
      ret.gram_list = []
      # TODO default value
      # q('rvalue', '( #fn_decl_arg_list? ) : #type ->').mx("ult=closure")
      ret.gram_list.push '''
        q('fn_decl_arg', '#tok_identifier : #type')
        q('fn_decl_arg_list', '#fn_decl_arg')
        q('fn_decl_arg_list', '#fn_decl_arg , #fn_decl_arg_list')
        q('stmt', '#tok_identifier ( #fn_decl_arg_list? ) : #type -> #block?').mx('ult=fn_decl')
        q('stmt', '#tok_identifier ( #fn_decl_arg_list? ) : #type -> #rvalue').mx('ult=fn_decl')
      '''#'
      
      return
    ret
  
  bp = col.autogen 'gram_class_decl', /^gram_class_decl$/, (ret)->
    ret.hash.require_list = ['gram_fn_decl', 'gram_var_decl']
    
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('stmt', 'class #tok_identifier')        .mx('ult=class_decl')
        q('stmt', 'class #tok_identifier #block') .mx('ult=class_decl eol=1')
      '''#'
      
      return
    ret
  
  # todo string (single/double)
  # todo string interpolate
  # todo multiline string+interpolate
  # todo regex
  # todo here regex +interpolate