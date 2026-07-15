import Foundation

/// User-editable list of apps that must keep the classic macOS behaviour
/// (stay running after their last window closes). Edit this file any time;
/// QuitOnClose re-reads it at every launch.
enum ConfigStore {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("QuitOnClose", isDirectory: true)
    }()

    static let excludedBundleIDsFile = directory.appendingPathComponent("excluded-bundle-ids.txt")

    private static let defaultContent = """
    # QuitOnClose - elenco di esclusione
    #
    # Un bundle identifier per riga. Le app elencate qui NON verranno chiuse
    # quando resta a zero finestre: manterranno il comportamento classico di macOS.
    # Le righe che iniziano con '#' sono commenti.
    #
    # Puoi trovare il bundle identifier di un'app con:
    #   osascript -e 'id of app "NomeApp"'
    #
    com.apple.finder
    """

    static func loadExcludedBundleIDs() -> Set<String> {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: excludedBundleIDsFile.path) {
            try? defaultContent.write(to: excludedBundleIDsFile, atomically: true, encoding: .utf8)
        }

        guard let content = try? String(contentsOf: excludedBundleIDsFile, encoding: .utf8) else {
            return ["com.apple.finder"]
        }

        let ids = content
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        return Set(ids)
    }
}
