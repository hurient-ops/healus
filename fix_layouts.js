const fs = require('fs');

function applyEdits(filePath, edits) {
    let content = fs.readFileSync(filePath, 'utf8');
    let changed = false;
    edits.forEach(edit => {
        if (content.includes(edit.from)) {
            content = content.replace(edit.from, edit.to);
            changed = true;
        } else {
            console.error(`Could not find target in ${filePath}:\n${edit.from}`);
        }
    });
    if (changed) {
        fs.writeFileSync(filePath, content);
        console.log(`Updated ${filePath}`);
    }
}

// 4. Meal Injection Padding
applyEdits('E:/projects/healus/ui_design/meal_injection/code.html', [
    {
        from: 'className="mb-5"',
        to: 'className="mb-3"'
    },
    {
        from: 'className="flex flex-col gap-3 mb-6"',
        to: 'className="flex flex-col gap-2 mb-3"'
    }
]);

// 5. Dining Image rounded corners
applyEdits('E:/projects/healus/ui_design/dining/code.html', [
    {
        from: 'class="rounded-xl overflow-hidden w-full shadow-sm border border-outline-variant/20 pt-xs h-[160px] mt-md"',
        to: 'class="rounded-xl overflow-hidden w-full shadow-sm border border-outline-variant/20 relative h-[160px] mt-md"'
    }
]);

// 6. History Screen height adjustment
applyEdits('E:/projects/healus/ui_design/history/code.html', [
    {
        from: '<div class="w-full shrink-0 pr-1 text-[10px] text-gray-400 text-right h-[320px] relative">',
        to: '<div class="w-full shrink-0 pr-1 text-[10px] text-gray-400 text-right h-[260px] relative">'
    },
    {
        from: '<div class="relative h-[320px] flex-1 border-l border-b border-gray-200 bg-white rounded-b-custom">',
        to: '<div class="relative h-[260px] flex-1 border-l border-b border-gray-200 bg-white rounded-b-custom">'
    }
]);
