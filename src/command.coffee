bunyan                 = require 'bunyan'
dashdash               = require 'dashdash'
_                      = require 'lodash'
fs                     = require 'fs-extra'
path                   = require 'path'
MeshbluConfig          = require 'meshblu-config'
MeshbluConnectorRunner = require './index'
isRunning              = require 'is-running'

class Command
  constructor: ({argv}) ->
    @args = dashdash.parse({argv: argv, options: []})

  panic: (error)=>
    @logger?.fatal error
    console.error error.stack
    process.exit 1

  run: =>
    connectorPath = @_getConnectorPath()
    meshbluConfig = new MeshbluConfig().toJSON()
    @parentPid = @_getParentPid()

    fs.mkdirsSync path.join(connectorPath, 'log')

    @logger = bunyan.createLogger
      name: path.basename(connectorPath),
      streams: [
        {
          level: 'error'
          type: 'rotating-file'
          path: path.join(connectorPath, 'log', 'meshblu-connector-runner-error.log')
          period: '1d'
          count: 3
        }
      ]

    process.stdout.on 'error', (error) =>
    process.stderr.on 'error', (error) =>
    setInterval(@_verifyParentPid, 30000) if @parentPid?

    meshbluConnectorRunner = new MeshbluConnectorRunner {connectorPath, meshbluConfig, @logger}
    return @_dieWithErrors meshbluConnectorRunner.errors() unless meshbluConnectorRunner.isValid()
    meshbluConnectorRunner.on 'error', (error) => @_dieWithErrors [error]
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

  _getParentPid: =>
    try
      data = JSON.parse fs.readFileSync './update.json'
    catch error
      return # ignore error

    return unless data?
    return data.Pid ? data.pid

  _verifyParentPid: =>
    pid = @_getParentPid()
    unless pid?
      return @panic new Error 'update.json is not readable, assuming parent process is no longer running'
    if pid != @parentPid
      return @panic new Error 'Parent process changed'
    unless isRunning(pid)
      return @panic new Error 'Parent process is no longer running'

module.exports = Command
