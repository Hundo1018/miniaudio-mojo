"""Tests for the example scene's one-shot voices (examples/web/scene.mojo): registered clips, overlap,
the voice limit, and that a scene which never calls play() renders what it did before.

Built with `-I examples/web` (see `pixi run test-scene-voices`)."""

from std.testing import assert_equal, assert_true, assert_raises, TestSuite

from scene import Scene, MAX_VOICES

comptime RATE: UInt32 = 48000


def _square(frames: Int, period: Int, amp: Float32) -> List[Float32]:
    """Stereo square wave, exact values: every sample is +amp or -amp."""
    var out = List[Float32](capacity=frames * 2)
    for i in range(frames):
        var v = amp if (i // (period // 2)) % 2 == 0 else -amp
        out.append(v)
        out.append(v)
    return out^


def _render(mut scene: Scene, frames: Int) raises -> List[Float32]:
    var all = List[Float32]()
    var buf = List[Float32]()
    var done = 0
    while done < frames:
        var n = min(128, frames - done)
        scene.render(buf, UInt64(n))
        for x in buf:
            all.append(x)
        done += n
    return all^


def _peak(pcm: List[Float32]) -> Float32:
    var p = Float32(0)
    for v in pcm:
        p = max(p, abs(v))
    return p


def _same(a: List[Float32], b: List[Float32]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def test_a_scene_with_registered_clips_is_silent_until_play() raises:
    var scene = Scene(RATE)
    var id = scene.add_clip_pcm(_square(480, 48, 0.5))
    assert_equal(id, 0)
    assert_equal(scene.clip_count(), 1)
    assert_equal(_peak(_render(scene, 1024)), Float32(0))
    assert_equal(scene.active_voices(), 0)


def test_play_is_heard_and_ends() raises:
    var scene = Scene(RATE)
    var id = scene.add_clip_pcm(_square(480, 48, 0.5))
    scene.play(id)
    assert_equal(scene.active_voices(), 1)
    var first = _render(scene, 256)
    assert_true(_peak(first) > 0.49 and _peak(first) < 0.51)
    _ = _render(scene, 1024)  # the clip is 480 frames long
    assert_equal(scene.active_voices(), 0)
    assert_equal(_peak(_render(scene, 256)), Float32(0))


def test_gain_scales_the_voice() raises:
    var scene = Scene(RATE)
    var id = scene.add_clip_pcm(_square(480, 48, 0.5))
    scene.play(id, 0.5)
    var p = _peak(_render(scene, 256))
    assert_true(p > 0.24 and p < 0.26)


def test_the_same_clip_overlaps_itself() raises:
    var scene = Scene(RATE)
    var id = scene.add_clip_pcm(_square(4800, 48, 0.25))
    scene.play(id)
    scene.play(id)
    assert_equal(scene.active_voices(), 2)
    var p = _peak(_render(scene, 256))
    assert_true(p > 0.49 and p < 0.51)  # two in-phase voices of 0.25


def test_two_clips_get_two_ids() raises:
    var scene = Scene(RATE)
    var a = scene.add_clip_pcm(_square(480, 48, 0.5))
    var b = scene.add_clip_pcm(_square(480, 96, 0.25))
    assert_equal(a, 0)
    assert_equal(b, 1)
    scene.play(b)
    var p = _peak(_render(scene, 256))
    assert_true(p > 0.24 and p < 0.26)


def test_more_plays_than_voices_replaces_the_oldest() raises:
    var scene = Scene(RATE)
    var id = scene.add_clip_pcm(_square(48000, 48, 0.01))
    for _ in range(MAX_VOICES + 5):
        scene.play(id)
    assert_equal(scene.active_voices(), MAX_VOICES)
    var p = _peak(_render(scene, 256))
    assert_true(p < Float32(MAX_VOICES) * 0.01 + 0.001)


def test_the_same_plays_render_the_same_samples() raises:
    var a = Scene(RATE)
    var b = Scene(RATE)
    var ia = a.add_clip_pcm(_square(2000, 48, 0.3))
    var ib = b.add_clip_pcm(_square(2000, 48, 0.3))
    a.set_tone(220.0, 0.25)
    b.set_tone(220.0, 0.25)
    a.play(ia)
    b.play(ib)
    var pa = _render(a, 700)
    var pb = _render(b, 700)
    a.play(ia, 0.5)
    b.play(ib, 0.5)
    var pa2 = _render(a, 700)
    var pb2 = _render(b, 700)
    assert_true(_same(pa, pb))
    assert_true(_same(pa2, pb2))


def test_never_calling_play_leaves_the_output_unchanged() raises:
    """The tone alone, with and without registered clips: the voices add nothing until one plays."""
    var plain = Scene(RATE)
    var with_clips = Scene(RATE)
    _ = with_clips.add_clip_pcm(_square(480, 48, 0.5))
    plain.set_tone(330.0, 0.2)
    with_clips.set_tone(330.0, 0.2)
    assert_true(_same(_render(plain, 1000), _render(with_clips, 1000)))


def test_bad_arguments() raises:
    var scene = Scene(RATE)
    with assert_raises(contains="unknown clip id"):
        scene.play(0)
    with assert_raises(contains="whole number of stereo frames"):
        _ = scene.add_clip_pcm(List[Float32]())
    var odd: List[Float32] = [0.1, 0.2, 0.3]
    with assert_raises(contains="whole number of stereo frames"):
        _ = scene.add_clip_pcm(odd)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
