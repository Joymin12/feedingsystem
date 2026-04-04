package com.feedingsystem.tmr

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.feedingsystem.tmr.ui.HanwooTmrApp
import com.feedingsystem.tmr.ui.theme.HanwooTmrTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        /**
         * Compose 단일 Activity 진입점.
         * 화면 흐름과 API 연동은 HanwooTmrApp + TmrViewModel에 모은다.
         */
        setContent {
            HanwooTmrTheme {
                HanwooTmrApp()
            }
        }
    }
}