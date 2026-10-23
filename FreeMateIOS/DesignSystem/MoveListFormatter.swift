import Foundation

enum MoveListFormatter {
    /// Groups SAN moves by full move number, such as "1. e4 e5". A game that starts with Black
    /// to move reads "1... e5" first. Move numbers come from the starting FEN.
    static func rows(_ sans: [String], startingFen: String) -> [String] {
        let fields = startingFen.split(separator: " ")
        var number = fields.count > 5 ? max(Int(fields[5]) ?? 1, 1) : 1
        var isWhite = fields.count > 1 ? fields[1] != "b" : true
        var rows: [String] = []
        for san in sans {
            if isWhite {
                rows.append("\(number). \(san)")
            } else if let last = rows.last, last.hasPrefix("\(number). "), !last.contains("...") {
                rows[rows.count - 1] = "\(last) \(san)"
            } else {
                rows.append("\(number)... \(san)")
            }
            if !isWhite { number += 1 }
            isWhite.toggle()
        }
        return rows
    }
}
