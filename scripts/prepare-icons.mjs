import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const folder = 'XiWang/Assets.xcassets/AppIcon.appiconset';
const source = `${folder}/icon-1024.png`;
const png = readFileSync(source);
const expected = 'b06d9254ac86b850aaa68a89f468215ea119c217592dcdd358605fa12db33bc7';
if (createHash('sha256').update(png).digest('hex') !== expected) throw new Error('Icon source is incomplete or changed');
if (png.readUInt32BE(16) !== 1024 || png.readUInt32BE(20) !== 1024 || png.subarray(-8, -4).toString() !== 'IEND') throw new Error('Invalid icon PNG');

const images = [];
for (const size of [20, 29, 40, 60]) {
  for (const scale of [2, 3]) {
    const filename = `icon-${size}@${scale}x.png`;
    const pixels = size * scale;
    execFileSync('sips', ['-z', String(pixels), String(pixels), source, '--out', `${folder}/${filename}`], { stdio: 'pipe' });
    const output = readFileSync(`${folder}/${filename}`);
    if (output.readUInt32BE(16) !== pixels || output.readUInt32BE(20) !== pixels) throw new Error('Icon resize failed');
    images.push({ filename, idiom: 'iphone', size: `${size}x${size}`, scale: `${scale}x` });
  }
}
images.push({ filename: 'icon-1024.png', idiom: 'ios-marketing', size: '1024x1024', scale: '1x' });
writeFileSync(`${folder}/Contents.json`, JSON.stringify({ images, info: { author: 'xcode', version: 1 } }, null, 2));
mkdirSync('artifacts', { recursive: true });
copyFileSync(source, 'artifacts/AppIcon-HD-1024.png');
copyFileSync(`${folder}/icon-60@3x.png`, 'artifacts/AppIcon-iPhone-180.png');
console.log('PASS: complete source hash and all iPhone icon sizes');
