import SwiftUI
import WidgetKit

/// The app's accent, matching `Theme.accent`. The widget cannot see the app's design system.
private let accent = Color(light: Color(red: 0.184, green: 0.486, blue: 0.827), dark: Color(red: 0.282, green: 0.584, blue: 0.937))
private let streakColor = Color(light: Color(red: 0.722, green: 0.431, blue: 0), dark: Color(red: 0.961, green: 0.651, blue: 0.137))

private extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}

struct FreeMateEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    var dueReviews: Int { snapshot?.dueReviews(at: date) ?? 0 }
    var streak: Int { snapshot?.streak(at: date) ?? 0 }

    static let preview = FreeMateEntry(date: Date(), snapshot: WidgetSnapshot(
        nextLessonId: "piece-movement", nextLessonTitle: "Piece Movement", courseTitle: "Beginner Fundamentals",
        lessonsDone: 4, lessonsTotal: 15, reviewDueDates: [Date(), Date()], activeDays: [], updatedAt: Date()
    ))
}

struct FreeMateProvider: TimelineProvider {
    func placeholder(in context: Context) -> FreeMateEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (FreeMateEntry) -> Void) {
        completion(context.isPreview ? .preview : FreeMateEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    /// One entry now, one when the next review comes due, and one at midnight for the streak.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FreeMateEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshot.load()
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        var dates = [now, midnight]
        if let next = snapshot?.nextReviewDate(after: now), next < midnight { dates.append(next) }
        let entries = dates.sorted().map { FreeMateEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

struct FreeMateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FreeMateEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: lockScreen
        case .systemMedium: medium
        default: small
        }
    }

    private var lessonURL: URL {
        URL(string: "freemate://lesson/\(entry.snapshot?.nextLessonId ?? "")") ?? URL(string: "freemate://lessons")!
    }

    @ViewBuilder
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            if entry.dueReviews > 0 {
                reviews
            } else {
                continueLesson
            }
        }
        .widgetURL(entry.dueReviews > 0 ? URL(string: "freemate://review") : lessonURL)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            Link(destination: lessonURL) {
                VStack(alignment: .leading, spacing: 6) {
                    header
                    Spacer(minLength: 0)
                    continueLesson
                }
            }
            Divider()
            Link(destination: URL(string: "freemate://review")!) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Review").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    reviews
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.dueReviews > 0 ? "\(entry.dueReviews) to review today" : "Next: \(entry.snapshot?.nextLessonTitle ?? "Start learning")")
                .font(.headline)
                .lineLimit(1)
            Label("\(entry.streak)-day streak", systemImage: "flame.fill")
                .font(.caption)
        }
        .widgetURL(entry.dueReviews > 0 ? URL(string: "freemate://review") : lessonURL)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("FreeMate").font(.caption.weight(.semibold)).foregroundStyle(accent)
            Spacer(minLength: 0)
            if entry.streak > 0 {
                Label("\(entry.streak)", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(streakColor)
                    .accessibilityLabel("\(entry.streak)-day streak")
            }
        }
    }

    private var reviews: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.dueReviews)")
                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(entry.dueReviews > 0 ? accent : .secondary)
            Text(entry.dueReviews == 1 ? "item to review today" : "items to review today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var continueLesson: some View {
        if let snapshot = entry.snapshot, let title = snapshot.nextLessonTitle {
            VStack(alignment: .leading, spacing: 4) {
                Text("Continue").font(.caption).foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                ProgressView(value: Double(snapshot.lessonsDone), total: Double(max(snapshot.lessonsTotal, 1)))
                    .tint(accent)
                Text("\(snapshot.lessonsDone) of \(snapshot.lessonsTotal) lessons")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Learn chess").font(.headline)
                Text("Open FreeMate to start your first lesson.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FreeMateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FreeMateWidget", provider: FreeMateProvider()) { entry in
            FreeMateWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("FreeMate")
        .description("Your next lesson, reviews due today, and your streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct FreeMateWidgets: WidgetBundle {
    var body: some Widget {
        FreeMateWidget()
    }
}

#Preview(as: .systemMedium) {
    FreeMateWidget()
} timeline: {
    FreeMateEntry.preview
}
