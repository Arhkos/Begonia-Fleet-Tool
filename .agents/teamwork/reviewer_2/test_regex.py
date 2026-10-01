import re

content = open('dandelion_tool/dandelion_tool.ps1', 'r', encoding='utf-8').read()
p1 = r'switch\s*\(\$choice\)'
p2 = r'Show-Menu'
p3 = r'seccfg|Bootloader'
p4 = r'recovery|vbmeta'
p5 = r'ROM|Root'

m1 = bool(re.search(p1, content) or re.search(p2, content))
m2 = bool(re.search(p3, content) and re.search(p4, content) and re.search(p5, content))

print('p1 match:', bool(re.search(p1, content)))
print('p2 match:', bool(re.search(p2, content)))
print('p3 match:', bool(re.search(p3, content)))
print('p4 match:', bool(re.search(p4, content)))
print('p5 match:', bool(re.search(p5, content)))
print('Combined result:', m1 and m2)
