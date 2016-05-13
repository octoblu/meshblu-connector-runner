_             = require 'lodash'
meshblu       = require 'meshblu'
debug         = require('debug')('meshblu-connector-runner:runner')

class Runner
  constructor: ({ @meshbluConfig, connectorPath }) ->
    debug 'connectorPath', connectorPath
    @Connector = require connectorPath
    @checkOnline = _.debounce @_checkOnline, 1000, { leading: true }
    @sendPong = _.debounce @_sendPong, 1000, { leading: true }

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
      return if message.topic == 'pong'
      return @checkOnline() if message.topic == 'ping'
      @connector.onMessage? message

    @meshblu.on 'config', (device) =>
      debug 'on config'
      @connector.onConfig? device

  _checkOnline: =>
    debug 'checking online'
    return unless @connector?
    return @sendPong({ response: running: true }) unless @connector.isOnline?
    @connector.isOnline (error, response) =>
      @sendPong { error, response }

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
        @boot device

    @meshblu.on 'error', (error) =>
      console.error 'meshblu error', error

    @meshblu.on 'notReady', (error) =>
      console.error 'message not ready', error

  _sendPong: ({ error, response })=>
    debug 'send pong'
    date = Date.now()
    message =
      devices: ['*']
      topic: 'pong'
      date: date
      response: response
      error: error

    @meshblu.message message
    { uuid } = @meshbluConfig

    debug 'sending pong', message
    @meshblu.update { uuid, lastPong: { response, error, date } }

  whoami: (callback) =>
    debug 'whoami'
    @meshblu.whoami {}, (device) =>
      callback null, device

module.exports = Runner
