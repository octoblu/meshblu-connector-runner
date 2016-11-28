_              = require 'lodash'
path           = require 'path'
async          = require 'async'
meshblu        = require 'meshblu'
StatusDevice   = require './status-device'
MessageHandler = require './message-handler'
debug          = require('debug')('meshblu-connector-runner:runner')

class Runner
  constructor: ({ @meshbluConfig, @connectorPath, @logger }={}) ->
    throw new Error 'Missing required parameter: meshbluConfig' unless @meshbluConfig?
    throw new Error 'Missing required parameter: connectorPath' unless @connectorPath?
    throw new Error 'Missing required parameter: logger' unless @logger?

    debug 'connectorPath', @connectorPath
    @Connector = require @connectorPath
    connectorPackageJSONPath = path.join @connectorPath, 'package.json'
    try @ConnectorPackageJSON = require connectorPackageJSONPath
    @checkOnline = _.throttle @_checkOnline, 1000, { leading: true, trailing: false }

  boot: (device, callback) =>
    @stopped = @_getStoppedState device

    debug 'booting up connector', uuid: device.uuid
    @connector = new @Connector {@logger}
    @connector.start ?= (device, callback) => callback()
    @connector.on? 'error', (error) =>
      return unless error?
      debug 'sending error', error
      @logger.error error, 'on error'
      @statusDevice?.update {error}

    @connector.on? 'message', (message) =>
      return if @stopped

      debug 'sending message', message
      @meshblu.message message, (error) =>
        @logger?.error error, 'on message' if error?

    @connector.on? 'update', (properties) =>
      return if @stopped

      debug 'sending update', properties
      {uuid, token} = @meshbluConfig
      properties = _.extend {uuid, token}, properties
      @meshblu.update properties, (error) =>
        return @_onError error if error?

    @connector.start device, (error) =>
      return @_onError error, callback if error?

      @messageHandler = new MessageHandler {
        @connector
        @connectorPath
        @logger
        defaultJobType: @ConnectorPackageJSON?.connector?.defaultJobType
      }

      @meshblu.on 'message', (message) =>
        return debug '@meshblu.on "message" ignored cause stopped' if @stopped

        debug '@meshblu.on "message"'
        fromUuid  = _.get message, 'fromUuid'
        respondTo = _.get message, 'metadata.respondTo'
        @messageHandler.onMessage message, (error, response) =>
          @_onError error if error?
          @_handleMessageHandlerResponse {fromUuid, respondTo, error, response}

      @meshblu.on 'config', (device) =>
        debug '@meshblu.on "config"'
        @_exitIfStoppedChanged device
        return debug '@meshblu.on "config" ignored cause stopped' if @stopped
        @connector.onConfig? device, (error) =>
          return @_onError error if error?

      callback()

  _checkOnline: (callback) =>
    debug 'checking online'
    return unless @connector?
    return callback null, running: true unless @connector.isOnline?
    @connector.isOnline callback

  close: (callback=_.noop) =>
    debug 'closing'
    @stopped = true
    tasks = [
      @_closeConnector
      @_closeMeshblu
      @_closeStatusDevice
    ]
    async.series tasks, callback

  _closeConnector: (callback) =>
    debug 'close connector'
    return callback() unless @connector?
    @connector.close callback

  _closeMeshblu: (callback) =>
    debug 'close meshblu'
    return callback() unless @connector?
    return callback() unless @meshblu?
    @meshblu.close callback

  _closeStatusDevice: (callback) =>
    debug 'close statusDevice'
    return callback() unless @statusDevice?
    @statusDevice.close callback

  _getStoppedState: (device) =>
    _.get device, 'connectorMetadata.stopped', false

  _exitIfStoppedChanged: (device) =>
    stopped = @_getStoppedState device
    return if stopped == @stopped
    @close =>
      process.exit 0

  _handleMessageHandlerResponse: ({fromUuid, respondTo, error, response}) =>
    devices = [fromUuid]

    if error?
      metadata =
        code: error.code ? 500
        error: message: error.message
      metadata.to = respondTo if respondTo?
      return @meshblu.message {devices, metadata, topic: 'error'}

    unless _.isEmpty response
      {data, metadata} = response
      if respondTo?
        metadata ?= {}
        metadata.to = respondTo
      @meshblu.message {devices, data, metadata, topic: 'response'}

  _onError: (error, callback) =>
    @logger?.error error, 'connector start'
    @statusDevice?.update {error}
    return unless _.isFunction callback
    return callback error

  run: (_callback=_.noop) =>
    debug 'running...'
    callback = _.once _callback
    @meshblu = meshblu.createConnection @meshbluConfig
    @meshblu.once 'ready', =>
      @meshblu.update uuid: @meshbluConfig.uuid, 'connectorMetadata.currentVersion': @ConnectorPackageJSON.version, =>
      @whoami (error, device) =>
        throw error if error?
        @statusDevice = new StatusDevice { @meshbluConfig, @meshblu, device, @checkOnline, @logger }
        @statusDevice.start (error) =>
          throw error if error?
          @boot device, callback

    @meshblu.on 'error', (error) =>
      console.error 'meshblu error', error
      @logger.error error
      callback error

    @meshblu.on 'notReady', (error) =>
      console.error 'message not ready', error
      @logger.error error
      callback error

  whoami: (callback) =>
    debug 'whoami'
    @meshblu.whoami {}, (device) =>
      callback null, device

module.exports = Runner
