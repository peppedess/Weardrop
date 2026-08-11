package com.peppedess.weardrop

import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.VisibilityThreshold
import androidx.compose.animation.core.spring
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.IntOffset

/**
 * Vocabolario di movimento condiviso.
 *
 * Distinzione Material 3 Expressive: le molle "spatial" muovono elementi nello
 * spazio e possono rimbalzare, quelle "effects" cambiano colore/opacita' e non
 * devono mai oscillare (dampingRatio 1.0).
 *
 * NOTA: per animare un IntOffset con spring serve visibilityThreshold
 * esplicito, altrimenti non compila.
 */
object Motion {

    fun <T> spatial(): FiniteAnimationSpec<T> = spring(
        dampingRatio = 0.78f,
        stiffness = 360f
    )

    fun <T> spatialFast(): FiniteAnimationSpec<T> = spring(
        dampingRatio = 0.60f,
        stiffness = 900f
    )

    fun <T> effects(): FiniteAnimationSpec<T> = spring(
        dampingRatio = Spring.DampingRatioNoBouncy,
        stiffness = 420f
    )

    fun offset(): FiniteAnimationSpec<IntOffset> = spring(
        dampingRatio = 0.80f,
        stiffness = 340f,
        visibilityThreshold = IntOffset.VisibilityThreshold
    )
}

/**
 * Compressione elastica alla pressione.
 */
@Composable
fun Modifier.pressBounce(interactionSource: MutableInteractionSource): Modifier {
    val pressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.965f else 1f,
        animationSpec = Motion.spatialFast(),
        label = "pressBounce"
    )
    return this.graphicsLayer {
        scaleX = scale
        scaleY = scale
    }
}
