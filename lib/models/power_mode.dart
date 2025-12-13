/// Power mode for battery optimization
enum PowerMode {
  /// Full features - when charging or >60% battery
  performance,

  /// Default operation - 30-60% battery
  balanced,

  /// Reduced scanning - <30% battery
  powerSaver,

  /// Emergency mode - <10% battery
  ultraLowPower,
}

