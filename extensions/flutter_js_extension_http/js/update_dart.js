// Write build result to js.dart
const fs = require("fs");
const path = require("path");
const buildFile = path.join(__dirname, "build/index.min.js");
const dartFile = path.join(__dirname, "../lib/src/js.dart");
const js = fs.readFileSync(buildFile, { encoding: "utf-8" }).trim();
const dart = fs.readFileSync(dartFile, { encoding: "utf-8" });
const replaced = dart.replace(/const String source = r'''([\s\S]*)''';/, `const String source = r'''${js.endsWith(';') ? js : js + ';'}void(0)''';`);
fs.writeFileSync(dartFile, replaced, { encoding: "utf-8" });
console.log('>>> Update dart done.');