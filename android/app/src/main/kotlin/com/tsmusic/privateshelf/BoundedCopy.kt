package com.tsmusic.privateshelf

import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

/** SAFコピーの上限検査。ストリームの開閉とflushは呼出元が所有する。 */
internal fun copyWithinLimit(input: InputStream, output: OutputStream, maxBytes: Long) {
    require(maxBytes >= 0) { "Copy size limit must not be negative" }
    val buffer = ByteArray(8192)
    var copiedBytes = 0L
    while (true) {
        val readBytes = input.read(buffer)
        if (readBytes < 0) return
        if (readBytes == 0) throw IOException("Source made no progress")
        // 加算前に検査し、上限超過とLongの桁あふれを防ぐ。
        if (readBytes.toLong() > maxBytes - copiedBytes) {
            throw IOException("Source exceeds the copy size limit")
        }
        output.write(buffer, 0, readBytes)
        copiedBytes += readBytes
    }
}
