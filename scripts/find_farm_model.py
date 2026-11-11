import glob

files = glob.glob('services/**/*.py', recursive=True)
for f in files:
    c = open(f, 'r', encoding='utf-8', errors='ignore').read()
    if "__tablename__ = 'farms'" in c or '__tablename__ = "farms"' in c:
        print('Found table farms in:', f)
