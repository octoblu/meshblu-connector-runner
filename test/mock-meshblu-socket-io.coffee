http = require 'http'
SocketIO = require 'socket.io'
portfinder = require 'portfinder'

class MockMeshbluSocketIO
  constructor: (options) ->
    {@onConnection} = options

  start: (callback) =>
    portfinder.getPort (error, @port) =>
      return callback error if error?
      @server = http.createServer()
      @server.on 'request', (request, response, next) =>
        response.end('OK')
      @io = SocketIO()
      @io.attach @server
      @io.on 'connection', @onConnection
      @server.listen @port, callback

  when: (event, data) =>
    @io.on event, => return data

  stop: (callback) =>
    @server.close callback

module.exports = MockMeshbluSocketIO
