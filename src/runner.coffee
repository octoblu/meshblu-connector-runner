debug         = require('debug')('meshblu-connector-runner:runner')
_             = require 'lodash'
meshblu       = require 'meshblu'

class Runner
  constructor: ({@meshbluConfig, connectorPath}) ->
    debug 'connectorPath', connectorPath
    @Connector = require connectorPath
    @stopped = false
    @checkOnline = _.debounce @_checkOnline, 1000, { leading: true }
    @sendPong = _.debounce @_sendPong, 1000, { leading: true }

  boot: (device) =>
    debug 'booting up connector', uuid: device.uuid
    @connector = new @Connector()

    @connector.on 'message', (message) =>
      debug 'sending message', message
      @conn.emit 'message', message

    @connector.on 'update', (properties) =>
      debug 'sending update', properties
      {uuid, token} = @meshbluConfig
      properties = _.extend {uuid, token}, properties
      @conn.update properties

    @connector.start device

    @conn.on 'message', (message) =>
      debug 'on message', message
      return if message.topic == 'pong'
      return @checkOnline() if message.topic == 'ping'
      @connector.onMessage message

    @conn.on 'config', (device) =>
      debug 'on config'
      @closeIfNeeded device, =>
        @connector.onConfig device

  _checkOnline: =>
    debug 'checking online'
    return unless @connector?
    return @sendPong({ response: running: true }) unless @connector.isOnline?
    @connector.isOnline (error, response) =>
      @sendPong { error, response }

  close: =>
    debug 'closing'
    return unless @connector?
    @connector.close =>
      debug 'closed'
      @connector = null

  closeIfNeeded: (device, callback) =>
    debug 'close if needed', device.stopped, @stopped
    return callback() if device.stopped == @stopped
    @stopped = false unless device.stopped?
    @stopped = device.stopped if device.stopped?
    debug 'is stopped', @stopped
    return callback() unless @stopped
    @close()

  run: =>
    debug 'running...'
    @conn = meshblu.createConnection @meshbluConfig

    @conn.once 'ready', =>
      debug 'on ready'
      @whoami (error, device) =>
        @boot device

    @conn.on 'notReady', (error) =>
      console.error 'Meshblu fired notReady', error

  _sendPong: ({ error, response })=>
    debug 'send pong'
    date = Date.now()
    message =
      devices: ['*']
      topic: 'pong'
      date: date
      response: response
      error: error

    @conn.emit 'message', message
    { uuid } = @meshbluConfig

    debug 'sending pong', message
    @conn.update { uuid, lastPong: { response, error, date } }

  whoami: (callback) =>
    debug 'whoami'
    @conn.whoami {}, (device) =>
      @closeIfNeeded device, =>
        callback null, device

module.exports = Runner
