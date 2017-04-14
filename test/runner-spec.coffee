{afterEach, beforeEach, context, describe, it} = global
{expect} = require 'chai'
sinon = require 'sinon'
_ = require 'lodash'

Runner = require '../src/runner'
MockMeshbluSocketIO = require './mock-meshblu-socket-io'

describe 'Runner', ->
  beforeEach 'socket.io', (done) ->
    @whoamiHandler = sinon.stub()
    @registerHandler = sinon.stub()
    @updateHandler = sinon.stub()
    @identityHandler = sinon.spy ->
      @emit 'ready', uuid: 'some-device', token: 'some-token'

    onConnection = (@socket) =>
      @socket.on 'whoami', @whoamiHandler
      @socket.on 'register', @registerHandler
      @socket.on 'update', @updateHandler
      @socket.on 'identity', @identityHandler
      # @socket.on 'whoami', =>
      #   console.log 'whoami'
      #   @whoamiHandler.apply @socket, arguments
      # @socket.on 'register', =>
      #   console.log 'register'
      #   @registerHandler.apply @socket, arguments
      # @socket.on 'update', =>
      #   console.log 'update', arguments
      #   @updateHandler.apply @socket, arguments
      # @socket.on 'identity', =>
      #   console.log 'identity'
      #   @identityHandler.apply @socket, arguments

      @socket.emit 'identify'

    @meshblu = new MockMeshbluSocketIO port: 0xd00d, onConnection: onConnection
    @meshblu.start done

  afterEach 'socket.io', (done) ->
    done = _.once done
    setTimeout done, 500
    @meshblu.stop done

  beforeEach ->
    logger =
      info: =>
      debug: =>
      warn: =>
      error: =>

    meshbluConfig =
      uuid: 'some-uuid'
      token: 'a-token'
      protocol: 'http'
      hostname: 'localhost'
      port: @meshblu.port

    connectorPath = __dirname + '/fake-connector'

    @sut = new Runner {meshbluConfig, connectorPath, logger}

  describe '->run', ->
    beforeEach (done) ->
      @whoamiHandler.yields uuid: 'some-uuid'
      @registerHandler.yields {}
      @updateHandler.yields {}
      @sut.run done

    afterEach 'sut.close', (done) ->
      @sut.close done

    it 'should create a statusDevice', ->
      expect(@sut.statusDevice).to.exist

    it 'should update with the connector version', ->
      expect(@updateHandler).to.have.been.calledWith {
        uuid: 'some-uuid'
        'connectorMetadata.currentVersion': '2.3.1'
      }

    it 'should create a messageHandler', ->
      expect(@sut.statusDevice).to.exist

    it 'should create a connector', ->
      expect(@sut.connector).to.exist

    describe 'connector', ->
      beforeEach ->
        {@meshblu, @connector} = @sut
        @meshblu.message = sinon.stub()
        @meshblu.update = sinon.stub()

      describe 'on message', ->
        beforeEach ->
          message =
            foo: 'bar'
          @connector.emit 'message', message

        it 'should call meshblu.message', ->
          expect(@meshblu.message).to.have.been.calledWith foo: 'bar'

      describe 'on update', ->
        beforeEach ->
          update =
            foo: 'bar'
          @connector.emit 'update', update

        it 'should call meshblu.update', ->
          expect(@meshblu.update).to.have.been.calledWith foo: 'bar', token: 'a-token', uuid: 'some-uuid'

    describe 'meshblu', ->
      beforeEach ->
        {@meshblu, @connector, @messageHandler} = @sut
        @messageHandler.onMessage = sinon.stub()
        @connector.onConfig = sinon.stub()

      describe 'on message', ->
        beforeEach ->
          message =
            foo: 'bar'
          @meshblu.emit 'message', message

        it 'should call connector.onMessage', ->
          expect(@messageHandler.onMessage).to.have.been.calledWith foo: 'bar'

      describe 'on error', ->
        beforeEach (done) ->
          @sut.on 'error', (@error) => done()
          error = new Error "Something bad happened to Meshblu!"
          @meshblu.emit 'error', error

        it 'should emit the error', ->
          expect(@error).to.exist

      describe 'on notReady', ->
        beforeEach (done) ->
          done = _.once done
          @sut.on 'notReady', (@notReady) => setTimeout done, 500
          @sut.on 'error', (@error) => done()
          error = new Error "Meshblu wasn't ready. Or something."
          @meshblu.emit 'notReady', error

        it 'should not emit as an error', ->
          expect(@error).to.not.exist

        it 'should emit a notReady', ->
          expect(@notReady).to.exist

      describe 'on config', ->
        beforeEach ->
          config =
            foo: 'bar'
          @meshblu.emit 'config', config

        it 'should call connector.onConfig', ->
          expect(@connector.onConfig).to.have.been.calledWith foo: 'bar'

    describe 'messageHandler', ->
      beforeEach ->
        {@meshblu, @connector, @messageHandler} = @sut
        @meshblu.message = sinon.stub()

      context 'job not found', ->
        beforeEach ->
          message =
            metadata:
              jobType: 'UnknownJob'
            fromUuid: 'from-uuid'

          @meshblu.emit 'message', message

        it 'should call meshblu.message', ->
          message =
            data: undefined
            devices: ['from-uuid']
            topic: 'response'
            metadata:
              code: 404
              status: 'Not Found'
          expect(@meshblu.message).to.have.been.calledWith message

      context 'job yields error', ->
        beforeEach (done) ->
          message =
            metadata:
              jobType: 'Fail'
            fromUuid: 'from-uuid'

          @meshblu.message = (@message, callback) =>
            callback?()
            done()
          @meshblu.emit 'message', message

        it 'should call meshblu.message', ->
          message =
            devices: ['from-uuid']
            topic: 'error'
            metadata:
              code: 500
              error: message: 'something wrong'
          expect(@message).to.deep.equal message

      context 'job yields response', ->
        beforeEach (done) ->
          message =
            metadata:
              jobType: 'Response'
            fromUuid: 'from-uuid'

          @meshblu.message = (@message, callback) =>
            callback?()
            _.defer done
          @meshblu.emit 'message', message

        it 'should call meshblu.message', ->
          message =
            data: 'i-am-data'
            devices: ['from-uuid']
            topic: 'response'
            metadata:
              code: 200
          expect(@message).to.deep.equal message

      context 'job yields no response', ->
        beforeEach ->
          message =
            metadata:
              jobType: 'NoResponse'
            fromUuid: 'from-uuid'

          @meshblu.emit 'message', message

        it 'should not call meshblu.message', ->
          expect(@meshblu.message).not.to.have.been.called

      context 'job yields an error and has respondTo', ->
        beforeEach ->
          message =
            metadata:
              jobType: 'Fail'
              respondTo:
                node: 'some-node'
            fromUuid: 'from-uuid'

          @meshblu.emit 'message', message

        it 'should call meshblu.message', ->
          message =
            devices: ["from-uuid"],
            topic: "error"
            metadata:
              code: 500
              error:
                message: "something wrong"
              to:
                node: "some-node"

          expect(@meshblu.message).to.have.been.calledWith message

      context 'message has a code', ->
        beforeEach ->
          message =
            metadata:
              code: 204
              jobType: 'Fail'
              respondTo:
                node: 'some-node'
            fromUuid: 'from-uuid'

          @meshblu.emit 'message', message

        it 'should not call meshblu.message', ->
          expect(@meshblu.message).not.to.have.been.called
