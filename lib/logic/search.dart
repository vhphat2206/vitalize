/// Vietnamese letters with their marks, by the plain letter they fold to.
const _marked = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final _plain = {
  for (final MapEntry(key: plain, value: letters) in _marked.entries)
    for (final letter in letters.split('')) letter: plain,
};

/// Lower case without the marks, so "pho" finds "Phở": "Bánh Mì" → "banh mi".
String foldVi(String s) => s.toLowerCase().split('').map((c) => _plain[c] ?? c).join();

/// Whether every word of [query] appears in [text], marks and case aside.
bool matchesVi(String text, String query) {
  final haystack = foldVi(text);
  return foldVi(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(haystack.contains);
}
