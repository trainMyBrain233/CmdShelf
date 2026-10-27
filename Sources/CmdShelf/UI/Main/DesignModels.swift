import Foundation

enum CmdShelfDesign {
    struct Category: Identifiable, Hashable {
        let id: String
        let name: String
        let symbol: String

        init(id: String? = nil, name: String, symbol: String) {
            self.id = id ?? name.lowercased()
            self.name = name
            self.symbol = symbol
        }
    }

    enum LibraryItem: Identifiable, Hashable {
        case command(Command)
        case sop(Sop)
        case inbox(InboxItem)

        var id: UUID {
            switch self {
            case .command(let command):
                return command.id
            case .sop(let sop):
                return sop.id
            case .inbox(let inbox):
                return inbox.id
            }
        }

        var title: String {
            switch self {
            case .command(let command):
                return command.title
            case .sop(let sop):
                return sop.title
            case .inbox:
                return "Inbox Capture"
            }
        }

        var preview: String {
            switch self {
            case .command(let command):
                return command.content.singleLinePreview(limit: 96)
            case .sop(let sop):
                return sop.bodyMarkdown.singleLinePreview(limit: 96)
            case .inbox(let inbox):
                return inbox.summary
            }
        }

        var category: String {
            switch self {
            case .command(let command):
                return command.groupName
            case .sop(let sop):
                return sop.groupName
            case .inbox(let inbox):
                return inbox.detectedType.rawValue.uppercased()
            }
        }

        var uses: Int {
            switch self {
            case .command(let command):
                return command.copyCount
            case .sop(let sop):
                return sop.copyCount
            case .inbox:
                return 0
            }
        }

        var createdAt: Date {
            switch self {
            case .command(let command):
                return command.createdAt
            case .sop(let sop):
                return sop.createdAt
            case .inbox(let inbox):
                return inbox.createdAt
            }
        }

        var updatedAt: Date {
            switch self {
            case .command(let command):
                return command.updatedAt
            case .sop(let sop):
                return sop.updatedAt
            case .inbox(let inbox):
                return inbox.createdAt
            }
        }

        var kindIcon: String {
            switch self {
            case .command:
                return "terminal.fill"
            case .sop:
                return "doc.text.fill"
            case .inbox:
                return "tray.fill"
            }
        }

        var typeLabel: String {
            switch self {
            case .command:
                return "CMD"
            case .sop:
                return "SOP"
            case .inbox(let inbox):
                return inbox.detectedType.rawValue.uppercased()
            }
        }
    }

    enum MockData {
        static let categories: [Category] = [
            .init(name: "Git", symbol: "point.topleft.down.curvedto.point.bottomright.up"),
            .init(name: "Docker", symbol: "shippingbox.fill"),
            .init(name: "K8s", symbol: "hexagon.2.fill"),
            .init(name: "Swift", symbol: "swift"),
            .init(name: "Ops", symbol: "wrench.and.screwdriver.fill")
        ]

        static let commands: [Command] = [
            .init(
                title: "Rebase Current Branch",
                content: "git fetch origin && git rebase origin/main",
                description: "Keep branch aligned with main",
                groupName: "Git",
                copyCount: 124,
                lastCopiedAt: daysAgo(1),
                createdAt: daysAgo(40),
                updatedAt: daysAgo(1)
            ),
            .init(
                title: "Docker Logs Follow",
                content: "docker logs -f --tail=200 my-api",
                description: "Follow service logs quickly",
                groupName: "Docker",
                copyCount: 93,
                lastCopiedAt: daysAgo(0),
                createdAt: daysAgo(35),
                updatedAt: daysAgo(0)
            ),
            .init(
                title: "K8s Rollout Restart",
                content: "kubectl rollout restart deploy/api -n prod",
                description: "Trigger rollout for production deployment",
                groupName: "K8s",
                copyCount: 81,
                lastCopiedAt: daysAgo(2),
                createdAt: daysAgo(90),
                updatedAt: daysAgo(2)
            )
        ]

        static let sops: [Sop] = [
            .init(
                title: "Release Checklist",
                bodyMarkdown: """
                # Release Checklist

                1. Run full tests
                2. Build release
                3. Tag and push

                ```bash
                swift test
                swift build -c release
                git tag v1.4.2
                git push --tags
                ```
                """,
                groupName: "Ops",
                copyCount: 112,
                lastUsedAt: daysAgo(2),
                createdAt: daysAgo(120),
                updatedAt: daysAgo(2)
            )
        ]

        static let inboxItems: [InboxItem] = [
            .init(rawText: "kubectl get pods -A", detectedType: .cmd, createdAt: daysAgo(0))
        ]

        private static func daysAgo(_ days: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        }
    }
}

private extension String {
    func singleLinePreview(limit: Int) -> String {
        let flattened = replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if flattened.count <= limit {
            return flattened
        }
        return String(flattened.prefix(limit)) + "..."
    }
}
