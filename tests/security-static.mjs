import fs from 'node:fs';import path from 'node:path';
const root=process.cwd();const files=[];function walk(d){for(const n of fs.readdirSync(d)){const p=path.join(d,n);if(['node_modules','dist','.git'].includes(n))continue;fs.statSync(p).isDirectory()?walk(p):files.push(p)}}walk(root);
const text=files.filter(f=>!f.endsWith('.zip')&&!f.endsWith('security-static.mjs')).map(f=>fs.readFileSync(f,'utf8')).join('\n');
const failures=[];if(/service_role\s*[=:]\s*['"][A-Za-z0-9_-]+/i.test(text))failures.push('service_role key');if(/Demo@123/.test(text))failures.push('demo password');if(!/enable row level security/i.test(text))failures.push('RLS declarations');if(!/public\s*=\s*false/i.test(text))failures.push('private storage');
if(failures.length){console.error('FAILED:',failures.join(', '));process.exit(1)}console.log('PASS security static checks:',files.length,'files');
