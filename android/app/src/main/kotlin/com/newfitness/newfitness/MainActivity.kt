package com.newfitness.newfitness

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity: o pacote `health` usa registerForActivityResult
// para pedir as permissões do Health Connect.
//
// Barra de navegação do Android (os botões "|||  ○  <" ou a barrinha de
// gestos) escondida com o app aberto; a barra de status (hora, bateria)
// continua. Puxando da borda de baixo ela aparece por alguns segundos e some
// sozinha. Escondida de novo sempre que o app volta para a frente, ganha o
// foco (depois de teclado, diálogo ou outro app) ou algo a faz reaparecer.
class MainActivity : FlutterFragmentActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private val hideRunnable = Runnable { hideNavigationBar() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ViewCompat.setOnApplyWindowInsetsListener(window.decorView) { view, insets ->
            if (insets.isVisible(WindowInsetsCompat.Type.navigationBars())) {
                scheduleHide()
            }
            ViewCompat.onApplyWindowInsets(view, insets)
        }
    }

    override fun onPostResume() {
        // O Flutter reaplica as barras no onPostResume: esconder depois dele.
        super.onPostResume()
        hideNavigationBar()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) scheduleHide(SHORT_DELAY_MS)
    }

    override fun onDestroy() {
        handler.removeCallbacks(hideRunnable)
        super.onDestroy()
    }

    private fun scheduleHide(delayMs: Long = HIDE_AGAIN_AFTER_MS) {
        handler.removeCallbacks(hideRunnable)
        handler.postDelayed(hideRunnable, delayMs)
    }

    private fun hideNavigationBar() {
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller.hide(WindowInsetsCompat.Type.navigationBars())
    }

    private companion object {
        const val HIDE_AGAIN_AFTER_MS = 3000L
        const val SHORT_DELAY_MS = 300L
    }
}
