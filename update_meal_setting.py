import sys

file_path = r'e:\projects\healus\ui_design\meal_setting\code.html'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Expand options up to 30
old_options = '<option value=\"0\">0</option><option value=\"1\" selected>1</option><option value=\"2\">2</option><option value=\"3\">3</option><option value=\"4\">4</option><option value=\"5\">5</option><option value=\"6\">6</option><option value=\"7\">7</option><option value=\"8\">8</option><option value=\"9\">9</option><option value=\"10\">10</option><option value=\"11\">11</option><option value=\"12\">12</option><option value=\"13\">13</option><option value=\"14\">14</option><option value=\"15\">15</option><option value=\"16\">16</option><option value=\"17\">17</option><option value=\"18\">18</option><option value=\"19\">19</option><option value=\"20\">20</option>'

new_options = '<option value=\"0\">0</option><option value=\"1\" selected>1</option>' + ''.join(f'<option value=\"{i}\">{i}</option>' for i in range(2, 31))

content = content.replace(old_options, new_options)

# Add event listeners for int-select limits
old_script = '  function applyMealValues(values) {\n'

new_script = '''  function setupSelectListeners(intId, decId) {
    const intEl = document.getElementById(intId);
    const decEl = document.getElementById(decId);
    if (!intEl || !decEl) return;
    intEl.addEventListener('change', () => {
      if (intEl.value === '30') {
        decEl.value = '00';
        Array.from(decEl.options).forEach(opt => {
          if (opt.value !== '00') opt.disabled = true;
        });
      } else {
        Array.from(decEl.options).forEach(opt => opt.disabled = false);
      }
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    setupSelectListeners('breakfast-int', 'breakfast-dec');
    setupSelectListeners('lunch-int', 'lunch-dec');
    setupSelectListeners('dinner-int', 'dinner-dec');
  });

  function applyMealValues(values) {
'''

content = content.replace(old_script, new_script)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
