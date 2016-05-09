_             = require 'lodash'
fs            = require 'fs'
path          = require 'path'
Runner        = require './runner'
{EventEmitter} = require 'events'

class MeshbluConnectorRunner extends EventEmitter
  constructor: ({@connectorPath, @meshbluConfig}={}) ->

  run: =>
    throw new Error('Invalid state: ', @errors()) unless @isValid()
    runner = new Runner {@connectorPath, @meshbluConfig}
    runner.run()

  errors: =>
    errors = []
    errors.push new Error 'Invalid connector, missing package.json' unless @isValidConnector()
    errors.push new Error 'Invalid meshbluConfig' unless @isValidMeshbluConfig()
    return errors

  isValid: =>
    _.isEmpty @errors()

  isValidConnector: ()=>
    packageJSONPath = path.join @connectorPath, 'package.json'
    return fs.existsSync packageJSONPath

  isValidMeshbluConfig: =>
    {uuid, token} = @meshbluConfig
    return uuid? && token?

module.exports = MeshbluConnectorRunner
