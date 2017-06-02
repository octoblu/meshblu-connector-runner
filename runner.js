"use strict"

var pathExists = require('path-exists');
var runner = null;

if (pathExists.sync('./dist/runner.js')) {
  runner = require('./dist/runner')
} else {
  require('coffee-script/register');
  runner = require('./src/runner');
}

module.exports = runner
