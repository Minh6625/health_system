import sys
import re

file_path = 'c:/Dev/Project2/health_system/lib/features/family/screens/search_user_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

# I will use a Regex to match the onPressed for the accept button.

pattern = re.compile(r'onPressed:\s*\(\)\s*async\s*\{\s*setState\(\(\)\s*\{\s*_acceptedRelationshipIds\.add\((.*?)\);\s*\}\);\s*await\s+(provider|targetProvider)\.acceptRequest\(\s*\1,\s*background:\s*true,\s*\);\s*if\s*\(mounted\)\s*\{\s*setState\(\(\)\s*\{\s*_acceptedRelationshipIds\.remove\(\1\);\s*\}\);\s*widget\.onSwitchTab\?\.call\(\);\s*\}\s*\},', re.DOTALL)

def repl(m):
    rel_id = m.group(1)
    prov = m.group(2)
    return f'''onPressed: () {{
                                setState(() {{
                                  _acceptedRelationshipIds.add({rel_id});
                                }});
                                widget.onSwitchTab?.call();
                                {prov}.acceptRequest(
                                  {rel_id},
                                  background: true,
                                ).then((_) {{
                                  if (mounted) {{
                                    setState(() {{
                                      _acceptedRelationshipIds.remove({rel_id});
                                    }});
                                  }}
                                }});
                              }},'''

new_text = pattern.sub(repl, text)
print(f'Replaced {len(pattern.findall(text))} instances using regex.')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_text)
