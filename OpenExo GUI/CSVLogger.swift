import Foundation

class CSVLogger: ObservableObject {

    @Published var isLogging = false
    @Published var currentFileName = ""
    @Published var logDirectory: URL

    private var fileHandle: FileHandle?
    private var columnNames: [String] = []

    init() {
        logDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func startLogging(prefix: String, columnNames: [String]) {
        stopLogging()
        let cols = columnNames.isEmpty ? (0..<10).map { "data\($0)" } : columnNames
        self.columnNames = cols

        let sanitized = prefix.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = sanitized.isEmpty ? "trial_\(timestamp).csv" : "\(sanitized)_trial_\(timestamp).csv"

        let url = logDirectory.appendingPathComponent(filename)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: url)

        let header = (["epoch", "mark"] + cols).joined(separator: ",") + "\n"
        fileHandle?.write(header.data(using: .utf8) ?? Data())

        currentFileName = filename
        isLogging = true
    }

    func log(values: [Double], mark: Int) {
        guard isLogging, let fh = fileHandle else { return }
        let epoch = Date().timeIntervalSince1970
        let dataFields = values.prefix(columnNames.count).map { String(format: "%.4f", $0) }
        let row = ([String(format: "%.3f", epoch), "\(mark)"] + dataFields).joined(separator: ",") + "\n"
        fh.write(row.data(using: .utf8) ?? Data())
    }

    func rollover(prefix: String) {
        let cols = columnNames
        stopLogging()
        startLogging(prefix: prefix, columnNames: cols)
    }

    func stopLogging() {
        fileHandle?.closeFile()
        fileHandle = nil
        isLogging = false
    }

    func allLogFiles() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return files.filter { $0.pathExtension == "csv" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
