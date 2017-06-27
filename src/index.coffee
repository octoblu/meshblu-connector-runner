_              = require 'lodash'
fs             = require 'fs'
path           = require 'path'
Runner         = require './runner'
{EventEmitter} = require 'events'
Logger         = require './logger'

class MeshbluConnectorRunner extends EventEmitter
  constructor: ({ @connectorPath, @meshbluConfig, @logger, logType }={}) ->
    throw new Error 'MeshbluConnectorRunner requires connectorPath' unless @connectorPath?
    throw new Error 'MeshbluConnectorRunner requires meshbluConfig' unless @meshbluConfig?
    @logger ?= new Logger { @connectorPath, logType }

  run: =>
    throw new Error('Invalid state: ', @errors()) unless @isValid()
    @runner = new Runner {@connectorPath, @meshbluConfig, @logger}
    @runner.on 'error', (error) =>
      console.error "Runner error:", error.stack
      console.log "Fatal error, exiting."
      process.exit 1
    @runner.run()

  stop: (callback) =>
    return unless @runner?
    @runner.close callback

  errors: =>
    errors = []
    errors.push new Error 'Invalid connector, missing package.json' unless @isValidConnector()
    errors.push new Error 'Invalid meshbluConfig' unless @isValidMeshbluConfig()
    return errors

  isValid: =>
    _.isEmpty @errors()

  getPackageJSON: =>
    packageJSONPath = path.join @connectorPath, 'package.json'
    return require packageJSONPath

  isValidConnector: =>
    packageJSONPath = path.join @connectorPath, 'package.json'
    return fs.existsSync packageJSONPath

  isValidMeshbluConfig: =>
    {uuid, token} = @meshbluConfig
    return uuid? && token?

module.exports = MeshbluConnectorRunner
