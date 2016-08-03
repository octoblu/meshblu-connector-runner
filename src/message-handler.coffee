_    = require 'lodash'
glob = require 'glob'
path = require 'path'
http = require 'http'

NOT_FOUND_RESPONSE = {metadata: {code: 404, status: http.STATUS_CODES[404]}}

class MessageHandler
  constructor: ({ @connector, @connectorPath, @defaultJobType, @logger }) ->
    throw new Error 'MessageHandler requires connectorPath' unless @connectorPath?
    throw new Error 'MessageHandler requires logger' unless @logger?
    @jobs = @_getJobs()

  onMessage: ({data, metadata}, callback) =>
    # drop responses on the floor
    return callback() if metadata?.code?

    job = @jobs[metadata?.jobType]
    job ?= @jobs[@defaultJobType] if @defaultJobType?
    return callback null, NOT_FOUND_RESPONSE unless job?

    @logger.debug {job}, 'MessageHandler.onMessage'
    job.action {@connector}, {data, metadata}, (error, response) =>
      return callback error if error?
      return callback null, _.pick(response, 'data', 'metadata')

  _getJobs: =>
    dirnames = glob.sync path.join(@connectorPath, 'jobs', '/*/')
    jobs = {}
    _.each dirnames, (dir) =>
      key = _.upperFirst _.camelCase path.basename dir
      try
        jobs[key] = require dir
      catch error
        @logger.debug error
        console.error error.stack

    return jobs

module.exports = MessageHandler
