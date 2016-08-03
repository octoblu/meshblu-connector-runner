bunyan        = require 'bunyan'
dashdash      = require 'dashdash'
_             = require 'lodash'
path          = require 'path'
MeshbluConfig = require 'meshblu-config'
MeshbluConnectorRunner = require './index'

class Command
  constructor: ({argv}) ->
    @args = dashdash.parse({argv: argv, options: []})

  panic: (error)=>
    console.error error.stack
    process.exit 1

  run: =>
    connectorPath = @_getConnectorPath()
    meshbluConfig = new MeshbluConfig().toJSON()

    @logger = bunyan.createLogger
      name: path.basename(connectorPath),
      streams: [
        {
          level: 'info'
          type: 'rotating-file'
          path: path.join(connectorPath, 'log', 'connector.log')
          period: '1d'
          count: 3
        },
        {
          level: 'warn'
          type: 'rotating-file'
          path: path.join(connectorPath, 'log', 'connector-warn.log')
          period: '1d'
          count: 3
        },
        {
          level: 'error'
          type: 'rotating-file'
          path: path.join(connectorPath, 'log', 'connector-error.log')
          period: '1d'
          count: 3
        }
      ]

    process.stdout.on 'error', (error) =>
    process.stderr.on 'error', (error) =>

    meshbluConnectorRunner = new MeshbluConnectorRunner {connectorPath, meshbluConfig, @logger}
    return @_dieWithErrors meshbluConnectorRunner.errors() unless meshbluConnectorRunner.isValid()
    meshbluConnectorRunner.run()

  _dieWithErrors: (errors) =>
    console.error 'ERROR:'
    _.each errors, (error) =>
      @logger?.fatal error
      console.error error.message
    process.exit 1

  _getConnectorPath: =>
    return process.cwd() unless _.last @args
    connectorPath = _.last @argv
    return path.resolve connectorPath

module.exports = Command
