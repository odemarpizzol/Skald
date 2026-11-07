// Release gates must reject failed launches and missing evidence, even if status happens to be zero.
function toolFailure(result, expected) {
  if (result.error) return 'could not start: ' + result.error.message;
  if (result.signal) return 'terminated by ' + result.signal;
  if (result.status !== 0) return 'exit status ' + result.status;
  if (typeof result.stdout !== 'string' || !expected.test(result.stdout)) return 'missing expected result';
  return null;
}

function inspectTga(data) {
  if (data.length < 18) throw new Error('truncated TGA header');
  if (data[1] !== 0 || data[2] !== 2 || data[16] !== 32 || (data[17] & 15) !== 8) {
    throw new Error('expected uncompressed 32-bit TGA with 8-bit alpha');
  }
  const width = data.readUInt16LE(12), height = data.readUInt16LE(14);
  const powerOfTwo = n => n > 0 && (n & (n - 1)) === 0;
  if (!powerOfTwo(width) || !powerOfTwo(height)) throw new Error('dimensions must be powers of two');
  const start = 18 + data[0], end = start + width * height * 4;
  if (data.length < end) throw new Error('truncated pixel data');
  let visible = 0;
  for (let i = start + 3; i < end; i += 4) if (data[i] > 0) visible++;
  if (!visible) throw new Error('all pixels are transparent');
  return { width, height, visible };
}

module.exports = { toolFailure, inspectTga };
