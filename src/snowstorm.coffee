# snowstorm formatter

a = require '../lib/ascent-0.0.1'

class Options
  constructor: ->
    @braces =
      wrapping:
        beforeLeft: yes
        afterLeft: yes
        beforeRight: yes
        afterRight: yes

class ModifierFlake
  constructor: (@modifiers) ->
  compile: (options) ->
    @modifiers.join(' ') + ' '

class ClassFlake
  constructor: (node) ->
    @name = node.name
    @modifiers = new ModifierFlake node.modifiers

  compile: (options) ->
    result = @modifiers.compile()
    result += "class #{@name}"
    result += "\n" if options.braces.wrapping.beforeLeft
    result += "{"
    result += "\n" if options.braces.wrapping.afterLeft
    result += "\n" if options.braces.wrapping.beforeRight
    result += "}"
    result += "\n" if options.braces.wrapping.afterRight

class Snowstorm
  constructor: ->
    @options = new Options
  format: (input) ->
    ast = a.parse input
    flake = new ClassFlake ast
    flake.compile(@options)

module.exports = new Snowstorm()
