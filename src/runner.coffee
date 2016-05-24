_             = require 'lodash'
meshblu       = require 'meshblu'
StatusDevice  = require './status-device'
debug         = require('debug')('meshblu-connector-runner:runner')

class Runner
  constructor: ({ @meshbluConfig, connectorPath }) ->
    debug 'connectorPath', connectorPath
    @Connector = require connectorPath
    @checkOnline = _.debounce @_checkOnline, 1000, { leading: true }

  boot: (device) =>
    debug 'booting up connector', uuid: device.uuid
    @connector = new @Connector()

    @connector.on? 'message', (message) =>
      debug 'sending message', message
      @meshblu.message message

    @connector.on? 'update', (properties) =>
      debug 'sending update', properties
      {uuid, token} = @meshbluConfig
      properties = _.extend {uuid, token}, properties
      @meshblu.update properties

    @connector.start? device

    @meshblu.on 'message', (message) =>
      debug 'on message', message
      @connector.onMessage? message

    @meshblu.on 'config', (device) =>
      debug 'on config'
      @connector.onConfig? device

  _checkOnline: (callback) =>
    debug 'checking online'
    return unless @connector?
    return callback null, running: true unless @connector.isOnline?
    @connector.isOnline callback

  close: =>
    debug 'closing'
    @connector?.close =>
      debug 'closed'
      @connector = null

  run: =>
    debug 'running...'
    @meshblu = meshblu.createConnection @meshbluConfig

    @meshblu.once 'ready', =>
      @whoami (error, device) =>
        @statusDevice = new StatusDevice { @meshbluConfig, @meshblu, device, @checkOnline }
        @statusDevice.start (error) =>
          throw error if error?
          @boot device

    @meshblu.on 'error', (error) =>
      console.error 'meshblu error', error

    @meshblu.on 'notReady', (error) =>
      console.error 'message not ready', error

  _sendPong: ({ error, response })=>

  whoami: (callback) =>
    debug 'whoami'
    @meshblu.whoami {}, (device) =>
      callback null, device

module.exports = Runner
