# meshblu-connector-runner

[![Build Status](https://travis-ci.org/octoblu/meshblu-connector-runner.svg?branch=master)](https://travis-ci.org/octoblu/meshblu-connector-runner)
[![Test Coverage](https://codecov.io/gh/octoblu/meshblu-connector-runner/branch/master/graph/badge.svg)](https://codecov.io/gh/octoblu/meshblu-connector-runner)
[![Dependency status](http://img.shields.io/david/octoblu/meshblu-connector-runner.svg?style=flat)](https://david-dm.org/octoblu/meshblu-connector-runner)
[![devDependency Status](http://img.shields.io/david/dev/octoblu/meshblu-connector-runner.svg?style=flat)](https://david-dm.org/octoblu/meshblu-connector-runner#info=devDependencies)
[![Slack Status](http://community-slack.octoblu.com/badge.svg)](http://community-slack.octoblu.com)

[![NPM](https://nodei.co/npm/meshblu-connector-runner.svg?style=flat)](https://npmjs.org/package/meshblu-connector-runner)
[![Dependency status](http://img.shields.io/david/octoblu/meshblu-connector-runner.svg?style=flat)](https://david-dm.org/octoblu/meshblu-connector-runner)


A component of [Meshblu Connectors](https://meshblu-connectors.readme.io). Click [here](https://meshblu-connectors.readme.io/docs/connector-runner) to view the component documentation.

## Getting Started

### Installation

In the connector project, follow these steps:

1 - Install the runner inside the connector

```bash
npm install --save meshblu-connector-runner
```

2 - Add to the `start` script to your `package.json`

```js
{
  //...
  "scripts": {
    "start": "meshblu-connector-runner"
  }
  //...
}
```

### Usage

**Requirements:**
* A meshblu configuration - see [meshblu-config](https://github.com/meshblu-config)
* A compatible connector. Use the latest [generator](https://github.com/octoblu/generator-meshblu-connector) to build a connector.

Running the connector:

```bash
npm start
```
