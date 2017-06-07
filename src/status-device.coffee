async           = require 'async'
_               = require 'lodash'
MeshbluSocketIO = require 'meshblu'
MeshbluHttp     = require 'meshblu-http'
moment          = require 'moment'
debug           = require('debug')('meshblu-connector-runner:status-device')

UPDATE_INTERVAL = 60 * 1000
EXPIRATION_TIMEOUT = 120 * 1000

class StatusDevice
  constructor: ({ @meshbluConfig, meshblu, device, @checkOnline, @logger }) ->
    throw new Error 'StatusDevice requires logger' unless @logger?
    @connectorDevice = device
    @connectorMeshblu = meshblu
    @tag = "connector-#{@meshbluConfig.uuid}-status-device"
    @update = _.throttle @_update, 1000, { leading: true, trailing: false }

  close: (callback) =>
    debug('close')
    clearInterval @_updateOnlineUntilInterval if @_updateOnlineUntilInterval?

    @_updateOnlineUntilToNow (error) =>
      debug('_updateOnlineUntilToNow', {error})
      return callback error if error?
      @statusMeshblu.close (error) =>
        debug('statusMeshblu.close', {error})
        return callback error if error?
        return callback()

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
      status: {}

    @connectorMeshblu.register device, (device={}) =>
      return callback device.error if device.error?
      @device = device
      @_connect callback

  _connect: (_callback) =>
    callback = _.once _callback
    meshbluConfig = _.cloneDeep @meshbluConfig
    meshbluConfig.uuid = @device.uuid
    meshbluConfig.token = @device.token
    @statusMeshblu = new MeshbluSocketIO meshbluConfig
    @statusMeshbluHttp = new MeshbluHttp meshbluConfig
    @statusMeshblu.once 'ready', =>
      debug 'status device is ready'
      @logger.debug 'status device is ready'
      callback()

    @statusMeshblu.connect()

    @statusMeshblu.on 'error', (error) =>
      console.error 'status device error', error
      @logger.error error, 'status device error'
      callback error

    @statusMeshblu.on 'notReady', (error) =>
      console.error 'status device notReady', error
      @logger.error error, 'status device notReady'
      callback error

    @statusMeshblu.on 'message', (message={}) =>
      return if message.topic != 'ping'
      debug 'on ping'
      @logger.debug message, 'on message'
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
    @_setup (error) =>
      return callback error if error?
      @_updateOnlineUntilInterval = setInterval @_updateOnlineUntil, UPDATE_INTERVAL
      @_updateOnlineUntil()
      callback()

  _copyDiscoverWhitelist: (callback) =>
    newDiscoverWhitelist = _.map _.get(@connectorDevice,  'meshblu.whitelists.discover.view', []), 'uuid'
    statusDeviceWhitelist = _.union @connectorDevice.discoverWhitelist, newDiscoverWhitelist, [@connectorDevice.uuid]
    @statusMeshblu.update uuid: @device.uuid, discoverWhitelist: statusDeviceWhitelist, () => callback()

  _findOrCreate: (callback) =>
    return @_generateToken @connectorDevice.statusDevice, callback if @connectorDevice.statusDevice?
    @_create callback

  _setup: (callback) =>
    async.series [
      @_findOrCreate
      @_updateStatusRef
      @_copyDiscoverWhitelist
    ], callback

  _update: ({ response, error }, callback=_.noop) =>
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
    @statusMeshblu.update { uuid, lastPong: { response, error, date } }, callback

  logError: ({ response, error }, callback) =>
    update =
      $push:
        errors:
          $each: [
            date: moment.utc().format()
            code: error.code ? 500
            message: error.message
          ]
          $slice: -99

    @statusMeshbluHttp.updateDangerously @device.uuid, update, (newError) =>
      console.error newError.stack if newError?
      return callback error if error?
      @update { response, error }, (error) =>
        return callback error

  _updateOnlineUntil: =>
    { uuid } = @device
    onlineUntil = moment().utc().add(EXPIRATION_TIMEOUT, 'ms')

    @statusMeshblu.update { uuid, 'status.onlineUntil': onlineUntil }, =>

  _updateOnlineUntilToNow: (callback) =>
    update = {
      uuid: @device.uuid
      'status.onlineUntil': moment()
    }

    @statusMeshblu.update update, =>
      callback()

  _updateStatusRef: (callback) =>
    update = {
      uuid:  @meshbluConfig.uuid
      statusDevice: @device.uuid
      status:
        $ref: "meshbludevice://#{@device.uuid}/#/status"
    }

    @connectorMeshblu.update update, (response={}) =>
      return callback response.error if response.error?
      callback()


module.exports = StatusDevice
