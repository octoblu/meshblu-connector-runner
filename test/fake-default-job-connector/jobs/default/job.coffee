_      = require 'lodash'

class Test
  constructor: ({@connector}) ->

  do: ({data}, callback) =>
    response =
      metadata:
        code: 200
      data: 'i-am-data'
    callback null, response

module.exports = Test
