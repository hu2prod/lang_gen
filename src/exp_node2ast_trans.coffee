node2ast = require './node2ast'
type_inference = require './type_inference'

@gen = (_root, opt)->
  ast_tree = node2ast.gen _root, opt
  ast_tree = type_inference.gen ast_tree, opt
  
  ast_tree
