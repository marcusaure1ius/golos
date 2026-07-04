import SwiftUI
import AppKit

// MARK: - Модель панели

@MainActor
final class DictionaryPaneViewModel: ObservableObject {
    @Published var rules: [DictionaryRule] = []

    func reload() async {
        rules = await DictionaryStore.shared.all()
    }

    func add() async {
        await DictionaryStore.shared.add(pattern: "", replacement: "")
        await reload()
    }

    func commit(_ rule: DictionaryRule) {
        Task { await DictionaryStore.shared.update(rule) }
    }

    func delete(_ rule: DictionaryRule) {
        Task {
            await DictionaryStore.shared.delete(id: rule.id)
            await reload()
        }
    }
}

// MARK: - Строка правила

private struct DictionaryRuleRow: View {
    @Binding var rule: DictionaryRule
    let onCommit: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @Environment(\.palette) var p

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $rule.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(p.accent)
                .onChange(of: rule.enabled) { _ in onCommit() }

            field(text: $rule.pattern, placeholder: "слышится как…")
                .opacity(rule.enabled ? 1 : 0.5)
                .onChange(of: rule.pattern) { _ in onCommit() }

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(p.muted2)

            field(text: $rule.replacement, placeholder: "заменить на…")
                .opacity(rule.enabled ? 1 : 0.5)
                .onChange(of: rule.replacement) { _ in onCommit() }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(hovering ? p.ink : p.muted)
                    .frame(width: 28, height: 28)
                    .background(hovering ? p.selection : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Удалить правило")
            .onHover { hovering = $0 }
        }
        .padding(.vertical, 6)
    }

    private func field(text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundStyle(p.ink)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(p.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(p.fieldBorder, lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .onSubmit(onCommit)
    }
}

// MARK: - Панель «Словарь»

struct DictionaryPane: View {
    @StateObject private var vm = DictionaryPaneViewModel()
    @Environment(\.palette) var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Словарь")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(p.ink)

                Text("Замены применяются к распознанному тексту перед вставкой. Совпадение по целым словам, без учёта регистра. Полезно для имён, терминов и слов, которые модель стабильно путает.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(p.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                if vm.rules.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 2) {
                        ForEach($vm.rules) { $rule in
                            DictionaryRuleRow(
                                rule: $rule,
                                onCommit: { vm.commit(rule) },
                                onDelete: { vm.delete(rule) }
                            )
                        }
                    }
                    .padding(.top, 22)
                }

                addButton
                    .padding(.top, 16)
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 38)
            .frame(maxWidth: 712)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .task { await vm.reload() }
    }

    private var addButton: some View {
        Button(action: { Task { await vm.add() } }) {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Добавить правило")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(p.accent)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(p.selection)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Словарь пуст")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(p.ink)
            Text("Добавь правило, чтобы исправлять слова, которые модель распознаёт неверно.")
                .font(.system(size: 13.5))
                .foregroundStyle(p.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}
