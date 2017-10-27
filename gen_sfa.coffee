#!/usr/bin/env iced
### !pragma coverage-skip-block ###
require 'fy'
fs = require 'fs'

mod = require('meta_block_gen')()

col = new mod.Block_blueprint_collection
require('meta_block_gen/file_gen')(col)

require('./src/tok')(col)
require('./src/gram')(col)
# ###################################################################################################
#    tok
# ###################################################################################################
main = col.gen 'tok_main'

main.inject ()->
  col.gen 'tok_space_scope'
  col.gen 'tok_id'
  col.gen 'tok_bin_op'
  col.gen 'tok_un_op'
  col.gen 'tok_int_family'
  col.gen 'tok_var_decl'

main.hash.dedent_fix    = false
main.hash.remove_end_eol= false
main.hash.empty_fix     = false

main.compile()
fs.writeFileSync "tok.gen.coffee", main.hash.cont

# ###################################################################################################
#    gram
# ###################################################################################################
main = col.gen 'gram_main'

main.inject ()->
  col.gen 'gram_space_scope'
  col.gen 'gram_id'
  col.gen 'gram_bin_op'
  col.gen 'gram_pre_op'
  col.gen 'gram_post_op'
  col.gen 'gram_stmt'
  col.gen 'gram_int_family'
  col.gen 'gram_var_decl'

main.compile()
fs.writeFileSync "gram.gen.coffee", main.hash.cont