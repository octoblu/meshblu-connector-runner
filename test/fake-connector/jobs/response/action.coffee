Job = require './job'

module.exports = (options, message, callback) =>
  job = new Job options
  job.do message, callback
