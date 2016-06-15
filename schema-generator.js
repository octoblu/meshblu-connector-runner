#!/usr/bin/env node
'use strict';
require('coffee-script/register');
require('fs-cson/register');

var SchemaGenerator, schemaGenerator;

SchemaGenerator = require('./src/schema-generator.coffee');
schemaGenerator = new SchemaGenerator({argv: process.argv});
schemaGenerator.run();
