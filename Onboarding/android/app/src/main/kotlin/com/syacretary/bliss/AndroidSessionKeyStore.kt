package com.syacretary.bliss

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import android.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec

/** Wraps the app's random AES session key with a non-exportable Android Keystore key. */
internal class AndroidSessionKeyStore(context: Context) {
    private val file = AtomicFile(File(context.noBackupFilesDir, "bliss-session-key.bin"))

    fun getOrCreateBase64Key(): String {
        val keystore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val wrappingKey = if (keystore.containsAlias(KEY_ALIAS)) {
            keystore.getKey(KEY_ALIAS, null) as java.security.Key
        } else {
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
                init(
                    KeyGenParameterSpec.Builder(
                        KEY_ALIAS,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                    ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setRandomizedEncryptionRequired(true)
                        .build(),
                )
                generateKey()
            }
        }

        val secret = if (file.baseFile.exists()) {
            val sealed = file.readFully()
            require(sealed.size > IV_LENGTH) { "Stored session-key envelope is invalid." }
            val iv = sealed.copyOfRange(0, IV_LENGTH)
            val ciphertext = sealed.copyOfRange(IV_LENGTH, sealed.size)
            Cipher.getInstance(TRANSFORMATION).run {
                init(Cipher.DECRYPT_MODE, wrappingKey, GCMParameterSpec(TAG_BITS, iv))
                doFinal(ciphertext)
            }
        } else {
            ByteArray(KEY_LENGTH).also { SecureRandom().nextBytes(it) }.also { raw ->
                val cipher = Cipher.getInstance(TRANSFORMATION)
                cipher.init(Cipher.ENCRYPT_MODE, wrappingKey)
                val envelope = cipher.iv + cipher.doFinal(raw)
                val output = file.startWrite()
                try {
                    output.write(envelope)
                    file.finishWrite(output)
                } catch (error: Throwable) {
                    file.failWrite(output)
                    throw error
                }
            }
        }
        require(secret.size == KEY_LENGTH) { "Stored session-key length is invalid." }
        return Base64.encodeToString(secret, Base64.NO_WRAP)
    }

    private companion object {
        const val KEY_ALIAS = "bliss.whatsapp.session.wrapper.v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_LENGTH = 32
        const val IV_LENGTH = 12
        const val TAG_BITS = 128
    }
}
