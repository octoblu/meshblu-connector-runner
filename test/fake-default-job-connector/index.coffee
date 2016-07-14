{EventEmitter} = require 'events'

class FakeConnector extends EventEmitter
  start: (device, callback) =>
    callback()

  close: (callback) =>
    callback()

  onMessage: =>

  onConfig: =>

module.exports = FakeConnector
