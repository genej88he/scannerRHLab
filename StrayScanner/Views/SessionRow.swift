//
//  SessionRow.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//

import SwiftUI

struct SessionRow: View {
    var session: Recording
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(sessionTitle())
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 0.0)
                Text(sessionDate())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 0.0)
            }
            Spacer()
        }

    }
    
    private func sessionTitle() -> String {
        if let name = session.name, !name.isEmpty, !name.hasPrefix("Recording ") {
            return name
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        if let created = session.createdAt {
            return dateFormatter.string(from: created)
        } else {
            return "Session"
        }
    }
    
    private func sessionDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        if let created = session.createdAt {
            return dateFormatter.string(from: created)
        }
        return ""
    }
}

