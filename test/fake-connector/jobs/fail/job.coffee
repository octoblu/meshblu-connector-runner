_      = require 'lodash'

class Test
  constructor: ({@connector}) ->

  do: ({data}, callback) =>
    callback new Error 'something wrong'

module.exports = Test
