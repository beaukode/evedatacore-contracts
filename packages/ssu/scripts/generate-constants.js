#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Read the namespace from environment variable, with fallback
const namespace = process.env.SSU_NAMESPACE || process.env.DEFAULT_NAMESPACE;

if(!namespace) {
  console.error('Error: SSU_NAMESPACE is not set');
  process.exit(1);
}

// Ensure namespace fits in bytes16 (16 bytes)
if (namespace.length > 16) {
  console.error(`Error: SSU_NAMESPACE "${namespace}" is longer than 16 bytes (bytes16 limit)`);
  process.exit(1);
}

// Read the existing constants file
const constantsPath = path.join(__dirname, '../src/systems/constants.sol');
let constantsContent = fs.readFileSync(constantsPath, 'utf8');

// Replace the placeholder with the actual namespace value
if (!constantsContent.includes('%SSU_NAMESPACE%')) {
  console.error('Error: Placeholder %SSU_NAMESPACE% not found in constants.sol');
  process.exit(1);
}

constantsContent = constantsContent.replace('%SSU_NAMESPACE%', namespace);

// Write back to the constants file
fs.writeFileSync(constantsPath, constantsContent, 'utf8');

console.log(`Generated constants.sol with SSU_SYSTEM_NAMESPACE = "${namespace}"`);

