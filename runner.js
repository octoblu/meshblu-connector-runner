"use strict"

var pathExists = require("path-exists")
var runner = null

if (pathExists.sync("./lib/runner.js")) {
  runner = require("./lib/runner")
} else {
  require("coffee-script/register")
  runner = require("./src/runner")
}

module.exports = runner
