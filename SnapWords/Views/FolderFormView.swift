import SwiftUI
import SwiftData
import LensCore

struct FolderFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocale.self) private var locale

    var folder: Folder?
    var parentFolder: Folder?

    @State private var name: String = ""
    @State private var selectedIcon: String = FolderConstants.icons[0]
    @State private var selectedColor: String = FolderConstants.colors[0]
    @State private var activeTab: PickerTab = .color

    enum PickerTab: String, CaseIterable {
        case color
        case icon
    }

    private var isEditing: Bool { folder != nil }
    private var isSystemFolder: Bool { folder?.isSystem == true }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 12)

                    // MARK: - Folder Preview
                    folderPreview
                        .frame(width: 180, height: 140)

                    // MARK: - Name Field
                    TextField(locale("folder_form.name_placeholder"), text: $name)
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 40)
                        .disabled(isSystemFolder)

                    // MARK: - Segmented Picker
                    Picker("", selection: $activeTab) {
                        Text(locale("folder_form.color"))
                            .tag(PickerTab.color)
                        Text(locale("folder_form.icon"))
                            .tag(PickerTab.icon)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 80)

                    // MARK: - Color / Icon Grid
                    Group {
                        if activeTab == .color {
                            colorRow
                        } else {
                            iconGrid
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale("folder_form.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale("folder_form.save")) {
                        saveFolder()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSystemFolder)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let folder {
                    name = folder.name
                    selectedIcon = folder.iconName
                    selectedColor = folder.colorHex
                }
            }
        }
    }

    private var navigationTitle: String {
        if isEditing {
            return locale("folder_form.edit_title")
        }
        if parentFolder != nil {
            return locale("menu.new_subfolder")
        }
        return locale("folder_form.new_title")
    }

    // MARK: - Folder Preview

    private var folderPreview: some View {
        let color = Color(hex: selectedColor)

        return ZStack {
            // Folder shape
            FolderShape()
                .fill(color)
                .shadow(color: color.opacity(0.4), radius: 12, y: 6)

            // Darker top flap overlay
            FolderFlapShape()
                .fill(color.opacity(0.15))

            // Center icon
            Image(systemName: selectedIcon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .offset(y: 8)
        }
    }

    // MARK: - Color Row

    private var colorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(FolderConstants.colors, id: \.self) { colorHex in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedColor = colorHex
                        }
                    } label: {
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if selectedColor == colorHex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(6)
                            .background {
                                if selectedColor == colorHex {
                                    Circle()
                                        .fill(Color(uiColor: .systemGray4))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Icon Grid

    private var iconGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                ForEach(FolderConstants.icons, id: \.self) { icon in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIcon = icon
                        }
                    } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(Color.clear)
                            .overlay {
                                if selectedIcon == icon {
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color(hex: selectedColor), lineWidth: 2)
                                }
                            }
                            .foregroundStyle(selectedIcon == icon ? Color(hex: selectedColor) : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Save

    private func saveFolder() {
        if let folder {
            guard !folder.isSystem else { return }
            folder.name = name.trimmingCharacters(in: .whitespaces)
            folder.iconName = selectedIcon
            folder.colorHex = selectedColor
        } else {
            let newFolder = Folder(
                name: name.trimmingCharacters(in: .whitespaces),
                iconName: selectedIcon,
                colorHex: selectedColor,
                parent: parentFolder
            )
            modelContext.insert(newFolder)
        }
    }
}
