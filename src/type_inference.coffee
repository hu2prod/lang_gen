Type = require 'type'
ast = require 'ast4gen'


class Ti_context
  parent    : null
  var_hash  : {}
  type_hash : {}
  constructor:()->
    @var_hash = ast.default_var_hash_gen() # на самом деле ничего не даст т.к. уже есть workaround для true false
    @type_hash= ast.default_type_hash_gen()
  
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

class_prepare = (ctx, t)->
  ctx.type_hash[t.name] = t
  for v in t.scope.list
    switch v.constructor.name
      when "Var_decl"
        t._prepared_field2type[v.name] = v.type
      when "Fn_decl"
        # BUG внутри scope уже есть this и ему нужен тип...
        t._prepared_field2type[v.name] = v.type
  return
@gen = (ast_tree, opt)->
  walk = (t, ctx)->
    switch t.constructor.name
      when "Scope"
        ctx_nest = ctx.mk_nest()
        for v in t.list
          if v.constructor.name == "Class_decl"
            class_prepare ctx, v
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
        
        found = false
        if list
          for tuple in list
            continue if tuple[0] != a
            continue if tuple[1] != b
            found = true
            t.type = new Type tuple[2]
        
        # extra cases
        if !found
          # may produce invalid result
          if t.op == 'ASSIGN'
            t.type = t.a.type
            found = true
          else if t.op in ['EQ', 'NE']
            t.type = new Type 'bool'
            found = true
          else if t.op == 'INDEX_ACCESS'
            switch t.a.type.main
              when 'string'
                t.type = new Type 'string'
                found = true
              when 'array'
                t.type = t.a.type.nest_list[0]
                found = true
              when 'hash'
                t.type = t.a.type.nest_list[0]
                found = true
              when 'hash_int'
                t.type = t.a.type.nest_list[0]
                found = true
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
        
        if t.name == 'new'
          field_type = new Type 'function'
          field_type.nest_list[0] = t.t.type
        else if !field_type = field_hash[t.name]
          throw new Error "unknown field. '#{t.name}' at type '#{root_type}'. Allowed fields [#{Object.keys(field_hash).join ', '}]"
        field_type = ast.type_actualize field_type, t.t.type
        t.type = field_type
        t.type
      
      when "If"
        walk(t.cond, ctx)
        walk(t.t, ctx.mk_nest())
        walk(t.f, ctx.mk_nest())
        null
      
      when "Switch"
        walk(t.cond, ctx)
        for k,v of t.hash
          walk(v, ctx.mk_nest())
        walk(t.f, ctx.mk_nest()) if t.f
        null
      
      when "For_range"
        walk(t.i, ctx)
        walk(t.a, ctx)
        walk(t.b, ctx)
        walk(t.step, ctx) if t.step
        walk(t.scope, ctx.mk_nest())
        null
      
      when "For_col"
        walk(t.k, ctx) if t.k
        walk(t.v, ctx)
        walk(t.t, ctx)
        walk(t.scope, ctx.mk_nest())
        null
      
      when "Un_op"
        list = ast.un_op_ret_type_hash_list[t.op]
        a = walk(t.a, ctx).toString()
        found = false
        if t.op == 'IS_NOT_NULL'
          t.type = new Type 'bool'
          found = true
        if list
          for tuple in list
            continue if tuple[0] != a
            found = true
            t.type = new Type tuple[1]
        if !found
          throw new Error "unknown un_op=#{t.op} a=#{a}"
        t.type
      
      when "Loop"
        walk t.scope, ctx.mk_nest()
        null
      
      when "While"
        walk t.cond, ctx.mk_nest()
        walk t.scope, ctx.mk_nest()
        null
      
      when "Fn_decl"
        ctx.var_hash[t.name] = t.type
        ctx_nest = ctx.mk_nest()
        for name,k in t.arg_name_list
          type = t.type.nest_list[k+1]
          ctx_nest.var_hash[name] = type
        walk t.scope, ctx_nest
        t.type
      
      when "Fn_call"
        root_type = walk t.fn, ctx
        for arg in t.arg_list
          walk arg, ctx
        t.type = root_type.nest_list[0]
      
      when "Continue", "Break"
        null
      
      when "Ret"
        walk t.t, ctx if t.t
        null
      
      when "Class_decl"
        class_prepare ctx, t
        
        ctx_nest = ctx.mk_nest()
        ctx_nest.var_hash["this"] = new Type t.name
        walk t.scope, ctx_nest
        t.type
      
      when "Struct_init"
        field_hash = {}
        for k,v of t.hash
          field_hash[k] = walk v, opt
        t.type = new Type "struct"
        t.type.field_hash = field_hash
        t.type
      else
        ### !pragma coverage-skip-block ###
        p t
        throw new Error "unknown node '#{t.constructor.name}'"
  walk ast_tree, new Ti_context
  
  
  ast_tree
