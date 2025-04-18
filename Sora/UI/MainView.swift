//
//  MainView.swift
//  Luna
//
//  Created by 김윤 on 2/23/25.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 홈 탭
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("홈")
                }
                .tag(0)
            
            // 아카이브 탭
            SoraArchiveView()
                .tabItem {
                    Image(systemName: "archivebox.fill")
                    Text("아카이브")
                }
                .tag(1)
        }
        .accentColor(.accentColor)
    }
}

// 홈 화면 뷰 (기존 메인 화면 내용)
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            ZStack {
                // 배경
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // 로고 및 제목
                    VStack(spacing: 15) {
                        Image(systemName: "sparkles.tv.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.accentColor)
                            .padding()
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.2))
                                    .frame(width: 120, height: 120)
                            )
                        
                        Text("소라")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("AI 대화 비서")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // 채팅 목록 버튼
                    NavigationLink(destination: ChatListView()) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.title3)
                            Text("채팅 목록 보기")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.accentColor)
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 40)
                    
                    // 새 채팅 시작 버튼
                    NavigationLink(destination: NewChatView(conversationId: UUID())) {
                        HStack {
                            Image(systemName: "plus.bubble.fill")
                                .font(.title3)
                            Text("새 채팅 시작")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.accentColor, lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(.ultraThinMaterial)
                                )
                        )
                        .foregroundColor(Color.accentColor)
                    }
                    .padding(.horizontal, 40)
                    
                    // 접을 수 있는 메모 테스트 버튼
                    NavigationLink(destination: CollapsibleMemoViewTestScreen()) {
                        HStack {
                            Image(systemName: "note.text")
                                .font(.title3)
                            Text("접을 수 있는 메모 테스트")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.purple, lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(.ultraThinMaterial)
                                )
                        )
                        .foregroundColor(Color.purple)
                    }
                    .padding(.horizontal, 40)
                    
                    // 새 메인 화면 샘플 테스트 버튼
                    NavigationLink(destination: SoraMainView()) {
                        HStack {
                            Image(systemName: "rectangle.3.group")
                                .font(.title3)
                            Text("새 메인 화면 샘플")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.indigo, lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(.ultraThinMaterial)
                                )
                        )
                        .foregroundColor(Color.indigo)
                    }
                    .padding(.horizontal, 40)
                    
                    // 버전 정보
                    Text("Sora v1.0 (WIP)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
                .padding()
            }
            .navigationTitle("소라")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: SoraConversationsDatabase.self, inMemory: true)
}
