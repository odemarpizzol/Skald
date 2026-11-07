const assert = require('assert');
const { toolFailure, inspectTga } = require('./check_helpers');
const done = /All done/;
assert(toolFailure({ status: 0, stdout: 'All done', error: new Error('EPERM') }, done));
assert(toolFailure({ status: 0, stdout: '' }, done));
assert(toolFailure({ status: 1, stdout: 'All done' }, done));
assert(toolFailure({ status: 0, signal: 'SIGTERM', stdout: 'All done' }, done));
assert.strictEqual(toolFailure({ status: 0, stdout: 'All done' }, done), null);
const tga = Buffer.alloc(18 + 2 * 2 * 4);
tga[2] = 2; tga.writeUInt16LE(2, 12); tga.writeUInt16LE(2, 14); tga[16] = 32; tga[17] = 8;
assert.throws(() => inspectTga(tga), /transparent/);
// A footer with nonzero bytes must never count as visible pixels.
assert.throws(() => inspectTga(Buffer.concat([tga, Buffer.from('TRUEVISION-XFILE.')])), /transparent/);
tga[21] = 255;
assert.strictEqual(inspectTga(tga).visible, 1);
assert.throws(() => inspectTga(tga.subarray(0, 20)), /truncated/);
const badSize = Buffer.from(tga); badSize.writeUInt16LE(3, 12);
assert.throws(() => inspectTga(badSize), /powers/);
console.log('All tooling checks passed');
