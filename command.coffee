_             = require 'lodash'
fs            = require 'fs'
path          = require 'path'
Runner        = require './src/runner'
MeshbluConfig = require 'meshblu-config'

class Command
  run: =>
    connectorPath = @getConnectorPath()
    @isValidConnector({ connectorPath })

    meshbluConfig = new MeshbluConfig({}).toJSON()
    @isValidMeshbluConfig(meshbluConfig)

    runner = new Runner {meshbluConfig, connectorPath}
    runner.run()

  getConnectorPath: =>
    connectorPath = _.last process.argv[2..]
    connectorPath = path.resolve connectorPath if connectorPath?
    connectorPath ?= process.cwd()
    return connectorPath

  isValidConnector: ({ connectorPath })=>
    packageJSONPath = path.join(connectorPath, 'package.json')
    @die new Error 'Invalid connector, missing package.json' unless fs.existsSync connectorPath

  isValidMeshbluConfig: ({ uuid, token }) =>
    @die new Error 'Missing uuid and token' unless uuid? or token?

  die: (error)=>
    process.exit 0 unless error?
    console.error error.stack
    process.exit 1

new Command().run()
