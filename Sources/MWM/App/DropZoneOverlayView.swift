import CoreGraphics
import SwiftUI

struct DropZoneOverlayViewModel: Equatable {
    struct ActivationBand: Equatable {
        let topInset: CGFloat
        let height: CGFloat
        let title: String
    }

    struct Section: Equatable, Identifiable {
        let id: String
        let title: String
        let items: [Item]
    }

    struct Item: Equatable, Identifiable {
        let id: String
        let title: String
        let isActive: Bool
    }

    let activationBand: ActivationBand?
    let sections: [Section]

    static func make(
        from zones: [DropZone],
        activeZoneID: String? = nil,
        activationBandFrame: CGRect? = nil,
        screenFrame: CGRect? = nil
    ) -> DropZoneOverlayViewModel {
        let basicItems = zones
            .filter { if case .basic = $0.target { return true } else { return false } }
            .map { Item(id: $0.id, title: $0.title, isActive: $0.id == activeZoneID) }

        var sections: [Section] = []
        if !basicItems.isEmpty {
            sections.append(Section(id: "snap", title: "Snap", items: basicItems))
        }

        let band: ActivationBand?
        if let activationBandFrame {
            band = ActivationBand(
                topInset: screenFrame.map { max(0, activationBandFrame.minY - $0.minY) } ?? 0,
                height: activationBandFrame.height,
                title: L10n.string("dropZone.activationBand")
            )
        } else {
            band = nil
        }

        return DropZoneOverlayViewModel(activationBand: band, sections: sections)
    }
}

struct DropZoneOverlayView: View {
    let model: DropZoneOverlayViewModel

    var body: some View {
        ZStack(alignment: .top) {
            if let band = model.activationBand {
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                        .frame(height: band.height)

                    Text(band.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.top, band.topInset)
                .padding(.horizontal, 28)
            }

            VStack(alignment: .center, spacing: 18) {
                ForEach(model.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 14) {
                            ForEach(section.items) { item in
                                Text(item.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 140, minHeight: 88)
                                    .background(item.isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.16))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(item.isActive ? 0.85 : 0.18), lineWidth: item.isActive ? 2 : 1)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color.clear)
    }
}
