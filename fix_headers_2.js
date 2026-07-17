const fs = require('fs');

function replaceHeader(filePath) {
    let content = fs.readFileSync(filePath, 'utf8');
    const targetRegex = /<div class="flex gap-1 justify-self-end">[\s\S]*?<\/div>/;
    
    const replacement = `<div class="flex items-center gap-4 justify-self-end text-primary" style="color: #2A6062;">
        <button type="button" onclick="window.location.reload()" aria-label="Sync" class="focus:outline-none flex items-center">
          <span class="material-symbols-outlined text-[24px]" style="font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;">sync</span>
        </button>
        <button type="button" aria-label="Bluetooth" class="focus:outline-none flex items-center">
          <span class="material-symbols-outlined text-[24px]" style="font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;">bluetooth</span>
        </button>
      </div>`;
      
    if (targetRegex.test(content)) {
        content = content.replace(targetRegex, replacement);
        fs.writeFileSync(filePath, content);
        console.log(`Updated ${filePath}`);
    } else {
        console.log(`Target not found in ${filePath}`);
    }
}

replaceHeader('E:/projects/healus/ui_design/meal_setting/code.html');
replaceHeader('E:/projects/healus/ui_design/basal_setting/code.html');
