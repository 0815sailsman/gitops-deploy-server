package software.say

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

object HmacVerifier {
    fun isValidSha256Signature(
        payload: ByteArray,
        providedSignature: String?,
        secret: String
    ): Boolean {
        if (providedSignature == null || !providedSignature.startsWith("sha256=")) return false

        val expected = computeHmacSha256(payload, secret)
        val provided = providedSignature.removePrefix("sha256=")

        return constantTimeEquals(expected, provided)
    }

    private fun computeHmacSha256(payload: ByteArray, secret: String): String {
        val keySpec = SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256")
        val mac = Mac.getInstance("HmacSHA256").apply { init(keySpec) }
        val hash = mac.doFinal(payload)
        return hash.joinToString("") { "%02x".format(it) }
    }

    // Mitigate timing attacks
    private fun constantTimeEquals(a: String, b: String): Boolean {
        if (a.length != b.length) return false
        var result = 0
        for (i in a.indices) {
            result = result or (a[i].code xor b[i].code)
        }
        return result == 0
    }
}
