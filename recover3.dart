import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      
      content = content.replaceAll(RegExp(r'\$1\((?=\s*bg:)'), r'_GoalColors(');
      
      content = content.replaceAllMapped(RegExp(r'EdgeInsets\.\$1\(([^)]*)\)'), (m) {
        var args = m[1]!;
        if (args.contains('top:') || args.contains('bottom:') || args.contains('left:') || args.contains('right:')) {
           return 'EdgeInsets.only($args)';
        }
        if (args.contains('horizontal:') || args.contains('vertical:')) {
           return 'EdgeInsets.symmetric($args)';
        }
        if (args.split(',').length == 4 && !args.contains(':')) {
           return 'EdgeInsets.fromLTRB($args)';
        }
        return 'EdgeInsets.all($args)';
      });

      content = content.replaceAllMapped(RegExp(r'(child:\s*)\$1\('), (m) => '${m[1]!}Row(');
      content = content.replaceAllMapped(RegExp(r'(children:\s*\[\s*)\$1\('), (m) => '${m[1]!}Row(');
      content = content.replaceAllMapped(RegExp(r'(textStyle:\s*)\$1\('), (m) => '${m[1]!}TextStyle(');
      content = content.replaceAll(r'EdgeInsets.$1', r'EdgeInsets.all');
      
      file.writeAsStringSync(content);
    }
  }
}
