import 'package:file_picker/file_picker.dart';

void main() async {
  await FilePicker.platform.saveFile(fileName: 'test.txt');
}
