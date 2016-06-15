_    = require 'lodash'
fs   = require 'fs'
path = require 'path'
http = require 'http'

NOT_FOUND_RESPONSE = {metadata: {code: 404, status: http.STATUS_CODES[404]}}

class MessageHandler
  constructor: ({@connector, @connectorPath}) ->
    throw new Error 'MessageHandler requires connectorPath' unless @connectorPath?
    @jobs = @_getJobs()

  onMessage: ({data, metadata}, callback) =>
    job = @jobs[metadata.jobType]
    return callback null, NOT_FOUND_RESPONSE unless job?

    job.action {@connector}, {data, metadata}, (error, response) =>
      return callback error if error?
      return callback null, _.pick(response, 'data', 'metadata')

  configSchema: (callback) =>
    callback null, @_configSchemaFromConnectorPath()

  formSchema: (callback) =>
    callback null, @_formSchemaFromJobs @jobs

  messageSchema: (callback) =>
    callback null, @_messageSchemaFromJobs @jobs

  responseSchema: (callback) =>
    callback null, @_responseSchemaFromJobs @jobs

  _configSchemaFromConnectorPath: =>
    filenames = fs.readdirSync path.join(@connectorPath, 'configs')
    configs = {}
    _.each filenames, (filename) =>
      filename = _.first filename.split /\./
      key = _.upperFirst _.camelCase filename
      file = path.join @connectorPath, 'configs', filename
      configs[key] = require file
    return configs

  _formSchemaFromJobs: (jobs) =>
    return {
      message: _.mapValues jobs, 'form'
    }

  _generateMessageMetadata: (jobType) =>
    return {
      type: 'object'
      required: ['jobType']
      properties:
        jobType:
          type: 'string'
          enum: [jobType]
          default: jobType
        respondTo: {}
    }

  _generateResponseMetadata: =>
    return {
      type: 'object'
      required: ['status', 'code']
      properties:
        status:
          type: 'string'
        code:
          type: 'integer'
    }

  _getJobs: =>
    dirnames = fs.readdirSync path.join(@connectorPath, 'jobs')
    jobs = {}
    _.each dirnames, (dirname) =>
      key = _.upperFirst _.camelCase dirname
      dir = path.join @connectorPath, 'jobs', dirname
      jobs[key] = require dir
    return jobs

  _messageSchemaFromJob: (job, key) =>
    message = _.cloneDeep job.message
    _.set message, 'x-form-schema.angular', "message.#{key}.angular"
    _.set message, 'x-response-schema', "#{key}"
    _.set message, 'properties.metadata', @_generateMessageMetadata(key)
    message.required = _.union ['metadata'], message.required
    return message

  _messageSchemaFromJobs: (jobs) =>
    _.mapValues jobs, @_messageSchemaFromJob

  _responseSchemaFromJob: (job) =>
    response = _.cloneDeep job.response
    _.set response, 'properties.metadata', @_generateResponseMetadata()
    return response

  _responseSchemaFromJobs: (jobs) =>
    _.mapValues jobs, @_responseSchemaFromJob

module.exports = MessageHandler
