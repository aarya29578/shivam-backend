import 'package:flutter/material.dart';

/// EDUMID Design System – Color Palette
/// Primary: Purple  |  Secondary: Blue  |  Accent: Amber
abstract class AppColors {
  // ── Brand Primaries ──────────────────────────────────────────────
  static const primary = Color(0xFF6C4CF1); // Purple
  static const primaryLight = Color(0xFF8B6FF5);
  static const primaryDark = Color(0xFF5438D4);

  static const secondary = Color(0xFF4A7BFF); // Blue
  static const secondaryLight = Color(0xFF6B93FF);
  static const secondaryDark = Color(0xFF2B5CE6);

  static const accent = Color(0xFFF59E0B); // Amber
  static const accentLight = Color(0xFFFBBF24);
  static const accentDark = Color(0xFFD97706);

  // ── Semantic ─────────────────────────────────────────────────────
  static const success = Color(0xFF22C55E);
  static const successSurface = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const warningSurface = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoSurface = Color(0xFFEFF6FF);

  // ── Light Mode Surfaces ──────────────────────────────────────────
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surface1Light = Color(0xFFF8FAFC);
  static const surface2Light = Color(0xFFF1F5F9);
  static const surface3Light = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFE2E8F0);

  // ── Dark Mode Surfaces ───────────────────────────────────────────
  static const surfaceDark = Color(0xFF0F172A);
  static const surface1Dark = Color(0xFF1E293B);
  static const surface2Dark = Color(0xFF334155);
  static const surface3Dark = Color(0xFF475569);
  static const borderDark = Color(0xFF334155);

  // ── Text ─────────────────────────────────────────────────────────
  static const textPrimaryLight = Color(0xFF111827);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const textTertiaryLight = Color(0xFF94A3B8);

  static const textPrimaryDark = Color(0xFFF1F5F9);
  static const textSecondaryDark = Color(0xFF94A3B8);
  static const textTertiaryDark = Color(0xFF64748B);

  // ── Glassmorphism ────────────────────────────────────────────────
  static const glassLight = Color(0xCCFFFFFF);
  static const glassDark = Color(0x801E293B);
  static const glassBorderLight = Color(0x40FFFFFF);
  static const glassBorderDark = Color(0x26FFFFFF);

  // ── Gradients ────────────────────────────────────────────────────
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C4CF1), Color(0xFF4A7BFF)],
  );

  static const secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A7BFF), Color(0xFF6C4CF1)],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  );

  static const darkBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
  );

  // ── Role Badge Colors ────────────────────────────────────────────
  static const roleStudent = Color(0xFF6C4CF1);
  static const roleTeacher = Color(0xFF6C4CF1);
  static const rolePrincipal = Color(0xFF6C4CF1);
  static const roleVendor = Color(0xFFF59E0B);
  static const roleDesigner = Color(0xFFEC4899);
  static const roleOperator = Color(0xFFEF4444);
  static const roleSales = Color(0xFF10B981);
  static const roleSchool = Color(0xFF06B6D4);
  static const roleDataOperator = Color(0xFF6366F1);
  static const roleSalesPerson = Color(0xFF10B981);
}
