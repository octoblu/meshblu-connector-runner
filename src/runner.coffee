_              = require 'lodash'
path           = require 'path'
async          = require 'async'
meshblu        = require 'meshblu'
StatusDevice   = require './status-device'
MessageHandler = require './message-handler'
debug          = require('debug')('meshblu-connector-runner:runner')

class Runner
  constructor: ({ @meshbluConfig, @connectorPath }={}) ->
    throw 'Runner requires meshbluConfig' unless @meshbluConfig?
    throw 'Runner requires connectorPath' unless @connectorPath?
    debug 'connectorPath', @connectorPath
    @Connector = require @connectorPath
    connectorPackageJSONPath = path.join @connectorPath, 'package.json'
    try @ConnectorPackageJSON = require connectorPackageJSONPath
    @checkOnline = _.throttle @_checkOnline, 1000, { leading: true, trailing: false }

  boot: (device, callback) =>
    debug 'booting up connector', uuid: device.uuid
    @connector = new @Connector
    @connector.start ?= (device, callback) => callback()
    @connector.start device, (error) =>
      return callback error if error?

      @messageHandler = new MessageHandler {
        @connector
        @connectorPath
        defaultJobType: @ConnectorPackageJSON?.connector?.defaultJobType
      }

      @connector.on? 'message', (message) =>
        debug 'sending message', message
        @meshblu.message message

      @connector.on? 'update', (properties) =>
        debug 'sending update', properties
        {uuid, token} = @meshbluConfig
        properties = _.extend {uuid, token}, properties
        @meshblu.update properties

      @meshblu.on 'message', (message) =>
        debug 'on message', message
        {metadata, fromUuid} = message
        {respondTo} = metadata ? {}
        @messageHandler.onMessage message, (error, response) =>
          @_handleMessageHandlerResponse {fromUuid, respondTo, error, response}

      @meshblu.on 'config', (device) =>
        debug 'on config'
        @connector.onConfig? device

      callback()

  _checkOnline: (callback) =>
    debug 'checking online'
    return unless @connector?
    return callback null, running: true unless @connector.isOnline?
    @connector.isOnline callback

  close: (callback=_.noop) =>
    debug 'closing'
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
      metadata.to = respondTo if respondTo?
      @meshblu.message {devices, data, metadata, topic: 'response'}

  run: (_callback=_.noop) =>
    debug 'running...'
    callback = _.once _callback
    @meshblu = meshblu.createConnection @meshbluConfig

    @meshblu.once 'ready', =>
      @whoami (error, device) =>
        throw error if error?
        @statusDevice = new StatusDevice { @meshbluConfig, @meshblu, device, @checkOnline }
        @statusDevice.start (error) =>
          throw error if error?
          @boot device, callback

    @meshblu.on 'error', (error) =>
      console.error 'meshblu error', error
      callback error

    @meshblu.on 'notReady', (error) =>
      console.error 'message not ready', error
      callback error

  whoami: (callback) =>
    debug 'whoami'
    @meshblu.whoami {}, (device) =>
      callback null, device

module.exports = Runner
