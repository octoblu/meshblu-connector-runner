"use strict"

var pathExists = require('path-exists');
var index = null;

if (pathExists.sync('./dist/index.js')) {
  index = require('./dist/index')
} else {
  require('coffee-script/register');
  index = require('./src/index');
}

module.exports = index
