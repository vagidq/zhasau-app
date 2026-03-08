import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      
      // Fix Color(FF to Color(0xFF
      content = content.replaceAll(r'Color(FF', r'Color(0xFF');
      
      // Fix decoration: BoxDecoration( inside TextField to InputDecoration
      content = content.replaceAllMapped(RegExp(r'(decoration:\s*)BoxDecoration\(([^)]*hintText[^)]*)\)'), (m) => '${m[1]}InputDecoration(${m[2]})');
      content = content.replaceAllMapped(RegExp(r'(decoration:\s*)BoxDecoration\(([^)]*filled[^)]*)\)'), (m) => '${m[1]}InputDecoration(${m[2]})');
      
      // Fix side: Divider( to side: BorderSide(
      content = content.replaceAll(r'side: Divider(', r'side: BorderSide(');
      
      // Fix settings_screen _GoalColors back to Divider
      if (file.path.contains('settings_screen.dart')) {
        content = content.replaceAll(r'return _GoalColors(', r'return Divider(');
      }
      
      // Fix create_task_screen $1(
      if (file.path.contains('create_task_screen.dart')) {
        // Line 255: child: $1( probably Row
        content = content.replaceAllMapped(RegExp(r'(child:\s*)\$1\('), (m) => '${m[1]}Row(');
      }
      if (file.path.contains('goal_detail_screen.dart')) {
        // Line 130: $1( probably Row inside CircularProgressIndicator?
        // Wait, 130 is 
        content = content.replaceAll(r'$1(', r'Row(');
      }
      if (file.path.contains('goal_card_horizontal.dart') || file.path.contains('goal_card_vertical.dart')) {
         // Fix _GoalColors issue:
         // class _GoalColors { final Color bg; ... }
         // 81:3 - '$1' must have a method body because '_GoalColors' isn't abstract.
         // Ah! I replaced `const _GoalColors({` with `$1({` ?
         // My original script: `content.replaceAll(r'const\s+(...|_GoalColors)\b', r'$1')`.
         // So `const _GoalColors` became `$1`.
         // Thus `const _GoalColors({required this.bg, ...` became `$1({required this.bg, ...`.
         content = content.replaceAll(r'$1({', r'_GoalColors({');
      }

      file.writeAsStringSync(content);
    }
  }
}
