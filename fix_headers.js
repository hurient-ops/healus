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
  
  // Parse the title
  const titleMatch = content.match(/<h1[^>]*>(.*?)<\/h1>/);
  const title = titleMatch ? titleMatch[1] : '';
  
  // Parse the back link
  const backMatch = content.match(/<a href="([^"]+)"[^>]*aria-label="Go back"/);
  const backHref = backMatch ? backMatch[1] : '#';
  
  // Parse the sync button onclick
  const syncMatch = content.match(/<button type="button" onclick="([^"]+)" aria-label="Sync"/);
  let syncOnclick = '';
  if (syncMatch && syncMatch[1]) {
    syncOnclick = ` onclick="${syncMatch[1]}"`;
  }
  
  const newHeader = `
<header class="flex items-center justify-between px-5 bg-white border-b border-gray-100 shrink-0 h-14 relative z-20">
<div class="flex items-center w-[80px]">
<a href="${backHref}" aria-label="Go back" class="text-[#2A6062] focus:outline-none">
<span class="material-icons text-[24px]">arrow_back</span>
</a>
</div>
<h1 class="text-[18px] font-bold text-gray-900 text-center flex-1 truncate px-2">${title}</h1>
<div class="flex items-center gap-4 w-[80px] justify-end text-[#2A6062]">
<button type="button"${syncOnclick} aria-label="Sync" class="focus:outline-none">
<span class="material-icons text-[24px]">sync</span>
</button>
<button aria-label="Bluetooth" class="focus:outline-none">
<span class="material-icons text-[24px]">bluetooth</span>
</button>
</div>
</header>
  `.trim();

  // Try replacing the specific new header first (if the file has it)
  const headerRegex1 = /<header class="flex items-center justify-between px-4 bg-white border-b border-gray-100 shrink-0 h-14 relative z-20">[\s\S]*?<\/header>/;
  const headerRegex2 = /<header class="flex items-center justify-between px-4 py-3 bg-white border-b border-gray-100 shrink-0 h-\[104px\]">[\s\S]*?<\/header>/;
  
  if (headerRegex1.test(content)) {
    content = content.replace(headerRegex1, newHeader);
    fs.writeFileSync(fullPath, content);
    console.log('Updated ' + file);
  } else if (headerRegex2.test(content)) {
    content = content.replace(headerRegex2, newHeader);
    fs.writeFileSync(fullPath, content);
    console.log('Updated ' + file + ' (old header)');
  } else {
    console.log('Header not found in ' + file);
  }
});
