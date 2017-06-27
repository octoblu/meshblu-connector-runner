path = require 'path'
debug = require('debug')('meshblu-connector-runner')

class Logger
  constructor: ({ @connectorPath, @logType }) ->
    return @_createConsoleLogger() if @logType == 'console'
    return @_createLogger()

  _createConsoleLogger: =>
     return {
      trace: console.info,
      debug: debug,
      info: console.log,
      warn: console.log,
      error: console.error,
      fatal: console.error,
    }

  _createBunyanLogger: =>
    bunyan = require 'bunyan'
    return bunyan.createLogger
      name: path.basename(@connectorPath),
      streams: [
        {
          level: 'error'
          type: 'rotating-file'
          path: path.join(@connectorPath, 'log', 'meshblu-connector-runner-error.log')
          period: '1d'
          count: 3
        }
      ]

  _createLogger: =>
    try
      return @_createBunyanLogger()
    return @_createConsoleLogger()

module.exports = Logger
