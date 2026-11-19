package com.hyzen.pharmd

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Uses isolated QA keys/files; never touches a student's actual study data. */
@RunWith(AndroidJUnit4::class)
class UpdateRetentionTest {
    @Test fun preferencesAndPrivateFilesSurviveSignedUpdate() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val prefs = context.getSharedPreferences("hyzen_update_qa", 0)
        val file = File(context.filesDir, "hyzen-update-qa.txt")
        if (InstrumentationRegistry.getArguments().getString("phase") == "seed") {
            assertTrue(prefs.edit().putString("sentinel", "upgrade-persistence-sentinel").commit())
            file.writeText("private offline data retained")
        } else {
            assertEquals("upgrade-persistence-sentinel", prefs.getString("sentinel", null))
            assertEquals("private offline data retained", file.readText())
            prefs.edit().clear().commit()
            file.delete()
        }
    }
}
