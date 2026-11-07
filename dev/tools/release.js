// The old script targeted Skald-publish and modified/copied files outside this repository.
// Fail before reading credentials, changing a version, building or uploading anything.
console.error('Legacy release script disabled. Follow dev/GUIA_PUBLICACAO.md.');
console.error('Run node dev/tools/checks.js, prepare the chosen version and changelog, then publish through the approved Git tag workflow.');
process.exitCode = 1;
