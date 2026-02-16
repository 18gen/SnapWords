import SwiftUI
import UIKit
import PhotosUI
import LensCore

private struct MenuHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : .clear)
            .contentShape(Rectangle())
    }
}

private struct CreateMenuSheet: View {
    @Environment(AppLocale.self) private var locale
    var onScanPhoto: () -> Void
    var onCamera: () -> Void
    var onNewFolder: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Group 1: Photo & Camera
            VStack(spacing: 0) {
                createButton(
                    title: locale("menu.scan_photo"),
                    icon: "photo",
                    iconColor: Color.accentColor,
                    action: onScanPhoto
                )
                Divider().padding(.leading, 56)
                createButton(
                    title: locale("import.camera"),
                    icon: "camera",
                    iconColor: Color.accentColor,
                    action: onCamera
                )
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Group 2: Folder
            VStack(spacing: 0) {
                createButton(
                    title: locale("menu.new_folder"),
                    icon: "folder.badge.plus",
                    iconColor: .secondary,
                    action: onNewFolder
                )
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func createButton(title: String, icon: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(MenuHighlightButtonStyle())
    }
}

struct ContentView: View {
    @Binding var captureImage: UIImage?
    @Binding var captureFilename: String?
    @Environment(AppLocale.self) private var locale
    @State private var selectedTab = 0
    @State private var showCreateMenu = false
    @State private var importConfig: ImportSheetConfig?
    @State private var showNewFolder = false
    @State private var showPhotoPicker = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(locale("tab.home"), systemImage: "house.fill", value: 0) {
                HomeView()
            }

            Tab(locale("tab.create"), systemImage: "plus", value: 1) {
                Color.clear
            }

            Tab(locale("tab.library"), systemImage: "books.vertical.fill", value: 2) {
                WordsView(onAddWords: { showCreateMenu = true })
            }

            Tab(locale("tab.settings"), systemImage: "gearshape.fill", value: 3) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 1 {
                selectedTab = oldValue
                showCreateMenu = true
            }
        }
        .onChange(of: captureImage) { _, newValue in
            if newValue != nil {
                selectedTab = 2
                if importConfig == nil {
                    importConfig = ImportSheetConfig(sourceMode: .photo)
                }
            }
        }
        .sheet(isPresented: $showCreateMenu) {
            CreateMenuSheet(
                onScanPhoto: { showCreateMenu = false; showPhotoPicker = true },
                onCamera: { showCreateMenu = false; importConfig = ImportSheetConfig(sourceMode: .camera) },
                onNewFolder: { showCreateMenu = false; showNewFolder = true }
            )
            .environment(locale)
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .sheet(item: $importConfig) { config in
            NavigationStack {
                ImportView(
                    captureImage: $captureImage,
                    captureFilename: $captureFilename,
                    initialSourceMode: config.sourceMode
                )
            }
            .environment(locale)
        }
        .sheet(isPresented: $showNewFolder) {
            FolderFormView()
                .environment(locale)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    captureImage = img
                    pickerItem = nil
                }
            }
        }
    }
}
