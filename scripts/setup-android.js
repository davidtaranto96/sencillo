#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const localProps = path.join(__dirname, '..', 'android', 'local.properties');
const sdkPath = 'C:\\\\Users\\\\david\\\\AppData\\\\Local\\\\Android\\\\Sdk';

if (!fs.existsSync(localProps)) {
  fs.writeFileSync(localProps, `sdk.dir=${sdkPath}\n`);
  console.log('✓ Creado android/local.properties');
} else {
  console.log('✓ android/local.properties ya existe');
}
