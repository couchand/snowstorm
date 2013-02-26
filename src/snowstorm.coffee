# snowstorm formatter

a = require '../lib/ascent-0.0.1'

class ModifierFlake
  constructor: (@modifiers) ->
  compile: ->
    @modifiers.join(' ') + ' '

class ClassFlake
  constructor: (node) ->
    @name = node.name
    @modifiers = new ModifierFlake node.modifiers

  compile: ->
    @modifiers.compile() +
    "class #{@name}" +
    "\n{\n}\n"

class Snowstorm
  constructor: ->
  format: (input) ->
    ast = a.parse input
    flake = new ClassFlake ast
    flake.compile()

module.exports = new Snowstorm()
