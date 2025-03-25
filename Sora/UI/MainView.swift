//
//  MainView.swift
//  Luna
//
//  Created by 김윤 on 2/23/25.
//

import SwiftUI

struct MainView: View {
    @State static var isOpen: Bool = false
    var body: some View {
        ZStack {
            Color("BackgroundColor")
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Whut.")
            }
            
        }
        .safeAreaInset(edge: .top) {
            VStack(alignment: .center) {
                HStack(alignment: .top) {
                    Spacer()
                    
                }
            }
            .background(.ultraThinMaterial)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    MainView()
}
