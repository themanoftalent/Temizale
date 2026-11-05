import Foundation

/// Product, brand and developer identity shown in the About panel, Settings and sidebar.
enum Brand {
    static let appName = "Temizale"
    static let brand = "Temizale"
    static let logoText = "Ale"
    static let developer = "Mehmet Akif Cifci"
    static let identity = "TheManOfTalent"
    static let credit = "Developed by Mehmet Akif Cifci | TheManOfTalent"
    static let github = URL(string: "https://github.com/themanoftalent")!
    static let repository = URL(string: "https://github.com/themanoftalent/Temizale")!

    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "4"
        return "\(short) (\(build))"
    }
}
