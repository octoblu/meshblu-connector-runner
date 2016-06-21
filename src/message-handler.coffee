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

  _getJobs: =>
    dirnames = fs.readdirSync path.join(@connectorPath, 'jobs')
    jobs = {}
    _.each dirnames, (dirname) =>
      key = _.upperFirst _.camelCase dirname
      dir = path.join @connectorPath, 'jobs', dirname
      jobs[key] = require dir
    return jobs

module.exports = MessageHandler
