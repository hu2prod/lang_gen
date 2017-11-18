require 'fy/codegen'
{
  gram_escape
} = require 'gram2'

module.exports = (col)->
  return if col.chk_file __FILE__
  bp = col.autogen 'gram_main', (ret)->
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
        """#"
      
      ret.hash.cont = """
        require \"fy\"
        {Gram, show_diff} = require \"gram2\"
        module = @
        g = new Gram
        {_tokenizer} = require \"./tok.gen.coffee\"
        do ()->
          for v in _tokenizer.parser_list
            g.extra_hash_key_list.push v.name
          
        q = (a, b)->g.rule a,b
        base_priority = -9000
        #{join_list gram_list}
        """#"
      return
    ret
  # ###################################################################################################
  bp = col.autogen 'gram_main_block_opt', (ret)->
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
        class Block
          list : [] # 2 варианта 1. обычные token'ы 2. Block
          res  : null
          constructor:()->
            @list = []
          push : (t)->@list.push t
        
        @__parse = (tok_res, opt={})->
          gram_res = g.go tok_res,
            expected_token : opt.expected_token or \"stmt_plus\"
            mode_full      : opt.mode_full or false
          # p Object.keys(g)
          if gram_res.length == 0
            throw new Error \"Parsing error. No proper combination found\"
          if gram_res.length != 1
            [a,b] = gram_res
            show_diff a,b
            ### !pragma coverage-skip-block ###
            throw new Error \"Parsing error. More than one proper combination found \#{gram_res.length}\"
          gram_res
        
        @_parse = (tok_res, opt={})->
          root = new Block
          stack = []
          block = root
          for tok_list in tok_res
            tok = tok_list[0]
            switch tok.mx_hash.hash_key
              when 'indent'
                nest = new Block
                nest.push tok_list
                
                block.push nest
                stack.push block
                block = nest
              when 'dedent'
                block.push tok_list
                block = stack.pop()
              else
                block.push tok_list
          
          node_total  = 0
          block_total = 0
          walk = (block)->
            block_total++
            for sub in block.list
              if sub instanceof Block
                walk sub
              else
                node_total++
            return
          walk root
          
          node_count  = 0
          block_count = 0
          
          loc_opt = clone opt
          loc_opt.expected_token = 'block'
          walk = (block, is_root)->
            if opt.progress
              process.stdout.write \"block=\#{block_count}/\#{block_total} node=\#{node_count}/\#{node_total}                   \\r\"
            tok_list_list = []
            for sub in block.list
              if sub instanceof Block
                walk sub, false
                tok_list_list.push sub.res
              else
                node_count++
                tok_list_list.push sub
            
            if is_root
              block.res = module.__parse tok_list_list, opt
            else
              block.res = module.__parse tok_list_list, loc_opt
            block_count++
            if opt.progress
              process.stdout.write \"block=\#{block_count}/\#{block_total} node=\#{node_count}/\#{node_total}                   \\r\"
            return
          if opt.progress
            process.stdout.write \"\\n\"
          walk root, true
          root.res
        
        @parse = (tok_res, opt, on_end)->
          try
            gram_res = module._parse tok_res, opt
          catch e
            return on_end e
          on_end null, gram_res
        """#"
      
      ret.hash.cont = """
        require \"fy\"
        {Gram, show_diff} = require \"gram2\"
        module = @
        g = new Gram
        {_tokenizer} = require \"./tok.gen.coffee\"
        do ()->
          for v in _tokenizer.parser_list
            g.extra_hash_key_list.push v.name
          
        q = (a, b)->g.rule a,b
        base_priority = -9000
        #{join_list gram_list}
        """#"
      return
    ret
  # ###################################################################################################
  bp = col.autogen 'gram_main_block_eol_opt', (ret)->
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
        class Block
          list : [] # 2 варианта 1. обычные token'ы 2. Block
          res  : null
          is_stmt : false
          constructor:()->
            @list = []
          push : (t)->@list.push t
        
        @__parse = (tok_res, opt={})->
          gram_res = g.go tok_res,
            expected_token : opt.expected_token or \"stmt_plus\"
            mode_full      : opt.mode_full or false
          # p Object.keys(g)
          if gram_res.length == 0
            throw new Error \"Parsing error. No proper combination found\"
          if gram_res.length != 1
            [a,b] = gram_res
            show_diff a,b
            ### !pragma coverage-skip-block ###
            throw new Error \"Parsing error. More than one proper combination found \#{gram_res.length}\"
          gram_res
        
        @_parse = (tok_res, opt={})->
          root = new Block
          stack = []
          block = root
          for tok_list in tok_res
            tok = tok_list[0]
            switch tok.mx_hash.hash_key
              when 'indent'
                nest = new Block
                nest.push tok_list
                
                block.push nest
                stack.push block
                block = nest
              when 'dedent'
                block.push tok_list
                block = stack.pop()
              else
                block.push tok_list
          # split by eol
          walk = (block)->
            chunk_list = []
            chunk = []
            eol_list = []
            for sub in block.list
              if sub[0]?.mx_hash?.hash_key == 'eol'
                eol_list.push sub
                chunk_list.push chunk
                chunk = []
                continue
              chunk.push sub
            if chunk.length
              chunk_list.push chunk
            idx = 0
            if chunk_list.length > 2
              block.list = []
              block.list.append chunk_list.shift()
              last = chunk_list.pop()
              for chunk in chunk_list
                block.list.push eol_list[idx++]
                sub = new Block
                sub.is_stmt = true
                sub.list = chunk
                block.list.push sub
              block.list.append last
            
            for sub in block.list
              if sub instanceof Block
                walk sub
            return
          walk root
          
          node_total  = 0
          block_total = 0
          walk = (block)->
            block_total++
            for sub in block.list
              if sub instanceof Block
                walk sub
              else
                node_total++
            return
          walk root
          
          node_count  = 0
          block_count = 0
          
          opt_block = clone opt
          opt_block.expected_token = 'block'
          opt_stmt = clone opt
          opt_stmt.expected_token = 'stmt_plus'
          walk = (block, is_root)->
            if opt.progress
              process.stdout.write \"block=\#{block_count}/\#{block_total} node=\#{node_count}/\#{node_total}                   \\r\"
            tok_list_list = []
            for sub in block.list
              if sub instanceof Block
                walk sub, false
                tok_list_list.push sub.res
              else
                node_count++
                tok_list_list.push sub
            
            if is_root or tok_list_list.last()[0].mx_hash?.hash_key != 'dedent'
              if block.is_stmt
                block.res = module.__parse tok_list_list, opt_stmt
                for v in block.res
                  # hack a bit
                  v.mx_hash.hash_key = 'stmt'
                  v.mx_hash.eol = 1
              else
                block.res = module.__parse tok_list_list, opt
            else
              block.res = module.__parse tok_list_list, opt_block
            block_count++
            if opt.progress
              process.stdout.write \"block=\#{block_count}/\#{block_total} node=\#{node_count}/\#{node_total}                   \\r\"
            return
          if opt.progress
            process.stdout.write \"\\n\"
          walk root, true
          root.res
        
        @parse = (tok_res, opt, on_end)->
          try
            gram_res = module._parse tok_res, opt
          catch e
            return on_end e
          on_end null, gram_res
        """#"
      
      ret.hash.cont = """
        require \"fy\"
        {Gram, show_diff} = require \"gram2\"
        module = @
        g = new Gram
        {_tokenizer} = require \"./tok.gen.coffee\"
        do ()->
          for v in _tokenizer.parser_list
            g.extra_hash_key_list.push v.name
          
        q = (a, b)->g.rule a,b
        base_priority = -9000
        #{join_list gram_list}
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
        s  = """.strict("$1.hash_key==tok_un_op#{aux_tail}")"""#"
        ret.gram_list.push "#{q.ljust 50}#{mx.ljust 50}#{s}"
      
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
        s  = """.strict("$1.hash_key==tok_un_op")"""#"
        ret.gram_list.push "#{q.ljust 50}#{mx.ljust 50}#{s}"
      
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
        q("rvalue",  "#rvalue [ #rvalue ]")               .mx("priority=#{base_priority} ult=index_access ti=index_access").strict("$1.priority==#{base_priority}")
        
      '''
      
    ret
  bp = col.autogen 'gram_bracket', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q("rvalue",  "( #rvalue )")                       .mx("priority=#{base_priority} ult=bracket ti=pass")
        
      '''
      
    ret
  
  bp = col.autogen 'gram_inline_comment', (ret)->
    ret
  
  bp = col.autogen 'gram_multiline_comment', (ret)->
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
  # ###################################################################################################
  
  bp = col.autogen 'gram_var_decl', (ret)->
    ret.hash.require_list = ['gram_type']
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('stmt', 'var #tok_identifier : #type')          .mx("ult=var_decl ti=var_decl")
        
      '''#'
      return
    ret
  
  bp = col.autogen 'gram_macro', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('stmt', '#tok_identifier #block')               .mx("ult=macro ti=macro eol=1")
        q('stmt', '#tok_identifier #rvalue #block')       .mx("ult=macro ti=macro eol=1").strict("#tok_identifier!='class'")
        
      '''#'
      return
  
  bp = col.autogen 'gram_for_range', (ret)->
    ret.hash.allow_step = true
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('ranger', '..')                                 .mx("ult=macro ti=macro eol=1")
        q('ranger', '...')                                .mx("ult=macro ti=macro eol=1")
        q('stmt', 'for #tok_identifier in [ #rvalue #ranger #rvalue ] #block').mx("ult=for_range ti=macro eol=1")
      '''#'
      if ret.hash.allow_step
        ret.gram_list.push '''
          q('stmt', 'for #tok_identifier in [ #rvalue #ranger #rvalue ] by #rvalue #block').mx("ult=for_range ti=macro eol=1")
        '''#'
      ret.gram_list.push ""
      return
  
  bp = col.autogen 'gram_for_col', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('stmt', 'for #tok_identifier                   in #rvalue #block').mx("ult=for_col ti=macro eol=1")
        q('stmt', 'for #tok_identifier , #tok_identifier in #rvalue #block').mx("ult=for_col ti=macro eol=1")
        
      '''#'
      return
  
  bp = col.autogen 'gram_field_access', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('lvalue', '#rvalue . #tok_identifier')          .mx("priority=#{base_priority} ult=field_access ti=macro").strict("$1.priority==#{base_priority}")
        
      '''#'
      return
    
  
  bp = col.autogen 'gram_fn_call', (ret)->
    ret.compile_fn = ()->
      ret.gram_list = []
      ret.gram_list.push '''
        q('fn_call_arg_list', '#rvalue')
        q('fn_call_arg_list', '#rvalue , #fn_call_arg_list')
        q('rvalue', '#rvalue ( #fn_call_arg_list? )')     .mx("priority=#{base_priority} ult=fn_call").strict("$1.priority==#{base_priority}")
        
      '''#'
      
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
      # q('rvalue', '( #fn_decl_arg_list? ) : #type ->').mx("ult=closure")
      ret.gram_list.push '''
        q('fn_decl_arg', '#tok_identifier : #type')
        q('fn_decl_arg_list', '#fn_decl_arg')
        q('fn_decl_arg_list', '#fn_decl_arg , #fn_decl_arg_list')
        q('stmt', '#tok_identifier ( #fn_decl_arg_list? ) : #type ->').mx('ult=fn_decl')
        q('stmt', '#tok_identifier ( #fn_decl_arg_list? ) : #type -> #block').mx('ult=fn_decl eol=1')
        q('stmt', '#tok_identifier ( #fn_decl_arg_list? ) : #type -> #rvalue').mx('ult=fn_decl')
        
        q('stmt', '#return #rvalue?')                     .mx('ult=return ti=return')
        
      '''#'
      if ret.hash.closure
        ret.gram_list.push '''
        q('rvalue', '( #fn_decl_arg_list? ) : #type =>').mx("priority=#{base_priority} ult=cl_decl")
        q('rvalue', '( #fn_decl_arg_list? ) : #type => #block').mx("priority=#{base_priority} ult=cl_decl eol=1")
        q('rvalue', '( #fn_decl_arg_list? ) : #type => #rvalue').mx("priority=#{base_priority} ult=cl_decl")
        
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