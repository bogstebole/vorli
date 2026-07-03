// Debug-only screen — compiled out of release builds.
#if DEBUG
//
//  ReceiptHTMLDebugView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI

/// Debug view to see the raw HTML and parsed lines
struct ReceiptHTMLDebugView: View {
    @State private var isLoading = false
    @State private var rawHTML: String = ""
    @State private var preContent: String = ""
    @State private var errorMessage: String?
    
    private let testURL = "https://suf.purs.gov.rs/v/?vl=AzRUOUpOOVZHNFQ5Sk45VkcWxgAA7qwAABCHPQgAAAAAAAABmqbMEogAAABdMzXT8/YZwZB1Ik5vOgoMg+PdpM6Ylru25/vnBD5zKf1ZV/d6qah8NlQf1kEzXglOqc5y7A/37F6E3UO5xPMCKMAg5/tWDRubiMaDaPLK9Fv/DXY6ED/H4TY2pi0sacHTUB30WXX1R5bqQ+4TExniiQRq5CyPFRVrJkBqaP7TEasM6rgFnYNzhKyLljOMa6xHkS3LwqQMIqKvSwuxw3qR3y71b2mOaxrwSC1wN0pDVRfVt7HB1XWEOaK6qOgJw/N5tfRXu6wiiBW/WgIzF364QMUu4vHW3JidwUpxkNcsyuOHboXIk/Q8x1BN1b5SxezE98ycxbhbj2Wicmg+bJVwPdo7vqpM0q7oIyt8gx4N37B0FYi7iYJ0gIXIO9AppmffqmpNSrmZp+aT+SkROHwOIVYIUytcCytaxr3imSlpcTp/BLdhlgugEZ54nNK9eAwfx/PnfwBk8tTSqLj/d0z+HP6H2zeGKQh9qgIfqQSuavmOCuGQqQr4vCHHdwVD6rnCSu56Dw3yscp0+vnexhXenDMvyrVqCrjUDFFTiP068pV4BbW7QCaZPJb3HGW/SI9MgOf/GycOetfEsJyyrPMaVhSKXFBMQBpwo5ggtSy07XxpiULpBf/jExtPtHQc+Gj66duVN99i+G7805twEA7+1SYq2rHB6l6OCks9Cdm21uT5/xKFZJ6UZeibOht1cv4%3D"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Button("Fetch HTML") {
                        Task {
                            await fetchHTML()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    
                    if let error = errorMessage {
                        Text("Error: \(error)")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    
                    if !preContent.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PRE Content (with indentation):")
                                .font(.headline)
                            
                            ScrollView(.horizontal) {
                                Text(preContent)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding()
                                    .background(.quaternary.opacity(0.3))
                            }
                            
                            Divider()
                            
                            Text("Lines (showing first 50 chars + leading spaces):")
                                .font(.headline)
                            
                            let lines = preContent.components(separatedBy: .newlines)
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                let leadingSpaces = line.prefix(while: { $0 == " " }).count
                                let preview = String(line.prefix(50))
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index):")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                    
                                    Text("[\(leadingSpaces)sp]")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.blue)
                                        .frame(width: 50)
                                    
                                    Text(preview)
                                        .font(.system(.caption2, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("HTML Debug")
        }
    }
    
    private func fetchHTML() async {
        isLoading = true
        errorMessage = nil
        rawHTML = ""
        preContent = ""
        
        do {
            guard let url = URL(string: testURL) else {
                errorMessage = "Invalid URL"
                isLoading = false
                return
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                errorMessage = "Could not decode HTML"
                isLoading = false
                return
            }
            
            rawHTML = html
            
            // Extract PRE content
            if let startRange = html.range(of: "<pre"),
               let endRange = html.range(of: "</pre>") {
                let content = html[startRange.upperBound..<endRange.lowerBound]
                let withoutTags = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                preContent = String(withoutTags)
            } else {
                errorMessage = "Could not find <pre> tag"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    ReceiptHTMLDebugView()
}
#endif
