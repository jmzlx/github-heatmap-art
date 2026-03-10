# Design Guide — GitHub Heatmap Art

Hard-won lessons from testing designs on real GitHub profiles.

## Rule 1: Binary Contrast

GitHub's 4 green shades (levels 1–3) are nearly indistinguishable to human eyes. **Design with level 0 (gray) and level 4 (dark green) only.** Use level 1 sparingly for subtle backgrounds.

Tested: aurora gradients, mountain landscapes, and multi-shade art all collapsed into unrecognizable green blobs.

## Rule 2: Recognizability

If you can't tell what it is without a label, it's a bad design. At 52×7 pixels, only these work:
- **Geometric patterns:** checkerboard, stripes, zigzag, diamonds
- **Iconic sprites:** hearts, space invaders, pac-man (everyone knows the shape)
- **Text:** always readable at this scale (~13 chars max)
- **Repeating motifs:** tessellation is self-explanatory

These fail: photos, complex images, "artistic interpretations," abstract gradients.

## Rule 3: Minimum 2px Thickness

Single-pixel lines vanish on the real heatmap. Every element needs ≥2px width to be visible.

## Rule 4: Fill the Canvas

Empty cells are gray. Sparse designs fight a gray void. A light background fill (level 1) makes dark accents (level 4) pop. Art comes from sculpting dark on light, not drawing on empty.

## Composition Techniques

**Layering:** Build grids incrementally. Start with background fill, add shapes, then details. Use non-zero values to overwrite.

**Centering:** A sprite of width W centers at column `(52 - W) // 2`. Height H centers at row `(7 - H) // 2`.

**Text:** Each character is roughly 3×5 pixels plus 1px gap = 4 columns per char. Max ~13 characters across 52 columns.

**Data visualization:** Map normalized values (0.0–1.0) to row heights. Fill from the bottom row up. Good for stock charts, activity graphs.

## Year Boundaries

The canvas starts on the Sunday before January 1. For years where Jan 1 isn't Sunday, the first few cells map to the previous year — `paint.sh` skips these automatically. Your first visible column might be partially filled.

## GitHub Commit Levels

GitHub uses dynamic quartile shading per user. The default commit counts (0, 2, 5, 8, 12 per level) work for most profiles. If shading looks off, adjust the `LEVELS` array in `paint.sh`.
