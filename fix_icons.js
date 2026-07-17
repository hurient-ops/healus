const fs = require('fs');
const path = require('path');

const files = [
  'language_setting/code.html',
  'product/code.html',
  'app_info/code.html',
  'guidelines/code.html',
  'battery_change/code.html',
  'infomation/code.html',
  'usage/code.html',
  'infusionset_change/code.html'
];

files.forEach(file => {
  const fullPath = path.join('E:/projects/healus/ui_design', file);
  if (!fs.existsSync(fullPath)) return;
  
  let content = fs.readFileSync(fullPath, 'utf8');
  content = content.replace(/<span class="material-icons text-\[24px\]">/g, '<span class="material-symbols-outlined text-[24px]" style="font-variation-settings: \'FILL\' 0, \'wght\' 400, \'GRAD\' 0, \'opsz\' 24;">');
  
  fs.writeFileSync(fullPath, content);
  console.log('Fixed icons in ' + file);
});
