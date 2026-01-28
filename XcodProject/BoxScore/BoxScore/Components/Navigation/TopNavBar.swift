//
//  TopNavBar.swift
//  BoxScore
//
//  Top navigation bar - black with hamburger, title, profile
//

import SwiftUI

struct TopNavBar: View {
    var onMenuTap: (() -> Void)? = nil
    var onProfileTap: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            // Hamburger menu
            Button {
                onMenuTap?()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // App title - Italics in italic font
            Text("Italics")
                .font(.system(size: 20, weight: .medium))
                .italic()
                .foregroundStyle(.white)
            
            Spacer()
            
            // Profile button - shows auth state
            ProfileButton {
                onProfileTap?()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color.black)
    }
}

#Preview {
    TopNavBar()
}
