import vm from 'node:vm';
import fs from 'node:fs';
import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('../XiWang/downloads.js',import.meta.url),'utf8');
let originalClicks=0,clickListener,readError=false,blobSize=12;
const messages=[];
class Anchor {click(){originalClicks++;}}
class FileReader {
  readAsDataURL(){this.result='data:application/json;base64,eyJ0ZXN0Ijp0cnVlfQ==';queueMicrotask(()=>this.onload());}
}
vm.runInNewContext(source,{
  window:{webkit:{messageHandlers:{xiwangDownload:{postMessage:m=>messages.push(m)}}}},
  HTMLAnchorElement:Anchor,FileReader,
  document:{addEventListener:(name,fn)=>{assert.equal(name,'click');clickListener=fn;}},
  fetch:async()=>{if(readError)throw Error('Network error');return {ok:true,blob:async()=>({size:blobSize})};}
});
const flush=()=>new Promise(resolve=>setImmediate(resolve));
const anchor=(href,download)=>Object.assign(new Anchor(),{href,download});
anchor('blob:test','膝望备份.json').click();await flush();
assert.equal(messages.length,1);assert.equal(messages[0].name,'膝望备份.json');assert.equal(originalClicks,0);
assert.equal(Buffer.from(messages[0].base64,'base64').toString(),'{"test":true}');
anchor('blob:test','膝望康复周报.html').click();await flush();assert.equal(messages[1].name,'膝望康复周报.html');
anchor('https://example.com/','').click();anchor('blob:test','image.jpg').click();assert.equal(originalClicks,2);
let prevented=false;const a=anchor('blob:test','膝望待同步内容.json');
clickListener({target:{closest:()=>a},preventDefault:()=>{prevented=true}});await flush();assert.equal(prevented,true);assert.equal(messages[2].name,'膝望待同步内容.json');
blobSize=10_000_001;anchor('blob:test','too-big.json').click();await flush();assert.equal(messages.at(-1).error,'download');
blobSize=12;readError=true;anchor('blob:test','failed.json').click();await flush();assert.equal(messages.at(-1).error,'download');
console.log('PASS detached report/backup exports, user clicks, normal links, unsupported files, oversize and failed reads');
