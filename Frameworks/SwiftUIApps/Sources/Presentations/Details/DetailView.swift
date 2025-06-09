//
//  DetailView.swift
//  SwiftUIApps
//
//  Created by Ahmad Zaky W on 03/06/25.
//

import SwiftUI
import DomainKit
import ZeroDesignKit

public struct DetailView: View {
    @EnvironmentObject var router: AppRouter
    @State private var viewModel: DetailViewModel
    
    public init(viewModel: DetailViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HeaderView(
            config: .init(title: viewModel.state.type.title)) {
                router.pop()
            } trailingItems: {
                HStack {
                    if let kanji = viewModel.state.kanji {
                        levelView(kanji.jlptLevel.rawValue)
                    } else if let kotoba = viewModel.state.kotoba {
                        levelView(kotoba.jlptLevel.rawValue)
                    }
                }
            } content: {
                VStack(spacing: 0) {
                    ScrollView(.vertical) {
                        if let kanji = viewModel.state.kanji {
                            kanjiContent(kanji)
                        }
                        
                        if let kotoba = viewModel.state.kotoba {
                            kotobaContent(kotoba)
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                    
                    DrawerButton(title: "Delete", config: $viewModel.state.drawerButtonConfig)
                        .padding(16)
                        .background(DefaultColors.background.opacity(0.4))
                }
            }
            .background(DefaultColors.background.opacity(0.4))
            .loading(viewModel.state.isLoading)
            .alertDrawer(
                config: $viewModel.state.drawerButtonConfig,
                primaryTitle: "Delete",
                secondaryTitle: "Cancel") {
                    viewModel.send(.didTapDelete({
                        router.pop()
                    }))
                } onSecondaryTapped: {
                    // Do Nothing
                } content: {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("Are you sure?")
                            .font(.title2.bold())
                        
                        Text("You can't undo this action.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 300)
                    }
                }
    }
    
    @ViewBuilder
    func kanjiContent(_ kanji: Kanji) -> some View {
        VStack {
            Text(kanji.kanji)
                .font(.largeTitle)
                .padding()
                .background(DefaultColors.background)
                .clipShape(.rect(cornerRadius: 16))
                .padding()
                .fixedSize()
            
            composeSections("Strokes", content: "\(kanji.stroke) strokes")
            composeSectionLists("Onyomi", content: kanji.onyomi)
            composeSectionLists("Kunyomi", content: kanji.kunyomi)
            composeSectionLists("Meanings", content: kanji.meanings)
            composeSections("Japanese Example", content: kanji.jpExample)
            composeSections("English Example", content: kanji.enExample)
        }
        .padding(16)
        .background(.white)
        .clipShape(.rect(cornerRadius: 16))
        .padding(16)
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    func kotobaContent(_ kotoba: Kotoba) -> some View {
        VStack(spacing: 16) {
            Text(kotoba.kanji)
                .font(.largeTitle)
                .padding()
                .background(DefaultColors.background)
                .clipShape(.rect(cornerRadius: 16))
                .padding()
                .fixedSize()
            
            composeSections("Furigana", content: kotoba.furigana)
            composeSectionLists("Meanings", content: kotoba.english)
            Spacer()
        }
        .padding(16)
        .background(.white)
        .clipShape(.rect(cornerRadius: 16))
        .padding(16)
        .frame(height: 450)
    }
    
    @ViewBuilder
    private func levelView(_ level: String) -> some View {
        Text(level)
            .font(.body.bold())
            .foregroundStyle(.white)
            .padding(8)
            .background(Color.red)
            .clipShape(.rect(cornerRadius: 8))
    }
    
    @ViewBuilder
    private func composeSections(_ title: String, content: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .font(.callout)
                .padding(.leading, 8)
                .frame(width: 100, alignment: .leading)
                .padding([.leading, .vertical], 8)
            
            Text(":")
                .padding(.vertical, 8)
                .font(.caption)
            
            Text(content)
                .font(.callout)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(DefaultColors.background)
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func composeSectionLists(_ title: String, content: [String]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .font(.callout)
                .padding(.leading, 8)
                .frame(width: 100, alignment: .leading)
                .padding([.leading, .vertical], 8)
            
            Text(":")
                .padding(.vertical, 8)
                .font(.caption)
            
            VStack(alignment: .leading) {
                ForEach(content, id: \.self) { data in
                    HStack(spacing: 8) {
                        Text("•")
                            .font(.body)
                        
                        Text(data)
                            .font(.callout)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(DefaultColors.background)
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    AppComposer.shared.makeDetailView(
        .init(
            kotoba: .init(
                id: "123",
                kanji: "asd",
                furigana: "asd",
                english: [
                    "asd",
                    "asd"
                ],
                jlptLevel: .n3
            ),
            kanji: nil
        )
    )
}
