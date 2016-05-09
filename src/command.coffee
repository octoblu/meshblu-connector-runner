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

    meshbluConnectorRunner = new MeshbluConnectorRunner {connectorPath, meshbluConfig}
    return @_dieWithErrors meshbluConnectorRunner.errors() unless meshbluConnectorRunner.isValid()
    meshbluConnectorRunner.run()

  _dieWithErrors: (errors) =>
    console.error 'ERROR:'
    _.each errors, (error) =>
      console.error error.message
    process.exit 1

  _getConnectorPath: =>
    return process.cwd() unless _.last @args
    connectorPath = _.last @argv
    return path.resolve connectorPath

module.exports = Command
