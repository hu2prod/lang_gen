assert = require 'assert'
require 'shelljs/global'

describe 'index section', ()->
  _tokenize = null
  _parse = null
  tokenize = null
  parse = null
  run = (str)->
    tok = _tokenize str
    ast = _parse tok
  
  it 'gen_sfa', ()->
    require '../gen_sfa.coffee'
    {_tokenize, tokenize} = require('../tok.gen.coffee')
    {_parse, parse}    = require('../gram.gen.coffee')
  
  it 'interface test', (done)->
    await tokenize str, {}, defer err, tok; throw err if err
    await parse tok, {}, defer err, ret; throw err if err
    done()
  
  describe 'throws', ()->
    it 'tokenize', (done)->
      await tokenize 'wtf кирилица', {}, defer err, tok;
      assert !!err
      done()
    
    it 'parse', (done)->
      await tokenize 'a+', {}, defer err, tok;
      await parse tok, {}, defer err, res;
      assert !!err
      done()
  
  str_list = """
    a
    +a
    a+b
    """.split /\n/g
  for str in str_list
    do (str)->
      it "parses '#{str}'", ()->
        run str
  
  # TODO other test (extended sfa)
  
  # requires scope
  # str_list = """
  #   ---
  #   
  #   ---
  #   
  #   
  #   """.split /\n*---\n*/g
  # for str in str_list
  #   do (str)->
  #     it "parses '#{JSON.stringify str}'", ()->
  #       run str
  # 
  # it 'test finish', ()->
    # rm '*gen.coffee'
  