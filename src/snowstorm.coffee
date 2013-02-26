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
    @indent =
      size:
        general: 4
        leading: 0
      character: ' '
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

getIndentChar = (options, num) ->
  tabs = ''
  for i in [0...num]
    for j in [0...options.indent.size.general]
      tabs += options.indent.character
  tabs

indent = (txt, options, num=1) ->
  return '' if txt is ''
  tabs = getIndentChar options, num
  tabs + txt.replace /\n/g, "\n#{tabs}"

class ModifierFlake
  constructor: (@modifiers) ->
  compile: (options) ->
    return '' unless @modifiers
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

class TypeFlake
  constructor: (node) ->
    @type = node

  compile: (options) ->
    type = @type
    if options.types.capitalize
      type = (capitalize t for t in @type.split '.').join '.'
    type

class ParameterFlake
  constructor: (node) ->
    @name = node.name
    @type = new TypeFlake node.type

  compile: (options) ->
    "#{@type.compile options} #{@name}"

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

class DeclarationFlake
  constructor: (node) ->
    @name = node.name
    @type = new TypeFlake node.type

  compile: (options) ->
    result = "#{@type.compile options} #{@name}"
    result += ';'

statementFactory = (node) ->
  switch node.statement
    when 'declaration'
      new DeclarationFlake node
    else
      throw new Error "unknown statement type #{node.statement} at line #{node.position.first_line}"

class MethodFlake
  constructor: (node) ->
    @name = node.name
    @type = new TypeFlake node.type
    @body = (statementFactory statement for statement in node.body)
    @modifiers = new ModifierFlake node.modifiers
    @parameters = new ParametersFlake node.parameters

  compile: (options) ->
    statements = (statement.compile options for statement in @body).join '\n'
    statements = indent statements, options

    result = @modifiers.compile(options)
    result += "#{@type.compile options} #{@name}"
    result += @parameters.compile(options)
    result += "\n" if options.braces.wrapping.beforeLeft
    result += "{"
    result += "\n" if options.braces.wrapping.afterLeft
    result += statements
    result += "\n" if options.braces.wrapping.beforeRight
    result += "}"
    result += "\n" if options.braces.wrapping.afterRight
    result

class AccessorFlake
  constructor: (node) ->
    @accessor = node.accessor
    @body = (statementFactory statement for statement in node.body) if node.body
    @modifiers = new ModifierFlake node.modifiers

  compile: (options) ->
    result = @modifiers.compile options
    result += @accessor
    unless @body
      result += ';'
    else
      statements = (statement.compile options for statement in @body).join '\n'
      statements = indent statements, options

      result += "\n" if options.braces.wrapping.beforeLeft
      result += "{"
      result += "\n" if options.braces.wrapping.afterLeft
      result += statements
      result += "\n" if options.braces.wrapping.beforeRight
      result += "}"
      result += "\n" if options.braces.wrapping.afterRight

class PropertyFlake
  constructor: (node) ->
    @name = node.name
    @type = new TypeFlake node.type
    @modifiers = new ModifierFlake node.modifiers
    @get = new AccessorFlake node.get if node.get
    @set = new AccessorFlake node.set if node.set

  compileAccessors: (options) ->
    all = []
    all.push @get.compile options if @get
    all.push @set.compile options if @set
    return indent all.join('\n'), options

  compile: (options) ->
    result = @modifiers.compile(options)
    result += "#{@type.compile options} #{@name}"
    if @get or @set
      result += "\n" if options.braces.wrapping.beforeLeft
      result += "{"
      result += "\n" if options.braces.wrapping.afterLeft
      result += @compileAccessors options
      result += "\n" if options.braces.wrapping.beforeRight
      result += "}"
      result += "\n" if options.braces.wrapping.afterRight
    else
      result += @initializer.compile(options) if @initializer
      result += ';'

classMember = (node) ->
  switch (node.member)
    when 'method'
      new MethodFlake node
    when 'property'
      new PropertyFlake node
    when 'inner_class'
      new ClassFlake node
    else
      throw new Error "unknown class member type #{node.member} at line #{node.position.first_line}"

class ClassFlake
  constructor: (node) ->
    @name = node.name
    @modifiers = new ModifierFlake node.modifiers
    @body = (classMember member for member in node.body)

  compile: (options) ->
    class_members = (member.compile options for member in @body).join '\n'
    class_members = indent class_members, options

    result = @modifiers.compile(options)
    result += "class #{@name}"
    result += "\n" if options.braces.wrapping.beforeLeft
    result += "{"
    result += "\n" if options.braces.wrapping.afterLeft
    result += class_members
    result += "\n" if options.braces.wrapping.beforeRight
    result += "}"
    result += "\n" if options.braces.wrapping.afterRight

    result = indent result, options if options.indent.size.leading
    result

class Snowstorm
  constructor: ->
    @options = new Options
  format: (input) ->
    ast = a.parse input
    flake = new ClassFlake ast
    flake.compile(@options)

module.exports = new Snowstorm()
