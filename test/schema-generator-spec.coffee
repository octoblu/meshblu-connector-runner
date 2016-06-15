SchemaGenerator = require '../src/schema-generator'
expectedSchema = require './expected-schema.json'

describe 'SchemaGenerator', ->
  beforeEach ->
    @sut = new SchemaGenerator argv: ['node', 'somefile', '--dir', 'test/fake-connector']

  it 'should generate a schema', (done) ->
    @sut.run (error, schemas) =>
      return done error if error?
      expect(schemas).to.deep.equal expectedSchema
      done()
