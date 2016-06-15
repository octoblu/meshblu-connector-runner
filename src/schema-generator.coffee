_              = require 'lodash'
async          = require 'async'
dashdash       = require 'dashdash'
path           = require 'path'
MessageHandler = require './message-handler'
stringify      = require 'json-stable-stringify'

class SchemaGenerator
  constructor: ({argv}) ->
    options = [
      {
        names: ['dir', 'd'],
        type: 'string',
        help: 'Connector directory',
        helpArg: 'DIR'
      }
    ]
    @args = dashdash.parse({argv, options})

  panic: (error)=>
    console.error error.stack
    process.exit 1

  run: (callback) =>
    connectorPath = @_getConnectorPath()
    schemas =
      version: '2.0.0'

    messageHandler = new MessageHandler {connectorPath}

    tasks =
      formSchema: messageHandler.formSchema
      messageSchema: messageHandler.messageSchema
      responseSchema: messageHandler.responseSchema
      configSchema: messageHandler.configSchema

    async.parallel tasks, (error, {formSchema, messageSchema, responseSchema, configSchema}) =>
      return @panic error if error?

      schemas.form = formSchema
      schemas.message = messageSchema
      schemas.response = responseSchema
      schemas.configure = configSchema

      return callback null, {schemas} if callback?
      console.log stringify {schemas}, space: 2

  _getConnectorPath: =>
    return process.cwd() unless @args.dir
    connectorPath = @args.dir
    return path.resolve connectorPath

module.exports = SchemaGenerator
