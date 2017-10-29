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
gen = null

macro_fn_map =
  'if' : (condition, block)->
    if !condition
      throw new Error "macro if should have condition"
    ret = new ast.If
    ret.cond= gen condition
    ret.t   = gen block
    ret

@_gen = gen = (root)->
  switch root.mx_hash.ult
    when "deep_scope"
      ret = new ast.Scope
      for v in root.value_array
        continue if v.mx_hash.hash_key == 'eol'
        loc = gen v
        continue if !loc
        if loc instanceof ast.Scope
          ret.list.append loc.list
        else
          ret.list.push loc
      ret
    
    when "block"
      gen root.value_array[1]
    
    when "comment"
      null
    
    when "var_decl"
      ret = new ast.Var_decl
      ret.name = root.value_array[1].value
      ret.type = new Type root.value_array[3].value_view.replace(/\s+/g, '')
      ret
    
    when "deep"
      gen root.value_array[0]
    
    when "id"
      if root.value_view in ["true", "false"]
        ret = new ast.Const
        ret.val = root.value_view
        ret.type = new Type "bool"
        ret
      else
        ret = new ast.Var
        ret.name = root.value_view
        ret
    
    when "const"
      ret = new ast.Const
      ret.val = root.value_view
      ret.type = new Type root.mx_hash.type
      ret
    
    when "bin_op"
      ret = new ast.Bin_op
      ret.op = bin_op_map[op = root.value_array[1].value_view]
      if !ret.op
        ### !pragma coverage-skip-block ###
        throw new Error "unknown bin_op=#{op}"
      ret.a = gen root.value_array[0]
      ret.b = gen root.value_array[2]
      ret
    
    when "pre_op"
      ret = new ast.Un_op
      ret.op = pre_op_map[op = root.value_array[0].value_view]
      if !ret.op
        ### !pragma coverage-skip-block ###
        throw new Error "unknown pre_op=#{op}"
      ret.a = gen root.value_array[1]
      ret
    
    when "post_op"
      ret = new ast.Un_op
      ret.op = post_op_map[op = root.value_array[1].value_view]
      if !ret.op
        ### !pragma coverage-skip-block ###
        throw new Error "unknown post_op=#{op}"
      ret.a = gen root.value_array[0]
      ret
    
    when "field_access"
      ret = new ast.Field_access
      ret.t    = gen root.value_array[0]
      ret.name = root.value_array[2].value
      ret
    
    when "macro"
      macro_name = root.value_array[0].value
      condition = seek_token 'rvalue', root
      scope = seek_token 'block', root
      if !fn = macro_fn_map[macro_name]
        throw new Error "unknown macro '#{macro_name}'. Known macro list = [#{Object.keys(macro_fn_map).join ', '}]"
      fn(condition, scope)
    
    when "for_range"
      ret = new ast.For_range
      ret.exclusive = seek_token('ranger', root).value_view == '...'
      [_for_skip, i] = seek_token_list 'tok_identifier', root
      # hack
      i.mx_hash.hacked = 'true'
      i.mx_hash.ult = 'id'
      i.value_view = i.value
      
      ret.i = gen i
      
      [a, b, by_node] = seek_token_list 'rvalue', root
      ret.a = gen a
      ret.b = gen b
      ret.step = gen by_node if by_node
      ret.scope = gen seek_token 'block', root
      ret
    
    when "fn_decl"
      ret = new ast.Fn_decl
      if name = seek_token 'tok_identifier', root
        ret.name = name.value
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
        ret.scope = gen scope
      
      ret
    
    when "return"
      ret = new ast.Ret
      if root.value_array[1]
        ret.t = gen root.value_array[1]
      ret
    
    when "class_decl"
      ret = new ast.Class_decl
      ret.name = root.value_array[1].value
      
      if scope = seek_token 'block', root
        ret.scope = gen scope
      
      ret
      
    
    else
      ### !pragma coverage-skip-block ###
      perr root
      throw new Error "unknown ult=#{root.mx_hash.ult}"

class Ti_context
  parent    : null
  var_hash  : {}
  type_hash : {}
  constructor:()->
    @var_hash = {}
    @type_hash= {}
  
  mk_nest : ()->
    ret = new Ti_context
    ret.parent = @
    ret
  
  check_id : (id)->
    return ret if ret = @var_hash[id]
    if @parent
      return @parent.check_id id
    throw new Error "can't find decl for id '#{id}'"
  
  check_type : (_type)->
    return ret if ret = @type_hash[_type]
    if @parent
      return @parent.check_type _type
    throw new Error "can't find type '#{_type}'"
  
@gen = (_root)->
  ast_tree = gen _root
  
  walk = (t, ctx)->
    switch t.constructor.name
      when "Scope"
        ctx_nest = ctx.mk_nest()
        for v in t.list
          walk v, ctx_nest
        null
      
      when "Var_decl"
        ctx.var_hash[t.name] = t.type
        null
      
      when "Var"
        t.type = ctx.check_id t.name
      
      when "Const"
        t.type
      
      when "Bin_op"
        list = ast.bin_op_ret_type_hash_list[t.op]
        a = walk(t.a, ctx).toString()
        b = walk(t.b, ctx).toString()
        if !list
          ### !pragma coverage-skip-block ###
          throw new Error "unknown bin_op=#{t.op}"
        found = false
        for tuple in list
          continue if tuple[0] != a
          continue if tuple[1] != b
          found = true
          t.type = new Type tuple[2]
        if !found
          throw new Error "unknown bin_op=#{t.op} a=#{a} b=#{b}"
        t.type
      
      when "Field_access"
        root_type = walk(t.t, ctx)
        if root_type.main == 'struct'
          field_hash = root_type.field_hash
        else
          class_decl = ctx.check_type root_type.main
          field_hash = class_decl._prepared_field2type
        
        if !field_type = field_hash[t.name]
          throw new Error "unknown field. '#{t.name}' at type '#{root_type}'. Allowed fields [#{Object.keys(field_hash).join ', '}]"
        t.type = field_type
        t.type
      
      when "If"
        walk(t.cond, ctx)
        walk(t.t, ctx.mk_nest())
        walk(t.f, ctx.mk_nest())
        null
      
      when "For_range"
        walk(t.i, ctx)
        walk(t.a, ctx)
        walk(t.b, ctx)
        walk(t.step, ctx) if t.step
        walk(t.scope, ctx.mk_nest())
        null
      
      when "Un_op"
        list = ast.un_op_ret_type_hash_list[t.op]
        a = walk(t.a, ctx).toString()
        if !list
          ### !pragma coverage-skip-block ###
          throw new Error "unknown un_op=#{t.op}"
        found = false
        for tuple in list
          continue if tuple[0] != a
          found = true
          t.type = new Type tuple[1]
        if !found
          throw new Error "unknown un_op=#{t.op} a=#{a}"
        t.type
      
      when "Fn_decl"
        ctx_nest = ctx.mk_nest()
        for name,k in t.arg_name_list
          type = t.type.nest_list[k+1]
          ctx_nest.var_hash[name] = type
        walk t.scope, ctx_nest
        t.type
      
      when "Ret"
        walk t.t, ctx if t.t
        null
      
      when "Class_decl"
        ctx.type_hash[t.name] = t
        for v in t.scope.list
          switch v.constructor.name
            when "Var_decl"
              t._prepared_field2type[v.name] = v.type
            when "Fn_decl"
              # BUG внутри scope уже есть this и ему нужен тип...
              t._prepared_field2type[v.name] = v.type
        
        ctx_nest = ctx.mk_nest()
        ctx_nest.var_hash["this"] = new Type t.name
        walk t.scope, ctx_nest
        t.type
      else
        null
  walk ast_tree, new Ti_context
  
  
  ast_tree