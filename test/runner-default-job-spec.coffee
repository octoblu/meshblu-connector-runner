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

    connectorPath = __dirname + '/fake-default-job-connector'

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
            data: 'i-am-data'
            devices: ['from-uuid']
            topic: 'response'
            metadata:
              code: 200
          expect(@meshblu.message).to.have.been.calledWith message
