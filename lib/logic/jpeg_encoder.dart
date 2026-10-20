import 'dart:math' as math;
import 'dart:typed_data';

/// Encodes RGBA pixels (premultiplied over black, as `ImageByteFormat.rawRgba` gives them) as a
/// baseline JFIF JPEG with the standard tables and no chroma subsampling. dart:ui can only encode
/// PNG, which is several times larger for photos; meal thumbnails are kept in local storage, so
/// they are stored as small JPEGs like the web app's canvas `toBlob('image/jpeg')`.
Uint8List encodeJpeg(Uint8List rgba, int width, int height, {int quality = 72}) {
  assert(rgba.length >= width * height * 4, 'expected RGBA pixels');
  return _JpegEncoder(quality.clamp(1, 100)).encode(rgba, width, height);
}

/// Natural (row-major) index of each coefficient in zigzag order.
final Uint8List jpegZigzag = () {
  final out = Uint8List(64);
  var k = 0;
  for (var s = 0; s < 15; s++) {
    final lo = math.max(0, s - 7), hi = math.min(s, 7);
    if (s.isEven) {
      for (var r = hi; r >= lo; r--) {
        out[k++] = r * 8 + (s - r);
      }
    } else {
      for (var r = lo; r <= hi; r++) {
        out[k++] = r * 8 + (s - r);
      }
    }
  }
  return out;
}();

// Base quantisation tables (ITU T.81 annex K.1), natural order.
const _lumaQuant = [
  16, 11, 10, 16, 24, 40, 51, 61, 12, 12, 14, 19, 26, 58, 60, 55, //
  14, 13, 16, 24, 40, 57, 69, 56, 14, 17, 22, 29, 51, 87, 80, 62,
  18, 22, 37, 56, 68, 109, 103, 77, 24, 35, 55, 64, 81, 104, 113, 92,
  49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95, 98, 112, 100, 103, 99,
];

const _chromaQuant = [
  17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99, //
  24, 26, 56, 99, 99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
  99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
];

/// A Huffman table as stored in the file: how many codes of each length 1–16, then the symbols.
class JpegHuffmanSpec {
  const JpegHuffmanSpec(this.counts, this.symbols);

  final List<int> counts;
  final List<int> symbols;
}

// Standard Huffman tables (ITU T.81 annex K.3).
const jpegDcLuma = JpegHuffmanSpec(
  [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0],
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
);

const jpegDcChroma = JpegHuffmanSpec(
  [0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
);

const jpegAcLuma = JpegHuffmanSpec(
  [0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d],
  [
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, //
    0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52,
    0xd1, 0xf0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25,
    0x26, 0x27, 0x28, 0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45,
    0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64,
    0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x83,
    0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99,
    0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
    0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3,
    0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8,
    0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa,
  ],
);

const jpegAcChroma = JpegHuffmanSpec(
  [0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77],
  [
    0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, //
    0x71, 0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33,
    0x52, 0xf0, 0x15, 0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25, 0xf1, 0x17, 0x18,
    0x19, 0x1a, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44,
    0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x63,
    0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a,
    0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97,
    0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4,
    0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca,
    0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7,
    0xe8, 0xe9, 0xea, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa,
  ],
);

/// Codes and lengths per symbol, built the canonical way from a [JpegHuffmanSpec].
class _Huffman {
  _Huffman(JpegHuffmanSpec spec) {
    var code = 0, k = 0;
    for (var len = 1; len <= 16; len++) {
      for (var i = 0; i < spec.counts[len - 1]; i++) {
        final s = spec.symbols[k++];
        codes[s] = code++;
        lengths[s] = len;
      }
      code <<= 1;
    }
  }

  final codes = Int32List(256);
  final lengths = Uint8List(256);
}

/// AAN scale factors for the float DCT (libjpeg jfdctflt.c).
const _aan = [1.0, 1.387039845, 1.306562965, 1.175875602, 1.0, 0.785694958, 0.5411961, 0.275899379];

class _JpegEncoder {
  _JpegEncoder(int quality) {
    final scale = quality < 50 ? 5000 ~/ quality : 200 - quality * 2;
    for (var k = 0; k < 64; k++) {
      final n = jpegZigzag[k];
      _lumaZz[k] = ((_lumaQuant[n] * scale + 50) ~/ 100).clamp(1, 255);
      _chromaZz[k] = ((_chromaQuant[n] * scale + 50) ~/ 100).clamp(1, 255);
    }
    for (var k = 0; k < 64; k++) {
      final n = jpegZigzag[k];
      final f = _aan[n ~/ 8] * _aan[n % 8] * 8;
      _lumaDiv[n] = 1 / (_lumaZz[k] * f);
      _chromaDiv[n] = 1 / (_chromaZz[k] * f);
    }
  }

  final _lumaZz = Uint8List(64);
  final _chromaZz = Uint8List(64);
  final _lumaDiv = Float64List(64);
  final _chromaDiv = Float64List(64);
  final _dcLuma = _Huffman(jpegDcLuma);
  final _acLuma = _Huffman(jpegAcLuma);
  final _dcChroma = _Huffman(jpegDcChroma);
  final _acChroma = _Huffman(jpegAcChroma);

  final _out = BytesBuilder(copy: false);
  final _pending = <int>[];
  int _byte = 0;
  int _free = 8;

  Uint8List encode(Uint8List rgba, int width, int height) {
    _headers(width, height);
    final y = Float64List(64), cb = Float64List(64), cr = Float64List(64);
    var dcY = 0, dcCb = 0, dcCr = 0;
    for (var by = 0; by < height; by += 8) {
      for (var bx = 0; bx < width; bx += 8) {
        for (var i = 0; i < 64; i++) {
          // Blocks past the edge repeat the last row and column.
          final px = math.min(bx + (i & 7), width - 1);
          final py = math.min(by + (i >> 3), height - 1);
          final o = (py * width + px) * 4;
          final r = rgba[o].toDouble(), g = rgba[o + 1].toDouble(), b = rgba[o + 2].toDouble();
          y[i] = 0.299 * r + 0.587 * g + 0.114 * b - 128;
          cb[i] = -0.16874 * r - 0.33126 * g + 0.5 * b;
          cr[i] = 0.5 * r - 0.41869 * g - 0.08131 * b;
        }
        dcY = _block(y, _lumaDiv, dcY, _dcLuma, _acLuma);
        dcCb = _block(cb, _chromaDiv, dcCb, _dcChroma, _acChroma);
        dcCr = _block(cr, _chromaDiv, dcCr, _dcChroma, _acChroma);
      }
    }
    // Pad the last byte with ones, then end of image.
    if (_free < 8) _bits((1 << _free) - 1, _free);
    _flushPending();
    _out.add(const [0xFF, 0xD9]);
    return _out.takeBytes();
  }

  void _headers(int width, int height) {
    void word(List<int> to, int v) => to.addAll([v >> 8 & 0xFF, v & 0xFF]);
    final h = <int>[0xFF, 0xD8];
    // JFIF APP0
    h.addAll([0xFF, 0xE0, 0, 16, 0x4A, 0x46, 0x49, 0x46, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]);
    // quantisation tables, zigzag order
    h.addAll([0xFF, 0xDB, 0, 132, 0]);
    h.addAll(_lumaZz);
    h.add(1);
    h.addAll(_chromaZz);
    // frame: 8-bit, three components, no subsampling
    h.addAll([0xFF, 0xC0, 0, 17, 8]);
    word(h, height);
    word(h, width);
    h.addAll([3, 1, 0x11, 0, 2, 0x11, 1, 3, 0x11, 1]);
    // Huffman tables
    h.addAll([0xFF, 0xC4, 0x01, 0xA2]);
    for (final (id, spec) in [
      (0x00, jpegDcLuma),
      (0x10, jpegAcLuma),
      (0x01, jpegDcChroma),
      (0x11, jpegAcChroma),
    ]) {
      h.add(id);
      h.addAll(spec.counts);
      h.addAll(spec.symbols);
    }
    // scan
    h.addAll([0xFF, 0xDA, 0, 12, 3, 1, 0x00, 2, 0x11, 3, 0x11, 0, 63, 0]);
    _out.add(h);
  }

  /// Transforms, quantises and writes one 8×8 block; returns its DC value for the next one.
  int _block(Float64List d, Float64List div, int prevDc, _Huffman dc, _Huffman ac) {
    _fdct(d);
    final du = Int32List(64);
    for (var k = 0; k < 64; k++) {
      final n = jpegZigzag[k];
      du[k] = (d[n] * div[n]).round().clamp(k == 0 ? -2047 : -1023, k == 0 ? 2047 : 1023);
    }
    final diff = du[0] - prevDc;
    final dcSize = diff.abs().bitLength;
    _symbol(dc, dcSize);
    if (dcSize > 0) _bits(_magnitude(diff, dcSize), dcSize);

    var end = 63;
    while (end > 0 && du[end] == 0) {
      end--;
    }
    var i = 1;
    while (i <= end) {
      var zeros = 0;
      while (du[i] == 0) {
        zeros++;
        i++;
      }
      while (zeros >= 16) {
        _symbol(ac, 0xF0);
        zeros -= 16;
      }
      final size = du[i].abs().bitLength;
      _symbol(ac, (zeros << 4) | size);
      _bits(_magnitude(du[i], size), size);
      i++;
    }
    if (end != 63) _symbol(ac, 0x00);
    return du[0];
  }

  /// Negative values are written as the ones' complement of their magnitude.
  static int _magnitude(int v, int size) => v > 0 ? v : v + (1 << size) - 1;

  void _symbol(_Huffman t, int s) => _bits(t.codes[s], t.lengths[s]);

  void _bits(int value, int length) {
    for (var i = length - 1; i >= 0; i--) {
      _byte = (_byte << 1) | (value >> i & 1);
      if (--_free == 0) {
        _pending.add(_byte);
        // A 0xFF byte in the entropy-coded data is followed by a zero, so it isn't a marker.
        if (_byte == 0xFF) _pending.add(0);
        _byte = 0;
        _free = 8;
        if (_pending.length > 4096) _flushPending();
      }
    }
  }

  void _flushPending() {
    _out.add(Uint8List.fromList(_pending));
    _pending.clear();
  }

  /// Forward DCT, AAN float version (libjpeg jfdctflt.c), rows then columns, in place.
  static void _fdct(Float64List d) {
    for (var pass = 0; pass < 2; pass++) {
      final step = pass == 0 ? 1 : 8;
      for (var line = 0; line < 8; line++) {
        final o = pass == 0 ? line * 8 : line;
        final d0 = d[o], d1 = d[o + step], d2 = d[o + 2 * step], d3 = d[o + 3 * step];
        final d4 = d[o + 4 * step], d5 = d[o + 5 * step], d6 = d[o + 6 * step];
        final d7 = d[o + 7 * step];
        final t0 = d0 + d7, t7 = d0 - d7, t1 = d1 + d6, t6 = d1 - d6;
        final t2 = d2 + d5, t5 = d2 - d5, t3 = d3 + d4, t4 = d3 - d4;

        // even part
        final t10 = t0 + t3, t13 = t0 - t3, t11 = t1 + t2, t12 = t1 - t2;
        d[o] = t10 + t11;
        d[o + 4 * step] = t10 - t11;
        final z1 = (t12 + t13) * 0.707106781;
        d[o + 2 * step] = t13 + z1;
        d[o + 6 * step] = t13 - z1;

        // odd part
        final u10 = t4 + t5, u11 = t5 + t6, u12 = t6 + t7;
        final z5 = (u10 - u12) * 0.382683433;
        final z2 = 0.5411961 * u10 + z5;
        final z4 = 1.306562965 * u12 + z5;
        final z3 = u11 * 0.707106781;
        final z11 = t7 + z3, z13 = t7 - z3;
        d[o + 5 * step] = z13 + z2;
        d[o + 3 * step] = z13 - z2;
        d[o + step] = z11 + z4;
        d[o + 7 * step] = z11 - z4;
      }
    }
  }
}
