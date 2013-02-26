# snowstorm formatter

a = require '../lib/ascent-0.0.1'

class Options
  constructor: ->
    @braces =
      empty:
        collapse: yes
        cuddle: ' '     # cuddled brace separator character
      wrapping:
        before:
          block:
            start: yes
            end: yes
        after:
          block:
            start: yes
            end: yes
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
    @operators =
      space:
        around:
          assignment: yes
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

assignmentClause = (value, options) ->
  result = ''
  result += ' ' if options.operators.space.around.assignment
  result += '='
  result += ' ' if options.operators.space.around.assignment
  result += value

blockStatements = (statements, options) ->
  block_empty = statements is ''
  statements = statements.replace /\n$/, ''
  space_char = if typeof options.braces.empty.cuddle is 'string' then options.braces.empty.cuddle else ' '
  supress_initial_newline = block_empty and options.braces.empty.cuddle
  supress_interior_newlines = block_empty and options.braces.empty.collapse
  before_left = options.braces.wrapping.before.block.start and not supress_initial_newline
  after_left = options.braces.wrapping.after.block.start and not supress_interior_newlines
  before_right = options.braces.wrapping.before.block.end and not block_empty
  after_right = options.braces.wrapping.after.block.end

  result = ''
  result += space_char if supress_initial_newline
  result += "\n" if before_left
  result += "{"
  result += "\n" if after_left
  result += indent statements, options unless block_empty
  result += "\n" if before_right
  result += "}"
  result += "\n" if after_right
  result

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
    @initializer = node.initializer

  compile: (options) ->
    result = "#{@type.compile options} #{@name}"
    if @initializer
      result += assignmentClause @initializer, options
    result += ';'

class ReturnFlake
  constructor: (node) ->
    @returns = node.returns[0] if node.returns.length

  compile: (options) ->
    result = 'return'
    result += " #{@returns}" if @returns
    result += ';'

statementFactory = (node) ->
  switch node.statement
    when 'declaration'
      new DeclarationFlake node
    when 'return'
      new ReturnFlake node
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

    result = @modifiers.compile(options)
    result += "#{@type.compile options} #{@name}"
    result += @parameters.compile(options)
    result += blockStatements statements, options
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
      result += blockStatements statements, options

class PropertyFlake
  constructor: (node) ->
    @name = node.name
    @type = new TypeFlake node.type
    @modifiers = new ModifierFlake node.modifiers
    @get = new AccessorFlake node.get if node.get
    @set = new AccessorFlake node.set if node.set
    @initializer = node.initializer

  compileAccessors: (options) ->
    all = []
    all.push @get.compile options if @get
    all.push @set.compile options if @set
    return all.join '\n'

  compile: (options) ->
    result = @modifiers.compile(options)
    result += "#{@type.compile options} #{@name}"
    if @get or @set
      result += blockStatements @compileAccessors(options), options
    else
      if @initializer
        result += assignmentClause @initializer, options
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

    result = @modifiers.compile(options)
    result += "class #{@name}"
    result += blockStatements class_members, options

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
