import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      
      content = content.replaceAll(RegExp(r'\$1\.(fromLTRB|symmetric|only|all)(?=\()'), r'EdgeInsets.$1');
      content = content.replaceAllMapped(RegExp(r'(decoration:\s*)\$1\('), (m) => '${m[1]}BoxDecoration(');
      content = content.replaceAllMapped(RegExp(r'(style:\s*)\$1\('), (m) => '${m[1]}TextStyle(');
      content = content.replaceAll(RegExp(r'\$1\(\s*Icons\.'), r'Icon(Icons.');
      content = content.replaceAll(RegExp(r"\$1\(\s*'"), r"Text('");
      content = content.replaceAll(RegExp(r'\$1\(\s*"'), r'Text("');
      content = content.replaceAll(RegExp(r'\$1\(\s*0x'), r'Color(');
      content = content.replaceAllMapped(RegExp(r'(valueColor:\s*)\$1\('), (m) => '${m[1]}AlwaysStoppedAnimation(');
      content = content.replaceAllMapped(RegExp(r'(errorBuilder:[^>]+>\s*)\$1\('), (m) => '${m[1]}CircleAvatar(');
      content = content.replaceAll(RegExp(r'return\s+\$1\('), r'return _GoalColors(');
      content = content.replaceAllMapped(RegExp(r'(borderSide:\s*|border:\s*Border\.all\([^)]*)\$1\('), (m) => '${m[1]}BorderSide(');
      content = content.replaceAllMapped(RegExp(r'(gradient:\s*)\$1\('), (m) => '${m[1]}LinearGradient(');
      content = content.replaceAllMapped(RegExp(r'(border:\s*)\$1\('), (m) => '${m[1]}Border(');
      content = content.replaceAll(RegExp(r'\$1\(\s*heightFactor:'), r'FractionallySizedBox(heightFactor:');
      content = content.replaceAll(RegExp(r'\$1\(\s*padding:'), r'Padding(padding:');
      
      content = content.replaceAll(RegExp(r'\$1\((?=\s*height:|\s*color:|\s*thickness:|\s*\))'), r'Divider(');
      
      file.writeAsStringSync(content);
    }
  }
}
