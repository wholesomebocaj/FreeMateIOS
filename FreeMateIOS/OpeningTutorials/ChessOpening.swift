import Foundation

/// A guided opening: one main line to walk through, plus opponent deviations to practise.
struct ChessOpening: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var eco: String?
    var ecoName: String?
    var userSide: ChessColor
    var summary: String
    var ideas: [String]
    /// Every ply from the starting position, alternating white and black.
    var mainLine: [OpeningStep]
    var variations: [OpeningVariation]

    var opponentSide: ChessColor { userSide.opposite }

    func isUserPly(_ ply: Int) -> Bool {
        (ply % 2 == 0) == (userSide == .white)
    }

    /// The main line and all variations merged into one move tree from the starting position.
    var variationTree: OpeningTreeNode {
        var root = OpeningTreeNode(step: nil, ply: -1, kind: .mainLine, variationIds: [])
        root.insert(mainLine, startingPly: 0, kind: .mainLine, variationId: nil)
        for variation in variations {
            let line = Array(mainLine.prefix(variation.branchPly)) + variation.moves
            root.insert(line, startingPly: 0, kind: .variation, variationId: variation.id)
        }
        return root
    }
}

/// One half-move in a tutorial line. `san` uses standard algebraic notation, as in eco.json.
struct OpeningStep: Codable, Equatable, Hashable {
    var san: String
    var title: String
    var explanation: String
    var hint: String?
}

/// A "What if?" line: the opponent leaves the main line at `branchPly`, and the user must answer.
struct OpeningVariation: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var eco: String?
    var ecoName: String?
    /// Index into the main line where the opponent plays `moves[0]` instead.
    var branchPly: Int
    var summary: String
    var moves: [OpeningStep]
}

struct OpeningTreeNode: Equatable, Identifiable {
    enum Kind: Equatable {
        case mainLine
        case variation
    }

    var step: OpeningStep?
    var ply: Int
    var kind: Kind
    var variationIds: [String]
    var children: [OpeningTreeNode] = []

    var id: String { "\(ply)-\(step?.san ?? "start")-\(variationIds.joined(separator: ","))" }

    /// Follows `sans` from this node. Returns nil when the sequence leaves the tree.
    func node(following sans: [String]) -> OpeningTreeNode? {
        var current = self
        for san in sans {
            guard let next = current.children.first(where: { SANText.matches($0.step?.san, san) }) else { return nil }
            current = next
        }
        return current
    }

    fileprivate mutating func insert(_ line: [OpeningStep], startingPly: Int, kind: Kind, variationId: String?) {
        guard let first = line.first else { return }
        let ply = startingPly
        if let index = children.firstIndex(where: { SANText.matches($0.step?.san, first.san) }) {
            if let variationId { children[index].variationIds.append(variationId) }
            children[index].insert(Array(line.dropFirst()), startingPly: ply + 1, kind: kind, variationId: variationId)
            return
        }
        var child = OpeningTreeNode(step: first, ply: ply, kind: kind, variationIds: variationId.map { [$0] } ?? [])
        child.insert(Array(line.dropFirst()), startingPly: ply + 1, kind: kind, variationId: variationId)
        children.append(child)
    }
}

enum SANText {
    /// Drops check marks, annotations, and zero-castling so "O-O+", "0-0", and "O-O" compare equal.
    static func normalized(_ san: String) -> String {
        san.replacingOccurrences(of: "0", with: "O")
            .filter { !"+#!?".contains($0) }
    }

    static func matches(_ lhs: String?, _ rhs: String) -> Bool {
        guard let lhs else { return false }
        return normalized(lhs) == normalized(rhs)
    }
}
