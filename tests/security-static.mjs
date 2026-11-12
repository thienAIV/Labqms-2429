import fs from 'node:fs';import path from 'node:path';
const files=[];function walk(d){for(const n of fs.readdirSync(d)){if(['node_modules','dist','.git'].includes(n))continue;const p=path.join(d,n);fs.statSync(p).isDirectory()?walk(p):files.push(p)}}walk(process.cwd());
const source=files.filter(f=>!f.endsWith('security-static.mjs')).map(f=>fs.readFileSync(f,'utf8')).join('\n');const bad=[];
if(/Demo@123/.test(source))bad.push('demo password');
if(/(?:sb_secret_|service_role)\s*[=:]\s*['"][A-Za-z0-9_-]+/i.test(source))bad.push('embedded secret');
if(!source.includes('enable row level security'))bad.push('RLS declarations missing');
if(!/\('documents','documents',false/.test(source))bad.push('documents bucket is not explicitly private');
if(bad.length){console.error('FAIL',bad);process.exit(1)}console.log('PASS security static checks:',files.length,'files');
