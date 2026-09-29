package com.illyaaaaaa.timemanager

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/** Decodes a short selected span to 16-bit PCM WAV without an FFmpeg dependency. */
internal class AudioTrimHandler(private val activity: MainActivity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "timemanager/audio_trim").setMethodCallHandler { call, result ->
            val input = call.argument<String>("inputPath")
            if (input == null || !isWithin(input, activity.cacheDir)) {
                result.error("INVALID_INPUT", "Audio input is unavailable", null)
                return@setMethodCallHandler
            }
            Thread {
                try {
                    when (call.method) {
                        "probe" -> {
                            val duration = probe(input)
                            activity.runOnUiThread { result.success(duration) }
                        }
                        "trim" -> {
                            val output = call.argument<String>("outputPath")
                            val start = call.argument<Int>("startMs")
                            val end = call.argument<Int>("endMs")
                            if (output == null || !isWithin(output, activity.filesDir) ||
                                start == null || end == null || start < 0 ||
                                end <= start || end - start > 30000) {
                                throw IllegalArgumentException("Invalid trim interval")
                            }
                            trim(input, output, start.toLong() * 1000, end.toLong() * 1000)
                            activity.runOnUiThread { result.success(null) }
                        }
                        else -> activity.runOnUiThread { result.notImplemented() }
                    }
                } catch (error: Exception) {
                    activity.runOnUiThread {
                        result.error("AUDIO_UNAVAILABLE", "This audio file cannot be used", null)
                    }
                }
            }.start()
        }
    }

    private fun isWithin(path: String, root: File): Boolean =
        File(path).canonicalPath.startsWith(root.canonicalPath + File.separator)

    private fun audioTrack(extractor: MediaExtractor): Pair<Int, MediaFormat> {
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            if (format.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                return index to format
            }
        }
        throw IllegalArgumentException("No audio track")
    }

    private fun probe(input: String): Int {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(input)
            val (_, format) = audioTrack(extractor)
            val durationUs = format.getLong(MediaFormat.KEY_DURATION)
            if (durationUs < 1_000_000 || durationUs > Int.MAX_VALUE.toLong() * 1000) {
                throw IllegalArgumentException("Invalid duration")
            }
            return (durationUs / 1000).toInt()
        } finally {
            extractor.release()
        }
    }

    private fun trim(input: String, output: String, startUs: Long, endUs: Long) {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        val destination = File(output)
        try {
            extractor.setDataSource(input)
            val (track, format) = audioTrack(extractor)
            val durationUs = format.getLong(MediaFormat.KEY_DURATION)
            if (endUs > durationUs + 1000) throw IllegalArgumentException("End past duration")
            extractor.selectTrack(track)
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            val mime = format.getString(MediaFormat.KEY_MIME)!!
            RandomAccessFile(destination, "rw").use { file ->
                file.setLength(44)
                file.seek(44)
                var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                var encoding = AudioFormat.ENCODING_PCM_16BIT
                if (mime == "audio/raw") {
                    if (format.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                        encoding = format.getInteger(MediaFormat.KEY_PCM_ENCODING)
                    }
                    if (encoding != AudioFormat.ENCODING_PCM_16BIT &&
                        encoding != AudioFormat.ENCODING_PCM_8BIT &&
                        encoding != AudioFormat.ENCODING_PCM_FLOAT) {
                        throw IllegalArgumentException("Unsupported PCM format")
                    }
                    val sample = ByteBuffer.allocate(256 * 1024)
                    while (true) {
                        sample.clear()
                        val size = extractor.readSampleData(sample, 0)
                        if (size < 0 || extractor.sampleTime >= endUs) break
                        appendPcm(file, sample, 0, size, extractor.sampleTime,
                            sampleRate, channels, encoding, startUs, endUs)
                        if (!extractor.advance()) break
                    }
                } else {
                    codec = MediaCodec.createDecoderByType(mime)
                    codec.configure(format, null, null, 0)
                    codec.start()
                    val info = MediaCodec.BufferInfo()
                    var inputDone = false
                    var outputDone = false
                    var attempts = 0
                    while (!outputDone && attempts++ < 20000) {
                        if (!inputDone) {
                            val index = codec.dequeueInputBuffer(10000)
                            if (index >= 0) {
                                val buffer = codec.getInputBuffer(index)!!
                                buffer.clear()
                                val size = extractor.readSampleData(buffer, 0)
                                if (size < 0) {
                                    codec.queueInputBuffer(index, 0, 0, 0,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                    inputDone = true
                                } else {
                                    codec.queueInputBuffer(index, 0, size,
                                        max(0L, extractor.sampleTime), 0)
                                    extractor.advance()
                                }
                            }
                        }
                        val index = codec.dequeueOutputBuffer(info, 10000)
                        if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                            val decoded = codec.outputFormat
                            channels = decoded.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                            sampleRate = decoded.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                            encoding = if (decoded.containsKey(MediaFormat.KEY_PCM_ENCODING))
                                decoded.getInteger(MediaFormat.KEY_PCM_ENCODING)
                            else AudioFormat.ENCODING_PCM_16BIT
                        } else if (index >= 0) {
                            if (info.size > 0) {
                                appendPcm(file, codec.getOutputBuffer(index)!!, info.offset,
                                    info.size, info.presentationTimeUs, sampleRate, channels,
                                    encoding, startUs, endUs)
                            }
                            outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0 ||
                                info.presentationTimeUs >= endUs
                            codec.releaseOutputBuffer(index, false)
                        }
                    }
                    if (attempts >= 20000) throw IllegalStateException("Audio decode timeout")
                }
                val dataSize = file.length() - 44
                if (dataSize <= 0) throw IllegalArgumentException("Empty selection")
                writeWavHeader(file, dataSize, sampleRate, channels)
            }
        } catch (error: Exception) {
            destination.delete()
            throw error
        } finally {
            try { codec?.stop() } catch (_: Exception) { }
            codec?.release()
            extractor.release()
        }
    }

    private fun appendPcm(
        output: RandomAccessFile, buffer: ByteBuffer, offset: Int, size: Int,
        presentationUs: Long, sampleRate: Int, channels: Int, encoding: Int,
        startUs: Long, endUs: Long,
    ) {
        val bytesPerSample = when (encoding) {
            AudioFormat.ENCODING_PCM_8BIT -> 1
            AudioFormat.ENCODING_PCM_16BIT -> 2
            AudioFormat.ENCODING_PCM_FLOAT -> 4
            else -> throw IllegalArgumentException("Unsupported decoded PCM")
        }
        val frameSize = channels * bytesPerSample
        val frames = size / frameSize
        val first = max(0, ceil((startUs - presentationUs).toDouble() * sampleRate / 1_000_000).toInt())
        val last = min(frames, ceil((endUs - presentationUs).toDouble() * sampleRate / 1_000_000).toInt())
        if (last <= first) return
        val slice = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        slice.position(offset + first * frameSize)
        slice.limit(offset + last * frameSize)
        if (encoding == AudioFormat.ENCODING_PCM_16BIT) {
            val data = ByteArray(slice.remaining())
            slice.get(data)
            output.write(data)
        } else if (encoding == AudioFormat.ENCODING_PCM_8BIT) {
            while (slice.hasRemaining()) {
                val value = ((slice.get().toInt() and 0xff) - 128) shl 8
                output.write(value and 0xff)
                output.write((value ushr 8) and 0xff)
            }
        } else {
            while (slice.remaining() >= 4) {
                val value = (slice.float.coerceIn(-1f, 1f) * 32767).toInt()
                output.write(value and 0xff)
                output.write((value ushr 8) and 0xff)
            }
        }
    }

    private fun writeWavHeader(file: RandomAccessFile, dataSize: Long, rate: Int, channels: Int) {
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt((36 + dataSize).toInt())
        header.put("WAVEfmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16)
        header.putShort(1)
        header.putShort(channels.toShort())
        header.putInt(rate)
        header.putInt(rate * channels * 2)
        header.putShort((channels * 2).toShort())
        header.putShort(16)
        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(dataSize.toInt())
        file.seek(0)
        file.write(header.array())
    }
}
