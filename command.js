#!/usr/bin/env node
'use strict';
require('coffee-script/register');
var Command, command;

Command = require('./src/command');
command = new Command({argv: process.argv});
command.run();
