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
      @socket.emit 'identify'

    @meshblu = new MockMeshbluSocketIO port: 0xd00d, onConnection: onConnection
    @meshblu.start done

  afterEach 'socket.io', (done) ->
    @meshblu.stop done

  beforeEach ->
    meshbluConfig =
      uuid: 'some-uuid'
      token: 'a-token'
      server: 'localhost'
      port: @meshblu.port

    connectorPath = __dirname + '/fake-connector'

    @sut = new Runner {meshbluConfig, connectorPath}

  describe '->run', ->
    beforeEach (done) ->
      @whoamiHandler.yields uuid: 'some-uuid'
      @registerHandler.yields {}
      @updateHandler.yields {}
      @sut.run done

    afterEach (done) ->
      @sut.close done

    it 'should create a statusDevice', ->
      expect(@sut.statusDevice).to.exist

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
        beforeEach ->
          message =
            metadata:
              jobType: 'Fail'
            fromUuid: 'from-uuid'

          @meshblu.emit 'message', message

        it 'should call meshblu.message', ->
          message =
            devices: ['from-uuid']
            topic: 'error'
            metadata:
              code: 500
              error: message: 'something wrong'
          expect(@meshblu.message).to.have.been.calledWith message

      context 'job yields response', ->
        beforeEach ->
          message =
            metadata:
              jobType: 'Response'
            fromUuid: 'from-uuid'

          @meshblu.emit 'message', message

        it 'should call meshblu.message', ->
          message =
            data: 'i-am-data'
            devices: ['from-uuid']
            topic: 'response'
            metadata:
              code: 200
          expect(@meshblu.message).to.have.been.calledWith message

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
