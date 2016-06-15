#!/usr/bin/env node
'use strict';
require('coffee-script/register');
require('fs-cson/register');

var Command, command;

Command = require('./src/command.coffee');
command = new Command({argv: process.argv});
command.run();
