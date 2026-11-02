package com.tsmusic.privateshelf

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import org.junit.Assert.*
import org.junit.Test

class BoundedCopyTest {
    @Test fun emptySourceWithZeroLimit() {
        val output = ByteArrayOutputStream()
        copyWithinLimit(ByteArrayInputStream(byteArrayOf()), output, 0)
        assertEquals(0, output.size())
    }

    @Test fun exactLimitAcrossBuffers() {
        val data = ByteArray(20000) { (it % 251).toByte() }
        val output = ByteArrayOutputStream()
        copyWithinLimit(ByteArrayInputStream(data), output, data.size.toLong())
        assertArrayEquals(data, output.toByteArray())
    }

    @Test fun oversizedFirstReadDoesNotWrite() {
        val output = ByteArrayOutputStream()
        assertThrows(IOException::class.java) {
            copyWithinLimit(ByteArrayInputStream(byteArrayOf(1)), output, 0)
        }
        assertEquals(0, output.size())
    }

    @Test fun oversizedLaterReadKeepsOnlyAllowedPrefix() {
        val data = ByteArray(8194) { 42 }
        val output = ByteArrayOutputStream()
        assertThrows(IOException::class.java) {
            copyWithinLimit(ByteArrayInputStream(data), output, 8193)
        }
        assertArrayEquals(data.copyOf(8192), output.toByteArray())
    }

    @Test fun negativeLimitRejectedBeforeReading() {
        val input = ByteArrayInputStream(byteArrayOf(1))
        assertThrows(IllegalArgumentException::class.java) {
            copyWithinLimit(input, ByteArrayOutputStream(), -1)
        }
        assertEquals(1, input.available())
    }

    @Test fun readFailurePropagates() {
        val failure = IOException("test read failure")
        val input = object : InputStream() {
            override fun read(): Int = throw failure
        }
        assertSame(failure, assertThrows(IOException::class.java) {
            copyWithinLimit(input, ByteArrayOutputStream(), 100)
        })
    }

    @Test fun writeFailurePropagates() {
        val failure = IOException("test write failure")
        val output = object : OutputStream() {
            override fun write(value: Int) { throw failure }
        }
        assertSame(failure, assertThrows(IOException::class.java) {
            copyWithinLimit(ByteArrayInputStream(byteArrayOf(1)), output, 100)
        })
    }

    @Test fun zeroProgressFailsInsteadOfLooping() {
        val input = object : InputStream() {
            override fun read(): Int = error("buffered read only")
            override fun read(buffer: ByteArray, offset: Int, length: Int): Int = 0
        }
        assertThrows(IOException::class.java) {
            copyWithinLimit(input, ByteArrayOutputStream(), 100)
        }
    }
}
