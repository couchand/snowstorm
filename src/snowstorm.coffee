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
      for mod in @modifiers
        anns.push annotation if annExp.test mod.annotation
    for modifier in options.modifiers.order
      modExp = new RegExp "^#{modifier}$", 'i'
      for mod in @modifiers
        mods.push modifier if modExp.test mod
    result = ""
    if anns.length
      result += anns.join ' '
      result += "\n" if options.modifiers.wrapping.afterAnnotations
    if mods.length
      result += mods.join ' '
    result += ' '

class ClassFlake
  constructor: (node) ->
    @name = node.name
    @modifiers = new ModifierFlake node.modifiers

  compile: (options) ->
    result = @modifiers.compile(options)
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
