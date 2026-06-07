class GradeHelper {
  /// 台大 (NTU) 4.3 制對照表
  static double scoreToGpa(double score) {
    if (score >= 90) return 4.3; // A+
    if (score >= 85) return 4.0; // A
    if (score >= 80) return 3.7; // A-
    if (score >= 77) return 3.3; // B+
    if (score >= 73) return 3.0; // B
    if (score >= 70) return 2.7; // B-
    if (score >= 67) return 2.3; // C+
    if (score >= 63) return 2.0; // C
    if (score >= 60) return 1.7; // C-
    return 0.0; // F
  }
}