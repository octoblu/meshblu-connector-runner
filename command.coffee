_             = require 'lodash'
fs            = require 'fs'
path          = require 'path'
Runner        = require './runner'
MeshbluConfig = require 'meshblu-config'

class Command
  run: =>
    return @die new Error 'Missing connector path' if _.size(process.argv) <= 2
    connectorPath = _.last process.argv
    connectorPath = path.resolve connectorPath
    packageJSONPath = path.join(connectorPath, 'package.json')
    return @die new Error 'Invalid connector, missing package.json' unless fs.existsSync connectorPath
    meshbluConfig = new MeshbluConfig({}).toJSON()
    return @die new Error 'Missing uuid and token' unless meshbluConfig.uuid or meshbluConfig.token
    runner = new Runner {meshbluConfig, connectorPath}
    runner.run()

  die: (error)=>
    process.exit 0 unless error?
    console.error error.stack
    process.exit 1

new Command().run()
