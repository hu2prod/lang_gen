Type = require 'type'
type = (t)->new Type t
ast = require 'ast4gen'

pre_op_map =
  '++'  : 'RET_INC'
  '--'  : 'RET_DEC'
  '!'   : 'BOOL_NOT'
  '~'   : 'BIT_NOT'
  'not' : 'BOOL_NOT' # пока так. На самом деле ti
  '+'   : 'PLUS'
  '-'   : 'MINUS'

post_op_map =
  '++'  : 'INC_RET'
  '--'  : 'DEC_RET'
  

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

@_gen = gen = (root)->
  switch root.mx_hash.ult
    when "deep_scope"
      ret = new ast.Scope
      for v in root.value_array
        continue if v.mx_hash.hash_key == 'eol'
        loc = gen v
        if loc instanceof ast.Scope
          ret.list.append loc.list
        else
          ret.list.push loc
      ret
    
    when "var_decl"
      ret = new ast.Var_decl
      ret.name = root.value_array[1].value
      ret.type = type root.value_array[3].value_view.replace(/\s+/g, '')
      ret
    
    when "deep"
      gen root.value_array[0]
    
    when "id"
      ret = new ast.Var
      ret.name = root.value_view
      ret
    
    when "const"
      ret = new ast.Const
      ret.val = root.value_view
      ret.type = type root.mx_hash.type
      ret
    
    when "bin_op"
      ret = new ast.Bin_op
      ret.op = bin_op_map[op = root.value_array[1].value_view]
      if !ret.op
        throw new Error "unknown bin_op=#{op}"
      ret.a = gen root.value_array[0]
      ret.b = gen root.value_array[2]
      ret
    
    when "pre_op"
      ret = new ast.Un_op
      ret.op = pre_op_map[op = root.value_array[0].value_view]
      if !ret.op
        throw new Error "unknown pre_op=#{op}"
      ret.a = gen root.value_array[1]
      ret
    
    when "post_op"
      ret = new ast.Un_op
      ret.op = post_op_map[op = root.value_array[1].value_view]
      if !ret.op
        throw new Error "unknown post_op=#{op}"
      ret.a = gen root.value_array[0]
      ret
    
    else
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
  
@gen = (_root)->
  ast_tree = gen _root
  # TODO type set
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
          throw new Error "unknown bin_op=#{t.op}"
        found = false
        for tuple in list
          continue if tuple[0] != a
          continue if tuple[1] != b
          found = true
          t.type = type tuple[2]
        if !found
          throw new Error "unknown bin_op=#{t.op} a=#{a} b=#{b}"
        t.type
      else
        null
  walk ast_tree, new Ti_context
  
  
  ast_tree