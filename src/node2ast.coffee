Type = require 'type'
ast = require 'ast4gen'

pre_op_map =
  '++'  : 'INC_RET'
  '--'  : 'DEC_RET'
  '!'   : 'BOOL_NOT'
  '~'   : 'BIT_NOT'
  'not' : 'BOOL_NOT' # пока так. На самом деле ti
  '+'   : 'PLUS'
  '-'   : 'MINUS'

post_op_map =
  '++'  : 'RET_INC'
  '--'  : 'RET_DEC'
  '?'   : 'IS_NOT_NULL'
  

bin_op_map =
  '+' : 'ADD'
  '-' : 'SUB'
  '*' : 'MUL'
  '/' : 'DIV'
  '%' : 'MOD'
  '**' : 'POW'
  
  '&' : 'BIT_AND'
  '|' : 'BIT_OR'
  '^' : 'BIT_XOR'
  
  '&&' : 'BOOL_AND'
  '||' : 'BOOL_OR'
  '^^' : 'BOOL_XOR'
  
  'and' : 'BOOL_AND'
  'or'  : 'BOOL_OR'
  'xor' : 'BOOL_XOR'
  
  '>>' : 'SHR'
  '<<' : 'SHL'
  '>>>' : 'LSR'
  
  '=' : 'ASSIGN'
  '+=' : 'ASS_ADD'
  '-=' : 'ASS_SUB'
  '*=' : 'ASS_MUL'
  '/=' : 'ASS_DIV'
  '%=' : 'ASS_MOD'
  '**=' : 'ASS_POW'
  
  '>>=' : 'ASS_SHR'
  '<<=' : 'ASS_SHL'
  '>>>=' : 'ASS_LSR'
  
  '&=' : 'ASS_BIT_AND'
  '|=' : 'ASS_BIT_OR'
  '^=' : 'ASS_BIT_XOR'
  
  '&&=' : 'ASS_BOOL_AND'
  '||=' : 'ASS_BOOL_OR'
  '^^=' : 'ASS_BOOL_XOR'
  
  '==' : 'EQ'
  '!=' : 'NE'
  '<>' : 'NE'
  '>'  : 'GT'
  '<'  : 'LT'
  '>=' : 'GTE'
  '<=' : 'LTE'
  
  # INDEX_ACCESS : true # a[b] как бинарный оператор
seek_token = (name, t)->
  for v in t.value_array
    return v if v.mx_hash.hash_key == name
  null
seek_token_list = (name, t)->
  list = []
  for v in t.value_array
    list.push v if v.mx_hash.hash_key == name
  list
seek_token_list_deep = (name, t)->
  list = []
  for v in t.value_array
    if v.mx_hash.hash_key == name
      list.push v
    else
      list.append seek_token_list_deep name, v
  list
gen = null
seek_and_set_line_pos = (ret, root)->
  
  walk = (root)->
    if root.line != -1
      ret.line = root.line
      ret.pos  = root.pos
      return true
    for v in root.value_array
      return true if walk(v)
    return false
  walk root
  return

wrap_scope = (stmt)->
  ret = new ast.Scope
  ret.list.push stmt
  ret

@macro_fn_map = macro_fn_map =
  'loop' : (condition, block)->
    if condition
      throw new Error "macro loop should not have condition"
    ret = new ast.Loop
    seek_and_set_line_pos ret, block
    
    ret.scope= gen block
    ret
  'while' : (condition, block)->
    if !condition
      throw new Error "macro while should have condition"
    ret = new ast.While
    seek_and_set_line_pos ret, block
    
    ret.cond= gen condition
    ret.scope= gen block
    ret


fix_iterator = (t)->
  # hack. В идеале должен быть lvalue
  t.mx_hash.hacked = 'true'
  t.mx_hash.ult = 'id'
  t.value_view = t.value
  t

hash_key_to_value = (key)->
  if key[0] in ["'", '"']
    eval key
  else
    key

@gen = gen = (root, opt={})->
  switch root.mx_hash.ult
    when "deep_scope"
      ret = new ast.Scope
      seek_and_set_line_pos ret, root
      
      for v in root.value_array
        continue if v.mx_hash.hash_key == 'eol'
        loc = gen v, opt
        continue if !loc
        if loc instanceof ast.Scope
          ret.list.append loc.list
        else
          ret.list.push loc
      ret
    
    when "block"
      gen root.value_array[1], opt
    
    when "comment"
      null
    
    when "var_decl"
      ret = new ast.Var_decl
      seek_and_set_line_pos ret, root
      
      ret.name = root.value_array[1].value
      ret.type = new Type root.value_array[3].value_view.replace(/\s+/g, '')
      ret
    
    when "deep"
      gen root.value_array[0], opt
    
    when "id"
      if root.value_view in ["true", "false"]
        ret = new ast.Const
        seek_and_set_line_pos ret, root
        
        ret.val = root.value_view
        ret.type = new Type "bool"
        ret
      else if root.value_view == "continue"
        ret = new ast.Continue
        seek_and_set_line_pos ret, root
        
        ret
      else if root.value_view == "break"
        ret = new ast.Break
        seek_and_set_line_pos ret, root
        
        ret
      else
        ret = new ast.Var
        seek_and_set_line_pos ret, root
        
        ret.name = root.value_view
        ret
    
    when "const"
      ret = new ast.Const
      seek_and_set_line_pos ret, root
      
      ret.val = root.value_view
      ret.type = new Type root.mx_hash.type
      ret
    
    when "bin_op"
      ret = new ast.Bin_op
      seek_and_set_line_pos ret, root
      
      ret.op = bin_op_map[op = root.value_array[1].value_view]
      if !ret.op
        ### !pragma coverage-skip-block ###
        throw new Error "unknown bin_op=#{op}"
      ret.a = gen root.value_array[0], opt
      ret.b = gen root.value_array[2], opt
      ret
    
    when "pre_op"
      ret = new ast.Un_op
      seek_and_set_line_pos ret, root
      
      ret.op = pre_op_map[op = root.value_array[0].value_view]
      if !ret.op
        ### !pragma coverage-skip-block ###
        throw new Error "unknown pre_op=#{op}"
      ret.a = gen root.value_array[1], opt
      ret
    
    when "post_op"
      ret = new ast.Un_op
      seek_and_set_line_pos ret, root
      
      ret.op = post_op_map[op = root.value_array[1].value_view]
      if !ret.op
        ### !pragma coverage-skip-block ###
        throw new Error "unknown post_op=#{op}"
      ret.a = gen root.value_array[0], opt
      ret
    
    when "field_access"
      ret = new ast.Field_access
      seek_and_set_line_pos ret, root
      
      ret.t    = gen root.value_array[0], opt
      ret.name = root.value_array[2].value
      ret
    
    when "index_access"
      ret = new ast.Bin_op
      seek_and_set_line_pos ret, root
      
      ret.op = 'INDEX_ACCESS'
      ret.a    = gen root.value_array[0], opt
      ret.b    = gen root.value_array[2], opt
      ret
    
    when "bracket"
      gen root.value_array[1], opt
    
    when "macro"
      macro_name = root.value_array[0].value
      condition = seek_token 'rvalue', root
      scope = seek_token 'block', root
      if !fn = macro_fn_map[macro_name]
        throw new Error "unknown macro '#{macro_name}'. Known macro list = [#{Object.keys(macro_fn_map).join ', '}]"
      fn(condition, scope)
    
    when "if_postfix"
      condition = seek_token 'rvalue', root
      block = seek_token 'stmt', root
      
      ret = new ast.If
      seek_and_set_line_pos ret, block
      ret.cond= gen condition
      ret.t   = wrap_scope gen block
      ret
    
    when "if"
      if_walk = (condition, block, if_tail_stmt)->
        _ret = new ast.If
        seek_and_set_line_pos _ret, block
        _ret.cond= gen condition
        _ret.t   = gen block
        
        if if_tail_stmt
          value0 = if_tail_stmt.value_array[0].value
          value1 = if_tail_stmt.value_array[1].value
          is_else_if = false
          if value0 in ['elseif', 'elsif', 'elif']
            is_else_if = true
          if value1 == 'if'
            is_else_if = true
          
          if is_else_if
            condition = seek_token 'rvalue', if_tail_stmt
            block = seek_token 'block', if_tail_stmt
            new_if_tail_stmt = seek_token 'if_tail_stmt', if_tail_stmt
            _ret.f.list.push if_walk condition, block, new_if_tail_stmt
          else
            _ret.f = gen seek_token 'block', if_tail_stmt
        _ret
      
      condition = seek_token 'rvalue', root
      block = seek_token 'block', root
      if_tail_stmt = seek_token 'if_tail_stmt', root
      if_walk condition, block, if_tail_stmt
    
    when "switch"
      condition = seek_token 'rvalue', root
      switch_tail_stmt = seek_token 'switch_tail_stmt', root
      
      ret = new ast.Switch
      seek_and_set_line_pos ret, root
      ret.cond= gen condition
      
      while switch_tail_stmt
        switch switch_tail_stmt.mx_hash.ult
          when 'switch_when'
            condition = gen seek_token 'rvalue', switch_tail_stmt
            v = switch_tail_stmt
            unless condition instanceof ast.Const
              perr condition
              throw new Error "when cond should be const"
            ret.hash[condition.val] = gen seek_token 'block', switch_tail_stmt
          when 'switch_else'
            ret.f = gen seek_token 'block', switch_tail_stmt
          else
            ### !pragma coverage-skip-block ###
            perr root
            throw new Error "unknown ult=#{root.mx_hash.ult} in switch"
        
        switch_tail_stmt = seek_token 'switch_tail_stmt', switch_tail_stmt
      ret
    
    when "for_range"
      ret = new ast.For_range
      seek_and_set_line_pos ret, root
      
      ret.exclusive = seek_token('ranger', root).value_view == '...'
      [_for_skip, i] = seek_token_list 'tok_identifier', root
      ret.i = gen fix_iterator i, opt
      
      [a, b, by_node] = seek_token_list 'rvalue', root
      ret.a = gen a, opt
      ret.b = gen b, opt
      ret.step = gen by_node, opt if by_node
      ret.scope = gen seek_token('block', root), opt
      ret
    
    when "for_col"
      ret = new ast.For_col
      seek_and_set_line_pos ret, root
      
      [_for_skip, k, v] = seek_token_list 'tok_identifier', root
      if !v
        v = k
        k = null
      
      ret.k = gen fix_iterator k, opt if k
      ret.v = gen fix_iterator v, opt
      ret.t = gen seek_token('rvalue', root), opt
      
      ret.scope = gen seek_token('block', root), opt
      ret

    when "fn_decl", "cl_decl"
      ret = new ast.Fn_decl
      seek_and_set_line_pos ret, root
      
      if name = seek_token 'tok_identifier', root
        ret.name = name.value
      if root.mx_hash.ult == "cl_decl"
        ret.is_closure = true
      ret.type = new Type "function"
      
      arg_list = []
      if fn_decl_arg_list = seek_token 'fn_decl_arg_list', root
        walk = (t)->
          arg = t.value_array[0]
          arg_list.push {
            name : arg.value_array[0].value
            type : new Type arg.value_array[2].value_view.replace(/\s+/g, '')
          }
          
          if t.value_array.length == 3
            walk t.value_array[2]
          return
        walk fn_decl_arg_list
      ret.type.nest_list.push new Type seek_token('type', root).value_view.replace(/\s+/g, '')
      for arg in arg_list
        ret.type.nest_list.push arg.type
        ret.arg_name_list.push arg.name
      
      scope = null
      scope ?= seek_token 'block', root
      scope ?= seek_token 'rvalue', root
      if scope
        ret.scope = gen scope, opt
      
      ret
    
    when "fn_call"
      ret = new ast.Fn_call
      seek_and_set_line_pos ret, root
      
      ret.fn = gen root.value_array[0], opt
      arg_list = []
      if fn_decl_arg_list = seek_token 'fn_call_arg_list', root
        walk = (t)->
          arg_list.push gen t.value_array[0], opt
          if t.value_array.length == 3
            walk t.value_array[2]
          return
        walk fn_decl_arg_list
      ret.arg_list = arg_list
      ret
      
    when "return"
      ret = new ast.Ret
      seek_and_set_line_pos ret, root
      
      if root.value_array[1]
        ret.t = gen root.value_array[1], opt
      ret
    
    when "class_decl"
      ret = new ast.Class_decl
      seek_and_set_line_pos ret, root
      
      ret.name = root.value_array[1].value
      
      if scope = seek_token 'block', root
        ret.scope = gen scope, opt
      
      ret
    
    when "require"
      # HACK WAY to parse single and double quote
      loc_ast_list = opt.require eval root.value_array[1].value
      ret = new ast.Scope
      seek_and_set_line_pos ret, root
      
      ret.need_nest = false
      for loc_ast in loc_ast_list
        loc_scope = gen loc_ast, opt
        ret.list.append loc_scope.list
      ret
    
    when "struct_init"
      ret = new ast.Struct_init
      seek_and_set_line_pos ret, root
      
      kv_list = seek_token_list_deep 'struct_init_kv', root
      for kv in kv_list
        key   = hash_key_to_value kv.value_array[0].value
        value = gen kv.value_array[2], opt
        ret.hash[key] = value
      
      ret
    
    when "at"
      ret = new ast.Var
      seek_and_set_line_pos ret, root
      ret.name = "this"
      # ret.type = new Type "" # LATER
      
      ret
    
    when "at_field_access"
      ret = new ast.Field_access
      
      a_this = new ast.Var
      a_this.name = "this"
      seek_and_set_line_pos ret, root
      ret.t = a_this
      ret.name = root.value_array[1].value
      
      ret
    
    else
      ### !pragma coverage-skip-block ###
      perr root
      throw new Error "unknown ult=#{root.mx_hash.ult}"
