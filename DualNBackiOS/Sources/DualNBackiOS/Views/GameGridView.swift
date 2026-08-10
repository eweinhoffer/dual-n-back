import SwiftUI

struct GameGridView: View {
    let currentDisplayIndex: Int?
    let highlightColor: Color

    var body: some View {
        GeometryReader { geo in
            let cellSize = min(geo.size.width, geo.size.height) / 3 - 6
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { col in
                            let displayIdx = row * 3 + col
                            if displayIdx == 4 {
                                Color.clear
                                    .frame(width: cellSize, height: cellSize)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(currentDisplayIndex == displayIdx
                                          ? highlightColor
                                          : Color.gray.opacity(0.25))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.45), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
