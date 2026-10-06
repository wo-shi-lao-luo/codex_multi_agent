// Controlled Prettier transport double: log calls and produce deterministic text.
// This is not a formatter implementation and must never ship as a production tool.
const fs = require('node:fs');
const path = require('node:path');

const args = process.argv.slice(2);
const ownRoot = path.resolve(__dirname, '../../..');
const log = path.join(ownRoot, 'tool-calls.jsonl');
fs.appendFileSync(log, JSON.stringify(args) + '\n');
if (args.includes('--version')) {
  process.stdout.write('0.0.0-controlled-fixture\n');
  process.exit(0);
}
if (args.includes('--file-info')) {
  const index = args.indexOf('--file-info');
  const target = args[index + 1];
  process.stdout.write(JSON.stringify({ ignored: target.includes('ignored'), inferredParser: 'babel' }));
  process.exit(0);
}

// Scenario controls remain in the owned synthetic project, never process secrets.
const modeFile = path.join(ownRoot, 'tool-mode.txt');
const mode = fs.existsSync(modeFile) ? fs.readFileSync(modeFile, 'utf8').trim() : '';
if (mode === 'fail') {
  process.stderr.write('Controlled formatter failure.\n');
  process.exit(3);
}
if (mode === 'timeout') {
  setTimeout(() => process.exit(0), 4000);
} else {
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { input += chunk; });
  process.stdin.on('end', () => {
    if (input.includes('FAIL_SENTINEL')) {
      process.stderr.write('Controlled candidate failure.\n');
      process.exitCode = 3;
      return;
    }
    if (mode === 'oversize' || mode === 'unicode-oversize') {
      process.stdout.write(mode === 'oversize' ? 'x'.repeat(5 * 1024 * 1024) : '界'.repeat(1500000));
      return;
    }
    if (mode === 'unicode-boundary') {
      const bytes = Buffer.from('A' + '😀'.repeat(6000), 'utf8');
      for (let offset = 0; offset < bytes.length; offset += 4095) {
        process.stdout.write(bytes.subarray(offset, offset + 4095));
      }
      return;
    }
    // A faithful whitespace-only scenario complements deliberately hostile transport output.
    process.stdout.write(input.replaceAll('UNFORMATTED', 'FORMATTED').replace(/^const spacing=1;$/gm, 'const spacing = 1;'));
  });
}
