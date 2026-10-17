package com.zliveremote.android

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContent {
            val remote: LiveRemoteViewModel = viewModel()
            val context = LocalContext.current

            val permissions = remember {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    arrayOf(
                        Manifest.permission.BLUETOOTH_SCAN,
                        Manifest.permission.BLUETOOTH_CONNECT
                    )
                } else {
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
                }
            }

            val launcher = rememberLauncherForActivityResult(
                ActivityResultContracts.RequestMultiplePermissions()
            ) { result ->
                if (result.values.all { it }) {
                    remote.startRemoteConnection()
                }
            }

            LaunchedEffect(Unit) {
                val granted = permissions.all {
                    ContextCompat.checkSelfPermission(
                        context,
                        it
                    ) == PackageManager.PERMISSION_GRANTED
                }

                if (granted) {
                    remote.startRemoteConnection()
                } else {
                    launcher.launch(permissions)
                }
            }

            ZLiveRemoteApp(remote)
        }
    }
}

private data class Palette(
    val background: Color,
    val surface: Color,
    val surfaceSecondary: Color,
    val line: Color,
    val text: Color,
    val muted: Color,
    val accent: Color,
    val ready: Color,
    val playing: Color,
    val danger: Color
)

private fun palette(dark: Boolean): Palette =
    if (dark) {
        Palette(
            background = Color(0xFF1B1B1A),
            surface = Color(0xFF242423),
            surfaceSecondary = Color(0xFF2D2D2B),
            line = Color(0xFF3D3D3A),
            text = Color(0xFFF2F2EF),
            muted = Color(0xFFA5A59F),
            accent = Color(0xFFFF6A00),
            ready = Color(0xFFFF9500),
            playing = Color(0xFF32D583),
            danger = Color(0xFFFF453A)
        )
    } else {
        Palette(
            background = Color(0xFFF2F2EF),
            surface = Color.White,
            surfaceSecondary = Color(0xFFE9E9E5),
            line = Color(0xFFD4D4CF),
            text = Color(0xFF171717),
            muted = Color(0xFF6E6E69),
            accent = Color(0xFFF45C00),
            ready = Color(0xFFE97F00),
            playing = Color(0xFF10A250),
            danger = Color(0xFFD92D20)
        )
    }

@Composable
private fun ZLiveRemoteApp(remote: LiveRemoteViewModel) {
    var dark by rememberSaveable { mutableStateOf(true) }
    var showSetlist by rememberSaveable { mutableStateOf(false) }
    var showInfo by rememberSaveable { mutableStateOf(false) }
    val p = palette(dark)

    val colors = if (dark) {
        darkColorScheme(
            primary = p.accent,
            background = p.background,
            surface = p.surface
        )
    } else {
        lightColorScheme(
            primary = p.accent,
            background = p.background,
            surface = p.surface
        )
    }

    MaterialTheme(colorScheme = colors) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = p.background
        ) {
            BoxWithConstraints(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 12.dp)
            ) {
                val wide = maxWidth >= 720.dp

                if (wide) {
                    TabletStage(
                        remote = remote,
                        p = p,
                        dark = dark,
                        toggleTheme = { dark = !dark },
                        openInfo = { showInfo = true }
                    )
                } else {
                    PhoneStage(
                        remote = remote,
                        p = p,
                        dark = dark,
                        toggleTheme = { dark = !dark },
                        openSetlist = { showSetlist = true },
                        openInfo = { showInfo = true }
                    )
                }
            }
        }

        if (showSetlist) {
            SetlistDialog(
                remote = remote,
                p = p,
                onClose = { showSetlist = false }
            )
        }

        if (showInfo) {
            InfoDialog(
                remote = remote,
                p = p,
                onClose = { showInfo = false }
            )
        }
    }
}

@Composable
private fun PhoneStage(
    remote: LiveRemoteViewModel,
    p: Palette,
    dark: Boolean,
    toggleTheme: () -> Unit,
    openSetlist: () -> Unit,
    openInfo: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(bottom = 18.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        AppHeader(remote, p, dark, toggleTheme)

        if (!remote.isConnected) {
            ConnectionBanner(remote, p)
        }

        CurrentSongPanel(remote, p)
        NextSongPanel(remote, p)
        NavigationControls(remote, p)

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            SecondaryAction(
                title = "SETLIST",
                p = p,
                modifier = Modifier.weight(1f),
                onClick = openSetlist
            )
            SecondaryAction(
                title = "INFO",
                p = p,
                modifier = Modifier.weight(1f),
                onClick = openInfo
            )
        }
    }
}

@Composable
private fun TabletStage(
    remote: LiveRemoteViewModel,
    p: Palette,
    dark: Boolean,
    toggleTheme: () -> Unit,
    openInfo: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        AppHeader(remote, p, dark, toggleTheme)

        if (!remote.isConnected) {
            ConnectionBanner(remote, p)
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
            ) {
                CurrentSongPanel(remote, p)
            }

            Column(
                modifier = Modifier
                    .width(390.dp)
                    .fillMaxHeight(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                NextSongPanel(remote, p)
                NavigationControls(remote, p)
                SecondaryAction(
                    title = "INFO",
                    p = p,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = openInfo
                )
                PersistentSetlist(
                    remote = remote,
                    p = p,
                    modifier = Modifier.weight(1f)
                )
            }
        }

        Spacer(Modifier.height(2.dp))
    }
}

@Composable
private fun AppHeader(
    remote: LiveRemoteViewModel,
    p: Palette,
    dark: Boolean,
    toggleTheme: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        androidx.compose.material3.Text(
            text = "▮▮▮▮",
            color = p.text,
            fontSize = 17.sp,
            fontWeight = FontWeight.Black
        )

        Spacer(Modifier.width(8.dp))

        androidx.compose.material3.Text(
            text = "Z LIVE REMOTE",
            color = p.text,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 0.4.sp
        )

        Spacer(Modifier.weight(1f))

        Box(
            modifier = Modifier
                .size(7.dp)
                .background(
                    if (remote.isConnected) p.playing else p.danger,
                    RoundedCornerShape(50)
                )
        )

        Spacer(Modifier.width(6.dp))

        androidx.compose.material3.Text(
            text = if (remote.isConnected) "CONECTADO" else "SIN CONEXIÓN",
            color = p.muted,
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold
        )

        Spacer(Modifier.width(10.dp))

        Box(
            modifier = Modifier
                .size(34.dp)
                .background(p.surface, RoundedCornerShape(4.dp))
                .border(1.dp, p.line, RoundedCornerShape(4.dp))
                .clickable(onClick = toggleTheme),
            contentAlignment = Alignment.Center
        ) {
            androidx.compose.material3.Text(
                text = if (dark) "☀" else "☾",
                color = p.text,
                fontSize = 16.sp
            )
        }
    }
}

@Composable
private fun ConnectionBanner(remote: LiveRemoteViewModel, p: Palette) {
    val title: String
    val message: String

    when {
        !remote.bridgeLinkReady -> {
            title = "BRIDGE DESCONECTADO"
            message = "Buscando conexión con la Mac."
        }
        !remote.dataStreamHealthy -> {
            title = "SIN DATOS"
            message = "No se reciben datos del Bridge. Controles bloqueados."
        }
        !remote.maxTransportReady -> {
            title = "ABLETON SIN RESPUESTA"
            message = "Revisá Max for Live y el dispositivo Z Live Remote."
        }
        else -> {
            title = "CONEXIÓN NO DISPONIBLE"
            message = "Los controles permanecen bloqueados por seguridad."
        }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(p.danger, RoundedCornerShape(4.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        androidx.compose.material3.Text(
            text = "⚠",
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.Black
        )
        Spacer(Modifier.width(10.dp))
        Column {
            androidx.compose.material3.Text(
                text = title,
                color = Color.White,
                fontSize = 11.sp,
                fontWeight = FontWeight.Black
            )
            androidx.compose.material3.Text(
                text = message,
                color = Color.White.copy(alpha = 0.82f),
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun CurrentSongPanel(remote: LiveRemoteViewModel, p: Palette) {
    val song = remote.currentSong

    Panel(p) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            androidx.compose.material3.Text(
                text = remote.playbackState.label,
                color = when (remote.playbackState) {
                    PlaybackState.PLAYING -> p.playing
                    PlaybackState.READY -> p.ready
                    PlaybackState.DISCONNECTED -> p.muted
                },
                fontSize = 12.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 1.4.sp
            )
            Spacer(Modifier.weight(1f))
            androidx.compose.material3.Text(
                text = remote.currentDisplayNumber,
                color = p.muted,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
        }

        Spacer(Modifier.height(16.dp))

        androidx.compose.material3.Text(
            text = song?.name ?: "ESPERANDO SETLIST",
            color = p.text,
            fontSize = 36.sp,
            fontWeight = FontWeight.Black,
            lineHeight = 38.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )

        Spacer(Modifier.height(7.dp))

        androidx.compose.material3.Text(
            text = remote.currentBPMLabel ?: "— BPM",
            color = if (remote.currentBPMLabel == null) p.muted else p.accent,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold
        )

        if (!song?.sounds.isNullOrEmpty()) {
            Spacer(Modifier.height(18.dp))
            DividerLine(p)
            Spacer(Modifier.height(12.dp))

            androidx.compose.material3.Text(
                text = "REFERENCIAS",
                color = p.muted,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.3.sp
            )

            Spacer(Modifier.height(5.dp))

            song!!.sounds.forEachIndexed { index, sound ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    androidx.compose.material3.Text(
                        text = "%02d".format(index + 1),
                        color = p.muted,
                        fontSize = 12.sp,
                        modifier = Modifier.width(30.dp)
                    )
                    androidx.compose.material3.Text(
                        text = sound,
                        color = p.text,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2
                    )
                }
            }
        }

        if (remote.hasTimeline) {
            Spacer(Modifier.height(16.dp))
            Timeline(remote, p)
        }

        Spacer(Modifier.height(18.dp))
        PlaybackControls(remote, p)
    }
}

@Composable
private fun Timeline(remote: LiveRemoteViewModel, p: Palette) {
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Row(Modifier.fillMaxWidth()) {
            androidx.compose.material3.Text(
                formatTime(remote.timelineElapsed),
                color = p.muted,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.weight(1f))
            androidx.compose.material3.Text(
                "−" + formatTime(remote.timelineRemaining),
                color = p.muted,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold
            )
        }

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(7.dp)
        ) {
            drawRoundRect(
                color = p.surfaceSecondary,
                size = size,
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(2.dp.toPx())
            )
            drawRoundRect(
                color = if (remote.playbackState == PlaybackState.PLAYING) {
                    p.playing
                } else {
                    p.accent
                },
                size = Size(
                    width = size.width * remote.timelineProgress.toFloat(),
                    height = size.height
                ),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(2.dp.toPx())
            )
        }
    }
}

@Composable
private fun PlaybackControls(remote: LiveRemoteViewModel, p: Palette) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val compactRow = maxWidth >= 560.dp

        when {
            !remote.isConnected -> {
                StatusButton(
                    text = "SIN CONEXIÓN",
                    background = p.surfaceSecondary,
                    foreground = p.muted,
                    p = p
                )
            }

            remote.playbackState == PlaybackState.PLAYING -> {
                if (compactRow) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        StatusButton(
                            text = "REPRODUCIENDO",
                            background = p.playing,
                            foreground = Color(0xFF082312),
                            p = p,
                            modifier = Modifier.weight(1f)
                        )
                        ActionButton(
                            text = "STOP",
                            background = p.danger,
                            foreground = Color.White,
                            modifier = Modifier.weight(1f),
                            onClick = remote::stop
                        )
                    }
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        StatusButton(
                            text = "REPRODUCIENDO",
                            background = p.playing,
                            foreground = Color(0xFF082312),
                            p = p
                        )
                        ActionButton(
                            text = "STOP",
                            background = p.danger,
                            foreground = Color.White,
                            onClick = remote::stop
                        )
                    }
                }
            }

            else -> {
                ActionButton(
                    text = "DISPARAR",
                    background = p.accent,
                    foreground = Color(0xFF151515),
                    minHeight = 70.dp,
                    onClick = remote::fire
                )
            }
        }
    }
}

@Composable
private fun NextSongPanel(remote: LiveRemoteViewModel, p: Palette) {
    Panel(p, innerPadding = 14.dp) {
        Row(Modifier.fillMaxWidth()) {
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.material3.Text(
                        "SIGUIENTE",
                        color = p.muted,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.1.sp
                    )
                    remote.bpmLabel(remote.nextSong)?.let {
                        Spacer(Modifier.width(8.dp))
                        androidx.compose.material3.Text(
                            it,
                            color = p.muted,
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                Spacer(Modifier.height(4.dp))

                androidx.compose.material3.Text(
                    text = remote.nextSong?.name ?: "FIN DE SETLIST",
                    color = p.text,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                val refs = remote.nextSong?.sounds.orEmpty()
                if (refs.isNotEmpty()) {
                    androidx.compose.material3.Text(
                        text = refs.joinToString(" · "),
                        color = p.muted,
                        fontSize = 12.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            androidx.compose.material3.Text(
                text = "›",
                color = p.muted,
                fontSize = 24.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun NavigationControls(remote: LiveRemoteViewModel, p: Palette) {
    val enabled = remote.isConnected && remote.playbackState != PlaybackState.PLAYING

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        SecondaryAction(
            title = "←  ANTERIOR",
            p = p,
            modifier = Modifier.weight(1f),
            enabled = enabled && remote.currentIndex > 0,
            onClick = remote::selectPrevious
        )
        SecondaryAction(
            title = "SIGUIENTE  →",
            p = p,
            modifier = Modifier.weight(1f),
            enabled = enabled && remote.currentIndex + 1 < remote.songs.size,
            onClick = remote::selectNext
        )
    }
}

@Composable
private fun PersistentSetlist(
    remote: LiveRemoteViewModel,
    p: Palette,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(p.surface, RoundedCornerShape(4.dp))
            .border(1.dp, p.line, RoundedCornerShape(4.dp))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(40.dp)
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            androidx.compose.material3.Text(
                "SETLIST",
                color = p.muted,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.1.sp
            )
            Spacer(Modifier.weight(1f))
            androidx.compose.material3.Text(
                remote.songs.size.toString() + " TEMAS",
                color = p.muted,
                fontSize = 9.sp,
                fontWeight = FontWeight.SemiBold
            )
        }

        DividerLine(p)

        LazyColumn(Modifier.weight(1f)) {
            itemsIndexed(remote.songs, key = { _, song -> song.id }) { index, song ->
                SetlistRow(
                    index = index,
                    song = song,
                    remote = remote,
                    p = p,
                    onSelected = { remote.select(song) }
                )
            }
        }
    }
}

@Composable
private fun SetlistDialog(
    remote: LiveRemoteViewModel,
    p: Palette,
    onClose: () -> Unit
) {
    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth(0.96f)
                .fillMaxHeight(0.92f),
            color = p.background,
            shape = RoundedCornerShape(6.dp)
        ) {
            Column {
                DialogHeader(
                    title = "SETLIST",
                    subtitle = remote.songs.size.toString() + " TEMAS",
                    p = p,
                    onClose = onClose
                )

                LazyColumn(Modifier.weight(1f)) {
                    itemsIndexed(remote.songs, key = { _, song -> song.id }) { index, song ->
                        SetlistRow(
                            index = index,
                            song = song,
                            remote = remote,
                            p = p,
                            onSelected = {
                                remote.select(song)
                                if (remote.playbackState != PlaybackState.PLAYING) {
                                    onClose()
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SetlistRow(
    index: Int,
    song: Song,
    remote: LiveRemoteViewModel,
    p: Palette,
    onSelected: () -> Unit
) {
    val current = remote.currentSong?.id == song.id
    val enabled = remote.playbackState != PlaybackState.PLAYING

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = enabled, onClick = onSelected)
            .background(
                if (current) p.surfaceSecondary else Color.Transparent
            )
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier
                .width(3.dp)
                .height(30.dp)
                .background(if (current) p.accent else Color.Transparent)
        )
        Spacer(Modifier.width(9.dp))
        androidx.compose.material3.Text(
            "%02d".format(index + 1),
            color = p.muted,
            fontSize = 10.sp,
            modifier = Modifier.width(28.dp)
        )
        androidx.compose.material3.Text(
            song.name,
            color = p.text,
            fontSize = 14.sp,
            fontWeight = if (current) FontWeight.Bold else FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        remote.bpmLabel(song)?.let {
            androidx.compose.material3.Text(
                it,
                color = p.muted,
                fontSize = 9.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun InfoDialog(
    remote: LiveRemoteViewModel,
    p: Palette,
    onClose: () -> Unit
) {
    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth(0.96f)
                .fillMaxHeight(0.92f),
            color = p.background,
            shape = RoundedCornerShape(6.dp)
        ) {
            Column {
                DialogHeader(
                    title = "INFO DEL SHOW",
                    subtitle = "",
                    p = p,
                    onClose = onClose
                )

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                        .padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        MetricCard(
                            "TEMAS",
                            remote.songs.size.toString(),
                            p,
                            Modifier.weight(1f)
                        )
                        MetricCard(
                            "DURACIÓN MUSICAL",
                            formatDuration(remote.totalSetlistDuration),
                            p,
                            Modifier.weight(1f)
                        )
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        MetricCard(
                            "BPM PROMEDIO",
                            formatBpm(remote.averageBPM),
                            p,
                            Modifier.weight(1f)
                        )
                        MetricCard(
                            "RANGO BPM",
                            bpmRange(remote),
                            p,
                            Modifier.weight(1f)
                        )
                    }

                    EnergyCard(remote, p)

                    Panel(p, innerPadding = 14.dp) {
                        androidx.compose.material3.Text(
                            "SOBRE LA DURACIÓN",
                            color = p.muted,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Black,
                            letterSpacing = 1.sp
                        )
                        Spacer(Modifier.height(5.dp))
                        androidx.compose.material3.Text(
                            if (remote.hasCompleteSetlistDuration) {
                                "La duración suma el contenido musical de las Scenes. No incluye pausas, charla ni cambios entre canciones."
                            } else {
                                "Duración parcial: se recibieron tiempos de " +
                                    remote.knownDurationSongCount + " de " +
                                    remote.songs.size + " canciones."
                            },
                            color = p.muted,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EnergyCard(remote: LiveRemoteViewModel, p: Palette) {
    val points = remote.songs.mapIndexedNotNull { index, song ->
        remote.bpmFor(song)?.let { Triple(index + 1, it, song.id) }
    }

    Panel(p, innerPadding = 14.dp) {
        androidx.compose.material3.Text(
            "ENERGÍA DEL SHOW",
            color = p.muted,
            fontSize = 11.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 1.1.sp
        )
        androidx.compose.material3.Text(
            "Curva estimada a partir de los BPM de cada canción",
            color = p.muted,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium
        )

        Spacer(Modifier.height(12.dp))

        if (points.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(150.dp),
                contentAlignment = Alignment.Center
            ) {
                androidx.compose.material3.Text(
                    "Esperando información de BPM.",
                    color = p.muted,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        } else {
            val minBpm = points.minOf { it.second }
            val maxBpm = points.maxOf { it.second }
            val lower = max(20.0, floor((minBpm - 10.0) / 10.0) * 10.0)
            val upper = max(lower + 20.0, ceil((maxBpm + 10.0) / 10.0) * 10.0)

            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(210.dp)
            ) {
                val left = 34.dp.toPx()
                val right = 16.dp.toPx()
                val top = 8.dp.toPx()
                val bottom = 12.dp.toPx()
                val chartWidth = size.width - left - right
                val chartHeight = size.height - top - bottom

                repeat(4) { step ->
                    val y = top + chartHeight * step / 3f
                    drawLine(
                        color = p.line.copy(alpha = 0.55f),
                        start = Offset(left, y),
                        end = Offset(size.width - right, y),
                        strokeWidth = 1f
                    )
                }

                val slot = chartWidth / (points.size + 1)
                val barWidth = max(4.dp.toPx(), slot * 0.58f)

                points.forEachIndexed { index, point ->
                    val ratio = ((point.second - lower) / (upper - lower))
                        .toFloat()
                        .coerceIn(0f, 1f)
                    val height = chartHeight * ratio
                    val centerX = left + slot * (index + 1)
                    val color =
                        if (remote.currentSong?.id == point.third) p.playing else p.accent

                    drawRect(
                        color = color,
                        topLeft = Offset(centerX - barWidth / 2f, top + chartHeight - height),
                        size = Size(barWidth, height)
                    )
                }

                drawIntoCanvas { canvas ->
                    val paint = android.graphics.Paint().apply {
                        color = android.graphics.Color.rgb(145, 145, 140)
                        textSize = 9.sp.toPx()
                        isAntiAlias = true
                    }
                    canvas.nativeCanvas.drawText(
                        upper.toInt().toString(),
                        0f,
                        top + 8.dp.toPx(),
                        paint
                    )
                    canvas.nativeCanvas.drawText(
                        lower.toInt().toString(),
                        0f,
                        top + chartHeight,
                        paint
                    )
                }
            }

            Row(Modifier.fillMaxWidth()) {
                androidx.compose.material3.Text(
                    "INICIO",
                    color = p.muted,
                    fontSize = 8.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.weight(1f))
                androidx.compose.material3.Text(
                    "ORDEN DEL SETLIST",
                    color = p.muted,
                    fontSize = 8.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(Modifier.weight(1f))
                androidx.compose.material3.Text(
                    "FIN",
                    color = p.muted,
                    fontSize = 8.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(Modifier.height(8.dp))
            DividerLine(p)
            Spacer(Modifier.height(7.dp))

            androidx.compose.material3.Text(
                "ⓘ  La curva usa BPM como referencia rítmica. No mide por sí sola la intensidad musical real.",
                color = p.muted,
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun DialogHeader(
    title: String,
    subtitle: String,
    p: Palette,
    onClose: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            androidx.compose.material3.Text(
                title,
                color = p.text,
                fontSize = 15.sp,
                fontWeight = FontWeight.Black
            )
            if (subtitle.isNotBlank()) {
                androidx.compose.material3.Text(
                    subtitle,
                    color = p.muted,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        Spacer(Modifier.weight(1f))

        Box(
            modifier = Modifier
                .size(34.dp)
                .background(p.surface, RoundedCornerShape(4.dp))
                .border(1.dp, p.line, RoundedCornerShape(4.dp))
                .clickable(onClick = onClose),
            contentAlignment = Alignment.Center
        ) {
            androidx.compose.material3.Text(
                "×",
                color = p.text,
                fontSize = 22.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }

    DividerLine(p)
}

@Composable
private fun MetricCard(
    title: String,
    value: String,
    p: Palette,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .height(86.dp)
            .background(p.surface, RoundedCornerShape(4.dp))
            .border(1.dp, p.line, RoundedCornerShape(4.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        androidx.compose.material3.Text(
            title,
            color = p.muted,
            fontSize = 9.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 0.8.sp
        )
        androidx.compose.material3.Text(
            value,
            color = p.text,
            fontSize = 20.sp,
            fontWeight = FontWeight.Black,
            maxLines = 1
        )
    }
}

@Composable
private fun Panel(
    p: Palette,
    modifier: Modifier = Modifier,
    innerPadding: Dp = 18.dp,
    content: @Composable Column.() -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(p.surface, RoundedCornerShape(4.dp))
            .border(1.dp, p.line, RoundedCornerShape(4.dp))
            .padding(innerPadding),
        content = content
    )
}

@Composable
private fun StatusButton(
    text: String,
    background: Color,
    foreground: Color,
    p: Palette,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(58.dp)
            .background(background, RoundedCornerShape(4.dp))
            .border(1.dp, background, RoundedCornerShape(4.dp)),
        contentAlignment = Alignment.Center
    ) {
        androidx.compose.material3.Text(
            text,
            color = foreground,
            fontSize = 15.sp,
            fontWeight = FontWeight.Black
        )
    }
}

@Composable
private fun ActionButton(
    text: String,
    background: Color,
    foreground: Color,
    modifier: Modifier = Modifier,
    minHeight: Dp = 58.dp,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(minHeight),
        shape = RoundedCornerShape(4.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = background,
            contentColor = foreground
        )
    ) {
        androidx.compose.material3.Text(
            text,
            fontSize = 16.sp,
            fontWeight = FontWeight.Black
        )
    }
}

@Composable
private fun SecondaryAction(
    title: String,
    p: Palette,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.height(52.dp),
        shape = RoundedCornerShape(4.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = p.surface,
            contentColor = p.text,
            disabledContainerColor = p.surface,
            disabledContentColor = p.muted.copy(alpha = 0.5f)
        ),
        border = androidx.compose.foundation.BorderStroke(1.dp, p.line)
    ) {
        androidx.compose.material3.Text(
            title,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun DividerLine(p: Palette) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(p.line)
    )
}

private fun formatTime(seconds: Double): String {
    val total = max(0, seconds.toInt())
    val minutes = total / 60
    val secs = total % 60
    return "%d:%02d".format(minutes, secs)
}

private fun formatDuration(seconds: Double): String {
    if (seconds <= 0) return "—"
    val total = seconds.toInt()
    val hours = total / 3600
    val minutes = (total % 3600) / 60
    val secs = total % 60

    return if (hours > 0) {
        "%d:%02d:%02d".format(hours, minutes, secs)
    } else {
        "%d:%02d".format(minutes, secs)
    }
}

private fun formatBpm(value: Double?): String {
    if (value == null) return "—"
    return if (kotlin.math.abs(value - value.toInt()) < 0.01) {
        value.toInt().toString()
    } else {
        "%.1f".format(value)
    }
}

private fun bpmRange(remote: LiveRemoteViewModel): String {
    val low = remote.minimumBPM ?: return "—"
    val high = remote.maximumBPM ?: return "—"
    return formatBpm(low) + "–" + formatBpm(high)
}
