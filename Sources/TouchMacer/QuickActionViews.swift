import SwiftUI

struct QuickActionGrid: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var service: QuickActionService
  let openMore: () -> Void

  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: 8),
    count: 4
  )

  init(model: AppModel, openMore: @escaping () -> Void) {
    self.model = model
    self.openMore = openMore
    self.service = model.quickActionService
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Quick Actions")
          .font(.headline)
        Spacer()
        Text("\(model.settings.pinnedQuickActions.count)/7")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
      }

      LazyVGrid(columns: columns, spacing: 10) {
        ForEach(service.pinnedItems(for: model.settings.pinnedQuickActions)) { item in
          QuickActionTile(item: item, style: .compact) {
            service.perform(item.reference)
          }
        }
        QuickActionMoreTile(action: openMore)
      }

      if let feedbackMessage = service.feedbackMessage {
        Text(feedbackMessage)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .transition(.opacity)
      }
    }
    .onAppear {
      service.refreshAll()
    }
  }
}

struct QuickActionsWindowView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var service: QuickActionService
  let openSettings: () -> Void

  private let columns = [
    GridItem(.adaptive(minimum: 118, maximum: 142), spacing: 14)
  ]

  init(model: AppModel, openSettings: @escaping () -> Void) {
    self.model = model
    self.openSettings = openSettings
    self.service = model.quickActionService
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Quick Actions")
            .font(.title2.weight(.semibold))
          Text("Run built-in actions and Apple Shortcuts without pinning them.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Manage") {
          openSettings()
        }
      }

      if let feedbackMessage = service.feedbackMessage {
        Label(feedbackMessage, systemImage: "info.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.secondary.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      }

      ScrollView {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
          ForEach(service.catalogItems) { item in
            QuickActionTile(item: item, style: .catalog) {
              service.perform(item.reference)
            }
          }
        }
        .padding(.vertical, 2)
      }
    }
    .padding(22)
    .frame(minWidth: 620, minHeight: 520, alignment: .topLeading)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear {
      service.refreshAll()
    }
  }
}

struct QuickActionSettingsView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var service: QuickActionService

  init(model: AppModel) {
    self.model = model
    self.service = model.quickActionService
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsGroup(spacing: 12) {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Pinned actions")
              .font(.headline)
            Text("The menu-bar popover shows these actions before the fixed More button.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text("\(model.settings.pinnedQuickActions.count) / 7")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(
              model.settings.pinnedQuickActions.count == 7 ? Color.orange : Color.secondary)
        }

        if model.settings.pinnedQuickActions.isEmpty {
          Text("No actions are pinned. The popover will show only More.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
        } else {
          ForEach(Array(model.settings.pinnedQuickActions.enumerated()), id: \.element.id) {
            index, reference in
            let item = service.item(for: reference)
            HStack(spacing: 10) {
              Image(systemName: item.systemImage)
                .frame(width: 22)
                .foregroundStyle(
                  item.state.availability.isAvailable ? Color.accentColor : Color.secondary)
              VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                if let reason = item.state.availability.reason {
                  Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }
              }
              Spacer()
              Button {
                model.movePinnedQuickAction(at: index, by: -1)
              } label: {
                Image(systemName: "chevron.up")
              }
              .buttonStyle(.borderless)
              .disabled(index == 0)
              .help("Move up")

              Button {
                model.movePinnedQuickAction(at: index, by: 1)
              } label: {
                Image(systemName: "chevron.down")
              }
              .buttonStyle(.borderless)
              .disabled(index == model.settings.pinnedQuickActions.count - 1)
              .help("Move down")

              Button(role: .destructive) {
                model.removePinnedQuickAction(reference)
              } label: {
                Image(systemName: "minus.circle")
              }
              .buttonStyle(.borderless)
              .help("Remove")
            }
            .padding(.vertical, 4)
          }
        }
      }

      SettingsGroup(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Available actions")
            .font(.headline)
          Text("Built-in actions and Apple Shortcuts can be added once and reordered above.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        ForEach(availableItems) { item in
          HStack(spacing: 10) {
            Image(systemName: item.systemImage)
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title)
              if let reason = item.state.availability.reason {
                Text(reason)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(2)
              }
            }
            Spacer()
            Button("Add") {
              model.addPinnedQuickAction(item.reference)
            }
            .disabled(
              model.settings.pinnedQuickActions.count >= 7
                || !item.state.availability.isAvailable
            )
          }
          .padding(.vertical, 3)
        }
      }
    }
    .onAppear {
      service.refreshAll()
    }
  }

  private var availableItems: [QuickActionItem] {
    let pinned = Set(model.settings.pinnedQuickActions)
    return service.catalogItems.filter { !pinned.contains($0.reference) }
  }
}

private enum QuickActionTileStyle {
  case compact
  case catalog

  var height: CGFloat {
    switch self {
    case .compact: return 72
    case .catalog: return 126
    }
  }

  var iconSize: CGFloat {
    switch self {
    case .compact: return 27
    case .catalog: return 34
    }
  }
}

private struct QuickActionTile: View {
  let item: QuickActionItem
  let style: QuickActionTileStyle
  let action: () -> Void

  @State private var confirmsDestructiveAction = false

  var body: some View {
    Button {
      if item.isDestructive {
        confirmsDestructiveAction = true
      } else {
        action()
      }
    } label: {
      VStack(spacing: style == .compact ? 5 : 8) {
        ZStack {
          Circle()
            .fill(iconBackground)
          if item.state.isRunning {
            ProgressView()
              .controlSize(.small)
          } else {
            Image(systemName: item.systemImage)
              .font(.system(size: style.iconSize, weight: .medium))
              .foregroundStyle(iconForeground)
          }
        }
        .frame(width: style == .compact ? 38 : 54, height: style == .compact ? 38 : 54)

        Text(item.title)
          .font(style == .compact ? .caption2 : .caption)
          .fontWeight(.medium)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.75)

        if style == .catalog,
          let reason = item.state.availability.reason
        {
          Text(reason)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, minHeight: style.height, alignment: .top)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .opacity(item.state.availability.isAvailable ? 1 : 0.62)
    .help(item.state.availability.reason ?? item.title)
    .accessibilityLabel(item.title)
    .accessibilityValue(accessibilityValue)
    .confirmationDialog(
      "Empty Trash?",
      isPresented: $confirmsDestructiveAction,
      titleVisibility: .visible
    ) {
      Button("Empty Trash", role: .destructive, action: action)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This permanently removes every item in your user Trash.")
    }
  }

  private var iconBackground: Color {
    guard item.state.availability.isAvailable else { return Color.secondary.opacity(0.12) }
    if item.state.isOn == true {
      return Color.accentColor
    }
    return Color.secondary.opacity(0.13)
  }

  private var iconForeground: Color {
    item.state.isOn == true ? .white : .primary
  }

  private var accessibilityValue: String {
    if let reason = item.state.availability.reason {
      return "Unavailable. \(reason)"
    }
    if item.state.isRunning {
      return "Running"
    }
    if let isOn = item.state.isOn {
      return isOn ? "On" : "Off"
    }
    return item.kind == .button ? "Button" : "Action"
  }
}

private struct QuickActionMoreTile: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 5) {
        ZStack {
          Circle()
            .fill(Color.accentColor.opacity(0.16))
          Image(systemName: "ellipsis")
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(Color.accentColor)
        }
        .frame(width: 38, height: 38)
        Text("More")
          .font(.caption2.weight(.medium))
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, minHeight: 72, alignment: .top)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Open all Quick Actions")
    .accessibilityLabel("More Quick Actions")
  }
}
