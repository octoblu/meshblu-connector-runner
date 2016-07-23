_       = require 'lodash'
meshblu = require 'meshblu'
debug   = require('debug')('meshblu-connector-runner:status-device')

class StatusDevice
  constructor: ({ @meshbluConfig, meshblu, device, @checkOnline }) ->
    @connectorDevice = device
    @connectorMeshblu = meshblu
    @tag = "connector-#{@meshbluConfig.uuid}-status-device"
    @update = _.debounce @_update, 1000, { leading: true }

  close: (callback) =>
    @statusMeshblu.close callback

  _create: (callback) =>
    debug 'creating status device'
    { uuid } = @meshbluConfig
    device =
      type: 'connector-status-device'
      owner: uuid
      discoverWhitelist: [ uuid, @connectorDevice.owner ]
      configureWhitelist: [ uuid, @connectorDevice.owner ]
      sendWhitelist: [ uuid, @connectorDevice.owner ]
      receiveWhitelist: [ uuid, @connectorDevice.owner ]

    @connectorMeshblu.register device, (device={}) =>
      return callback device.error if device.error?
      @connectorMeshblu.update { uuid, statusDevice: device.uuid }, (response={}) =>
        return callback response.error if response.error?
        @device = device
        @_connect callback

  _connect: (_callback) =>
    callback = _.once _callback
    meshbluConfig = _.cloneDeep @meshbluConfig
    meshbluConfig.uuid = @device.uuid
    meshbluConfig.token = @device.token
    @statusMeshblu = meshblu.createConnection meshbluConfig
    @statusMeshblu.once 'ready', =>
      debug 'status device is ready'
      callback()

    @statusMeshblu.on 'error', (error) =>
      console.error 'status device error', error
      callback error

    @statusMeshblu.on 'notReady', (error) =>
      console.error 'status device notReady', error
      callback error

    @statusMeshblu.on 'message', (message={}) =>
      return if message.topic != 'ping'
      debug 'on ping'
      @checkOnline (error, response) =>
        @update({ error, response })

  _generateToken: (uuid, callback) =>
    debug 'generating token for status device'
    @connectorMeshblu.revokeTokenByQuery { uuid, @tag }, (response={}) =>
      return callback response.error if response.error?
      @connectorMeshblu.generateAndStoreToken { uuid, @tag }, (device={}) =>
        return callback device.error if device.error?
        @device = device
        @_connect callback

  start: (callback) =>
    return @_generateToken @connectorDevice.statusDevice, callback if @connectorDevice.statusDevice?
    @_create callback

  _update: ({ response, error }) =>
    date = Date.now()
    message = {
      devices: ['*']
      topic: 'pong'
      date
      response
      error
    }

    debug 'sending pong', message
    @statusMeshblu.message message
    { uuid } = @device
    @statusMeshblu.update { uuid, lastPong: { response, error, date } }

module.exports = StatusDevice
