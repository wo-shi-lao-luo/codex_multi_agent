// Controlled CLI double for transport failures. Real lifecycle coverage uses the pinned upstream CLI.
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
const mode = process.env.KIT_OPENSPEC_TEST_MODE || '';
if (args[0] === '--version') {
  console.log(mode === 'version' ? '99.0.0' : '1.13.2');
} else if (mode === 'exit') {
  console.error('controlled upstream failure'); process.exitCode = 7;
} else if (mode === 'json') {
  console.log('not json');
} else if (mode === 'timeout') {
  setTimeout(() => {}, 10000);
} else if (args[0] === 'templates') {
  console.log(JSON.stringify(Object.fromEntries(['proposal', 'specs', 'design', 'tasks'].map(id => [id, { source: mode === 'schema' ? 'user' : 'package' }]))));
} else if (args[0] === 'archive') {
  // Simulate a partial upstream write: recovery must preserve both old and damaged states.
  fs.writeFileSync(path.join(process.cwd(), 'openspec/specs/damaged.md'), 'partial write');
  console.error('controlled archive failure'); process.exitCode = 9;
} else {
  console.log(JSON.stringify({ changeName: 'sample', schemaName: 'spec-driven', artifacts: [], root: { path: process.cwd() } }));
}
