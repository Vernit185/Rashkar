import os

path = os.path.join('apps', 'mobile', 'lib', 'main.dart')
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

import_stmts = (
    "import 'package:cropnet_mobile/shared/theme/rashkar_theme.dart';\n"
    "import 'package:cropnet_mobile/shared/theme/rashkar_tokens.dart';\n"
    "import 'package:cropnet_mobile/shared/theme/rashkar_components.dart';\n"
)

if 'rashkar_theme.dart' not in content:
    content = import_stmts + content

old_block = """      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFFE65100),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),"""

new_block = "      theme: RashkarTheme.theme,"

content_norm = content.replace('\r\n', '\n')
old_block_norm = old_block.replace('\r\n', '\n')

if old_block_norm in content_norm:
    content_norm = content_norm.replace(old_block_norm, new_block, 1)
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(content_norm)
    print("SUCCESS: Updated main.dart theme to RashkarTheme.theme")
else:
    print("ERROR: old_block not found in main.dart")
