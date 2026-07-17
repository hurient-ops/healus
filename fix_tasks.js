const fs = require('fs');

function applyEdits(filePath, edits) {
    let content = fs.readFileSync(filePath, 'utf8');
    let changed = false;
    edits.forEach(edit => {
        if (content.includes(edit.from)) {
            content = content.replace(edit.from, edit.to);
            changed = true;
        } else {
            console.error(`Could not find target in ${filePath}:\n${edit.from.substring(0, 50)}...`);
        }
    });
    if (changed) {
        fs.writeFileSync(filePath, content);
        console.log(`Updated ${filePath}`);
    }
}

// 1. Meal Setting Layout Fixes
applyEdits('E:/projects/healus/ui_design/meal_setting/code.html', [
    {
        from: '<div class="p-4 flex flex-col gap-4">',
        to: '<div class="p-4 flex flex-col gap-2">'
    },
    {
        from: '<div class="mt-4 flex gap-3">',
        to: '<div class="mt-2 flex gap-3">'
    },
    {
        from: 'active:scale-95 text-[16px] font-bold py-4">저장',
        to: 'active:scale-95 text-[16px] font-bold py-3">저장'
    },
    {
        from: 'active:scale-95 text-[16px] font-bold py-4">닫기',
        to: 'active:scale-95 text-[16px] font-bold py-3">닫기'
    }
]);

// 2. Meal Setting and Basal Setting Header Icons Fix
const mealSettingHeaderTarget = `<div class="flex gap-1 justify-self-end">
        <button type="button" onclick="window.location.reload()" class="p-2 hover:bg-teal-50 rounded-full transition-colors active:scale-95 text-primary">
          <span class="material-symbols-outlined">sync</span>
        </button>
        <button type="button" class="p-2 hover:bg-teal-50 rounded-full transition-colors active:scale-95 text-primary">
          <span class="material-symbols-outlined">bluetooth</span>
        </button>
      </div>`;
const mealSettingHeaderReplacement = `<div class="flex items-center gap-4 justify-self-end text-primary" style="color: #2A6062;">
        <button type="button" onclick="window.location.reload()" aria-label="Sync" class="focus:outline-none flex items-center">
          <span class="material-symbols-outlined text-[24px]" style="font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;">sync</span>
        </button>
        <button type="button" aria-label="Bluetooth" class="focus:outline-none flex items-center">
          <span class="material-symbols-outlined text-[24px]" style="font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;">bluetooth</span>
        </button>
      </div>`;

applyEdits('E:/projects/healus/ui_design/meal_setting/code.html', [
    {
        from: mealSettingHeaderTarget,
        to: mealSettingHeaderReplacement
    }
]);

// For basal_setting we need to check its header first
let basalContent = fs.readFileSync('E:/projects/healus/ui_design/basal_setting/code.html', 'utf8');
if (basalContent.includes(mealSettingHeaderTarget)) {
    applyEdits('E:/projects/healus/ui_design/basal_setting/code.html', [
        {
            from: mealSettingHeaderTarget,
            to: mealSettingHeaderReplacement
        }
    ]);
} else if (basalContent.includes('<div class="flex gap-1 justify-self-end">')) {
    // try to find the exact target by regex or simpler string
    // Let's just use regex for basal setting if exact string fails
    const match = basalContent.match(/<div class="flex gap-1 justify-self-end">[\s\S]*?<\/div>/);
    if(match) {
        applyEdits('E:/projects/healus/ui_design/basal_setting/code.html', [
            {
                from: match[0],
                to: mealSettingHeaderReplacement
            }
        ]);
    }
}

// 3. Info screens long title truncation - reduce gap and width of right icons container
const infoScreens = ['usage', 'guidelines', 'infusionset_change', 'battery_change'];
infoScreens.forEach(folder => {
    applyEdits(`E:/projects/healus/ui_design/${folder}/code.html`, [
        {
            from: '<div class="flex items-center gap-4 w-[80px] justify-end text-[#2A6062]">',
            to: '<div class="flex items-center gap-1 w-[60px] justify-end text-[#2A6062]">'
        }
    ]);
});
