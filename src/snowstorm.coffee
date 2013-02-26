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
    @parens =
      space:
        before:
          methodCall: no
          methodDeclaration: no
          statement: yes
        within:
          methodCall: yes
          methodDeclaration: yes
          statement: yes
    @commas =
      space:
        after:
          methodCall: yes
          methodDeclaration: yes
          assignment: yes
          collectionInitializer: yes
    @types =
      capitalize: yes
    @modifiers =
      wrapping:
        afterAnnotations: yes
      order: [
        'public', 'private', 'protected', 'global'
        'static', 'abstract', 'virtual', 'override'
        'transient', 'final', 'testMethod'
        'with sharing', 'without sharing'
      ]
      annotations: [
        '@isTest', '@future', '@deprecated', '@ReadOnly'
#        '@isTest(SeeAllData=)', "@RestResource(urlMapping='/myResource')"
      ]

class ModifierFlake
  constructor: (@modifiers) ->
  compile: (options) ->
    anns = []
    mods = []
    for annotation in options.modifiers.annotations
      annExp = new RegExp "^#{annotation}$", 'i'
      for mod in @modifiers when annExp.test mod.annotation
        anns.push annotation
        continue
    for modifier in options.modifiers.order
      modExp = new RegExp "^#{modifier}$", 'i'
      for mod in @modifiers when modExp.test mod
        mods.push modifier
        continue
    result = ""
    if anns.length
      result += anns.join ' '
      result += "\n" if options.modifiers.wrapping.afterAnnotations
    if mods.length
      result += mods.join ' '
    result += ' '

capitalize = (str) ->
  str[0].toUpperCase() + str[1..]

class ParameterFlake
  constructor: (node) ->
    @name = node.name
    @type = node.type

  compile: (options) ->
    type = @type
    if options.types.capitalize
      type = (capitalize t for t in @type.split '.').join '.'
    "#{type} #{@name}"

class ParametersFlake
  constructor: (params) ->
    @parameters = (new ParameterFlake param for param in params)

  compile: (options) ->
    joiner = if options.commas.space.after.methodDeclaration then ', ' else ','
    result = ''
    result += ' ' if options.parens.space.before.methodDeclaration
    result += '('
    result += ' ' if options.parens.space.within.methodDeclaration && @parameters.length
    result += (param.compile options for param in @parameters).join joiner
    result += ' ' if options.parens.space.within.methodDeclaration && @parameters.length
    result += ')'

class MethodFlake
  constructor: (node) ->
    @name = node.name
    @type = node.type
    @modifiers = new ModifierFlake node.modifiers
    @parameters = new ParametersFlake node.parameters

  compile: (options) ->
    result = @modifiers.compile(options)
    result += "#{@type} #{@name}"
    result += @parameters.compile(options)
    result += "\n" if options.braces.wrapping.beforeLeft
    result += "{"
    result += "\n" if options.braces.wrapping.afterLeft
    result += "\n" if options.braces.wrapping.beforeRight
    result += "}"
    result += "\n" if options.braces.wrapping.afterRight

classMember = (node) ->
  switch (node.member)
    when 'method'
      new MethodFlake node
    else
      throw new Error "unknown class member type #{node.member} at line #{node.position.first_line}"

class ClassFlake
  constructor: (node) ->
    @name = node.name
    @modifiers = new ModifierFlake node.modifiers
    @body = (classMember member for member in node.body)

  compile: (options) ->
    result = @modifiers.compile(options)
    result += "class #{@name}"
    result += "\n" if options.braces.wrapping.beforeLeft
    result += "{"
    result += "\n" if options.braces.wrapping.afterLeft
    result += (member.compile options for member in @body).join '\n'
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
