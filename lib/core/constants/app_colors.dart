import 'dart:ui';

// ─────────────────────────────────────────────────────────────────────────
// Pink-terminal dark palette.
//
// Single source of truth for every color in the shell. Use these tokens —
// never raw `Colors.white*` or hardcoded hex. The palette is grouped by role:
//   • Surfaces  — shell background + raised/recessed panels + hairlines
//   • Accent    — the pink system, primary action color
//   • Text      — three contrast tiers tuned for the dark shell
//   • Semantic  — caution / destructive / success, tuned to the palette
//   • Controls  — derived button + tab tokens (what UI primitives consume)
// ─────────────────────────────────────────────────────────────────────────

// Surfaces ──────────────────────────────────────────────────────────────────

/// Recessed background for panels sitting below the shell surface.
const Color panelDark = Color(0xFF141414);

/// Raised card surface, slightly lifted from the shell background.
/// Also the standard surface for dialogs, sheets, and popovers.
const Color panelRaised = Color(0xFF212121);

/// Base app shell background.
const Color shellBackground = Color(0xFF1B1B1B);

/// 1px hairline borders — the terminal precision layer.
const Color hairline = Color(0xFF2C2C2C);

/// Accent surface tint derived from the pink system.
const Color pinkSurface = Color(0xFF2A1C22);

// Accent (pink system) ───────────────────────────────────────────────────────

/// Primary brand accent — labels, active markers, highlights.
const Color lightPink = Color(0xFFF4C3D3);

/// Stronger pink for primary action fills where lightPink would wash out.
const Color accentPink = Color(0xFFE89BAC);

/// Muted pink for disabled / locked accents so they read as intentional,
/// not as a faded-out afterthought.
const Color pinkDim = Color(0xFF6E4A55);

// Legacy aliases (kept so existing call sites keep working) ──────────────────
const Color darkGrey = shellBackground;
const Color lightGrey = Color(0xFF434343);

// Text tiers (tuned for the dark shell) ──────────────────────────────────────

const Color textPrimary = Color(0xFFECECEC);
const Color textSecondary = Color(0xFF9A9A9A);
const Color textMuted = Color(0xFF666666);

// Semantic ───────────────────────────────────────────────────────────────────

/// Amber for caution / destructive-warning accents.
const Color amberWarn = Color(0xFFD4942B);

/// Destructive accent — tuned to sit next to amberWarn without going neon.
const Color destructive = Color(0xFFC9544A);

/// Success / confirmation accent.
const Color success = Color(0xFF6F9E57);

// Controls — derived tokens consumed by AppButton, tabs, etc ─────────────────

// Buttons
const Color buttonPrimaryBg = lightGrey; // elevated default action
const Color buttonPrimaryFg = textPrimary;
const Color buttonOutlineBorder = hairline;
const Color buttonOutlineFg = textSecondary;
const Color buttonAccentBg = pinkSurface; // pink-tinted emphasis action
const Color buttonAccentFg = lightPink;
const Color buttonDisabledFg = textMuted;

// Tab bar
const Color tabBarBg = panelDark;
const Color tabInactiveBg = Color(0x00000000);
const Color tabActiveBg = panelRaised;
const Color tabActiveFg = textPrimary;
const Color tabInactiveFg = textMuted;
const Color tabActiveAccent = accentPink; // underline / marker on the live tab
