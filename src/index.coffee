_              = require 'lodash'
fs             = require 'fs'
path           = require 'path'
Runner         = require './runner'
OctobluRaven   = require 'octoblu-raven'
{EventEmitter} = require 'events'

SENTRY_DSN = process.env.SENTRY_DSN
SENTRY_DSN ?= 'https://3b31e8586a854297a44da9770d84e7e0@app.getsentry.com/88235'

class MeshbluConnectorRunner extends EventEmitter
  constructor: ({ @connectorPath, @meshbluConfig, @logger }={}) ->
    throw new Error 'MeshbluConnectorRunner requires connectorPath' unless @connectorPath?
    throw new Error 'MeshbluConnectorRunner requires meshbluConfig' unless @meshbluConfig?
    throw new Error 'MeshbluConnectorRunner requires logger' unless @logger?

  run: =>
    throw new Error('Invalid state: ', @errors()) unless @isValid()
    @setupRaven()
    @runner = new Runner {@connectorPath, @meshbluConfig, @logger}
    @runner.on 'error', (error) =>
      console.error "Runner error:", error.stack
      console.log "Fatal error, exiting."
      process.exit 1
    @runner.run()

  setupRaven: =>
    { version, name } = @getPackageJSON()
    { uuid } = @meshbluConfig
    octobluRaven = new OctobluRaven { name, release: "v#{version}", dsn: SENTRY_DSN }
    octobluRaven.patchGlobal()
    octobluRaven.setUserContext({ uuid })

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
