"use strict"

var pathExists = require("path-exists")
var index = null

if (pathExists.sync("./lib/index.js")) {
  index = require("./lib/index")
} else {
  require("coffee-script/register")
  index = require("./src/index")
}

module.exports = index
