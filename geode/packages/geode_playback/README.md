# Geode playback

`GeodePlayer` connects Flutter transport to the original C++ Android player:
AMediaCodec decoding, resampling, Oboe output, DSP, and its PCM analysis tap.
All Android playback and visual analysis use this single audio pipeline.

The adapter filters snapshots by source token and waits for native decoder
readiness before returning from a file load. Dart's music controller owns queue,
repeat, shuffle, A–B loop, sleep timer and persistence. MediaSession actions feed
back into that same controller; metadata is published to the Android service.
Audio imports read title, artist, album and duration through native TagLib.

The native 10-band equalizer uses the existing DSP implementation. Independent
speed and pitch are not implemented by that C++ player, so Android controls do
not claim support. Other supported platforms retain just_audio playback.
