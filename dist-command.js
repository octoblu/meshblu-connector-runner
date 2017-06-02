#!/usr/bin/env node
'use strict';
var Command, command;

Command = require('./dist/command');
command = new Command({argv: process.argv});
command.run();
