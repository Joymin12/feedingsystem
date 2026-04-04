package com.feedingsystem.tmr.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val HanwooColorScheme = lightColorScheme(
    primary = Color(0xFF48714F),
    onPrimary = Color.White,
    secondary = Color(0xFFEC8735),
    background = Color(0xFFF9F7F3),
    surface = Color(0xFFFFFDFC),
    onSurface = Color(0xFF342B22)
)

@Composable
fun HanwooTmrTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = HanwooColorScheme,
        content = content
    )
}