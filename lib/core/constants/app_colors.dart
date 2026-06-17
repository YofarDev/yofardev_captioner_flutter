import 'dart:ui';

// Base palette
const Color darkGrey = Color(0xFF1B1B1B);
const Color lightGrey = Color(0xFF434343);
const Color lightPink = Color(0xFFF4C3D3);

// Settings — "pink terminal" depth + text tiers
/// Recessed background for panels sitting below the shell surface.
const Color panelDark = Color(0xFF141414);

/// Raised card surface, slightly lifted from the shell background.
const Color panelRaised = Color(0xFF212121);

/// 1px hairline borders — the terminal precision layer.
const Color hairline = Color(0xFF2C2C2C);

/// Accent surface tint derived from the pink system.
const Color pinkSurface = Color(0xFF2A1C22);

/// Muted pink for disabled / locked accents so they read as intentional,
/// not as a faded-out afterthought.
const Color pinkDim = Color(0xFF6E4A55);

/// Text tiers tuned for the dark shell.
const Color textPrimary = Color(0xFFECECEC);
const Color textSecondary = Color(0xFF9A9A9A);
const Color textMuted = Color(0xFF666666);
