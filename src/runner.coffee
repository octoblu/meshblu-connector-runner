_               = require 'lodash'
path            = require 'path'
async           = require 'async'
MeshbluSocketIO = require 'meshblu'
StatusDevice    = require './status-device'
MessageHandler  = require './message-handler'
{EventEmitter}  = require 'events'

class Runner extends EventEmitter
  constructor: ({ meshbluConfig, @connectorPath, @logger }={}) ->
    throw new Error 'Missing required parameter: meshbluConfig' unless meshbluConfig?
    throw new Error 'Missing required parameter: connectorPath' unless @connectorPath?
    throw new Error 'Missing required parameter: logger' unless @logger
    @logger.debug 'connectorPath', @connectorPath

    @meshbluConfig            = _.cloneDeep meshbluConfig
    @meshbluConfig.options   ?= reconnectionAttempts: 20
    @failedConnectionAttempts = 0

    @Connector = require @connectorPath
    connectorPackageJSONPath = path.join @connectorPath, 'package.json'
    try @ConnectorPackageJSON = require connectorPackageJSONPath
    @checkOnline = _.throttle @_checkOnline, 1000, { leading: true, trailing: false }

  boot: (device, callback) =>
    @stopped = @_getStoppedState device

    @logger.debug 'booting up connector', uuid: device.uuid
    @connector = new @Connector {@logger}
    @connector.start ?= (device, callback) => callback()
    @connector.on? 'error', (error) =>
      return unless error?
      @logger.error 'connector emitted error', error
      @statusDevice.logError {error}

    @connector.on? 'message', (message) =>
      return if @stopped

      @logger.debug 'sending message', message
      @meshblu.message message, (error) =>
        @logger.error error, 'on message' if error?

    @connector.on? 'update', (properties) =>
      return if @stopped

      @logger.debug 'sending update', properties
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
        return @logger.debug '@meshblu.on "message" ignored cause stopped' if @stopped

        @logger.debug '@meshblu.on "message"'
        fromUuid  = _.get message, 'fromUuid'
        respondTo = _.get message, 'metadata.respondTo'
        @messageHandler.onMessage message, (error, response) =>
          @_onError error if error?
          @_handleMessageHandlerResponse {fromUuid, respondTo, error, response}

      @meshblu.on 'config', (device) =>
        @logger.debug '@meshblu.on "config"'
        @_exitIfStoppedChanged device
        return @logger.debug '@meshblu.on "config" ignored cause stopped' if @stopped
        @connector.onConfig? device, (error) =>
          return @_onError error if error?

      callback()

  _checkOnline: (callback) =>
    @logger.debug 'checking online'
    return unless @connector?
    return callback null, running: true unless @connector.isOnline?
    @connector.isOnline callback

  close: (callback=_.noop) =>
    @logger.debug 'closing'
    @stopped = true
    tasks = [
      @_closeConnector
      @_closeMeshblu
      @_closeStatusDevice
    ]
    async.series tasks, callback

  _closeConnector: (callback) =>
    @logger.debug 'close connector'
    return callback() unless @connector?
    @connector.close callback

  _closeMeshblu: (callback) =>
    @logger.debug 'close meshblu'
    return callback() unless @connector?
    return callback() unless @meshblu?
    @meshblu.close callback

  _closeStatusDevice: (callback) =>
    @logger.debug 'close statusDevice'
    return callback() unless @statusDevice
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
      return @meshblu.message {devices, metadata, topic: 'error'}, =>

    unless _.isEmpty response
      {data, metadata} = response
      if respondTo?
        metadata ?= {}
        metadata.to = respondTo
      @meshblu.message {devices, data, metadata, topic: 'response'}, =>

  _handleNotReady: (error) =>
    @failedConnectionAttempts++ if error?.status == 504
    if @failedConnectionAttempts < 20
      return @emit 'notReady', error
    else
      error = new Error 'Exceeded number of reconnect attempts for meshblu'
      @emit 'error', error

  _onError: (error, callback) =>
    @logger.error '_onError', { error }
    @statusDevice.logError { error }
    return unless _.isFunction callback
    return callback error

  run: (_callback=_.noop) =>
    @logger.debug 'running...'
    callback = _.once _callback
    @meshblu = new MeshbluSocketIO @meshbluConfig

    @meshblu.on 'error', @_handleError

    @meshblu.on 'notReady', (error) =>
      @logger.warn 'meshblu notReady', error
      @_handleNotReady error

    @meshblu.once 'ready', =>
      @failedConnectionAttempts = 0
      @meshblu.update uuid: @meshbluConfig.uuid, 'connectorMetadata.currentVersion': @ConnectorPackageJSON.version, =>
      @whoami (error, device) =>
        return @emit 'error', error if error?
        @statusDevice = new StatusDevice { @meshbluConfig, @meshblu, device, @checkOnline, @logger }
        @statusDevice.start (error) =>
          return @emit 'error', error if error?
          @boot device, callback

    @meshblu.connect()

  whoami: (callback) =>
    @logger.debug 'whoami'
    @meshblu.whoami (device) =>
      callback null, device

  _handleError: (error) =>
    @logger.error error
    @emit 'error', error

module.exports = Runner
