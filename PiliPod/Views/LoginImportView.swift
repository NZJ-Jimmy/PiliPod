//
//  LoginImportView.swift
//  PiliPod
//
//  Created by co on 2026/5/21.
//

import SwiftUI
import UniformTypeIdentifiers

struct LoginImportView: View {
    let title: String
    let onImported: () -> Void

    @State private var showImporter = false
    @State private var importError: String?

    init(title: String = "导入登录数据", onImported: @escaping () -> Void) {
        self.title = title
        self.onImported = onImported
    }

    var body: some View {
        Button(title) {
            showImporter = true
        }
        .alert("导入失败", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("确定") { importError = nil }
        } message: { Text(importError ?? "") }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                do {
                    try LoginImportService.importFrom(url: url)
                    onImported()
                } catch {
                    importError = error.localizedDescription
                }

            case .failure(let error):
                importError = error.localizedDescription
            }
        }
    }
}
