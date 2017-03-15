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

    connectorPath = @_getConnectorPath()
    meshbluConfig = new MeshbluConfig().toJSON()

    fs.mkdirsSync path.join(connectorPath, 'log')

    @parentPid = @_getParentPid()
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

    @meshbluConnectorRunner = new MeshbluConnectorRunner {connectorPath, meshbluConfig, @logger}
    return @_dieWithErrors @meshbluConnectorRunner.errors() unless @meshbluConnectorRunner.isValid()
    @meshbluConnectorRunner.on 'error', (error) => @_dieWithErrors [error]


  panic: (error)=>
    @logger?.fatal error
    console.error error.stack
    process.exit 1

  run: =>
    process.stdout.on 'error', (error) => @logger.error error.message
    process.stderr.on 'error', (error) => @logger.error error.message
    process.on 'SIGINT', @stop
    process.on 'SIGTERM', @stop

    setInterval(@_verifyParentPid, 30000) if @parentPid?
    @meshbluConnectorRunner.run()

  stop: =>
    @meshbluConnectorRunner.stop (error) =>
      return @panic error if error?
      process.exit 0

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
    catch
      return # ignore error

    return unless data?
    return data.Pid ? data.pid

  _verifyParentPid: =>
    pid = @_getParentPid()
    return if pid? && pid == @parentPid && isRunning(pid)

    @meshbluConnectorRunner.stop (error) =>
      @logger.error error, 'Error on meshbluConnectorRunner.stop' if error?

      unless pid?
        return @panic new Error 'update.json is not readable, assuming parent process is no longer running'
      if pid != @parentPid
        return @panic new Error 'Parent process changed'
      unless isRunning(pid)
        return @panic new Error 'Parent process is no longer running'

module.exports = Command
