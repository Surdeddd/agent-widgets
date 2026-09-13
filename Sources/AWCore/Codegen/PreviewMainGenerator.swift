public enum PreviewMainGenerator {
    public static func generate(view: String) -> String {
        """
        import AWKit
        import AWPreview

        AWPreviewMain.run(\(view).self)

        """
    }
}
