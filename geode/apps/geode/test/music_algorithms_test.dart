import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:geode/media/music_lyrics.dart';
import 'package:geode/media/music_models.dart';
import 'package:geode/media/shuffle_order.dart';

void main() {
  group('shuffle navigation', () {
    test('visits each queue entry once and stops with repeat disabled', () {
      final order = ShuffleOrder(random: Random(27))..reset(12, 4);
      final played = <int>[4];
      while (order.hasNext) {
        played.add(order.next(repeatAll: false)!);
      }
      expect(played.length, 12);
      expect(played.toSet(), List.generate(12, (index) => index).toSet());
      expect(order.next(repeatAll: false), isNull);
    });

    test('previous and next follow listening history', () {
      final order = ShuffleOrder(random: Random(4))..reset(6, 2);
      final first = order.next(repeatAll: false);
      final second = order.next(repeatAll: false);
      expect(order.previous(), first);
      expect(order.previous(), 2);
      expect(order.previous(), isNull);
      expect(order.next(repeatAll: false), first);
      expect(order.next(repeatAll: false), second);
    });

    test('repeat starts a fresh cycle without immediately repeating a song', () {
      final order = ShuffleOrder(random: Random(3))..reset(4, 0);
      var last = 0;
      for (var i = 0; i < 20; i++) {
        final next = order.next(repeatAll: true)!;
        expect(next, isNot(last));
        last = next;
      }
      final single = ShuffleOrder()..reset(1, 0);
      expect(single.next(repeatAll: false), isNull);
      expect(single.next(repeatAll: true), 0);
      single.reset(0, -1);
      expect(single.next(repeatAll: true), isNull);
    });
  });

  group('lyrics', () {
    test('expands chorus timestamps, sorts them and applies global offset', () {
      final lines = parseLyrics('[ar:Artist]\n[offset:+500]\n'
          '[00:30.00][00:10.00]Chorus\n[00:01.5]Opening');
      expect(lines.map((line) => line.text), ['Opening', 'Chorus', 'Chorus']);
      expect(lines.map((line) => line.time!.inMilliseconds), [1000, 9500, 29500]);
      expect(activeLyricIndex(lines, const Duration(seconds: 9)), 0);
      expect(activeLyricIndex(lines, const Duration(seconds: 10)), 1);
    });

    test('keeps plain text and blank timed lines that clear a lyric', () {
      expect(parseLyrics('First\n\nSecond').map((line) => line.text), ['First', 'Second']);
      final lines = parseLyrics('[00:01]Sung\n[00:02]\n[00:03]Next');
      expect(lines[1].text, isEmpty);
      expect(activeLyricIndex(lines, const Duration(milliseconds: 2500)), 1);
      expect(activeLyricIndex(lines, Duration.zero), -1);
    });

    test('negative offsets delay lyrics and invalid seconds are ignored', () {
      final lines = parseLyrics('[offset:-250]\n[00:00.01]Begin\n[00:99]Invalid');
      expect(lines, hasLength(1));
      expect(lines.single.time, const Duration(milliseconds: 260));
    });
  });

  test('track edits and persistence preserve artwork and loudness tags', () {
    const source = MusicTrack(id: 'track', path: '/owned/audio.flac', title: 'Song',
      addedAt: 100, artPath: '/owned/art.jpg', trackGainDb: -6.25,
      trackPeak: 0.97, albumGainDb: -5, albumPeak: 0.99);
    final restored = MusicTrack.fromJson(source.copyWith(title: 'Edited').toJson());
    expect(restored.title, 'Edited');
    expect(restored.path, source.path);
    expect(restored.artPath, source.artPath);
    expect(restored.trackGainDb, -6.25);
    expect(restored.albumPeak, 0.99);
  });
}
