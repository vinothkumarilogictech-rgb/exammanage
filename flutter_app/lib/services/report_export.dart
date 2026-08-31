/// Placeholder for the same report/export service layer used by the
/// reference WorkLog mobile architecture. Office reports can be wired here
/// without coupling screens to PDF/printing implementations.
class ReportExport {
  static Future<void> export(String title, String content) async {
    // Add pdf/printing implementation when report export is enabled.
  }
}
