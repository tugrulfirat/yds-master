import SwiftUI
import StoreKit

/// Premium subscription paywall. Prices always come from StoreKit
/// (`product.displayPrice`) so App Store Connect pricing — including the
/// Turkish introductory prices — is the single source of truth.
struct PaywallView: View {
    @EnvironmentObject var premium: PremiumStore
    @EnvironmentObject var store: WordStore
    @Environment(\.dismiss) private var dismiss

    /// Hosted legal documents (required by App Review for subscriptions).
    static let privacyPolicyURL = URL(string: "https://tugrulfirat.github.io/yds-master-legal/privacy.html")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private func planTagline(for productID: String) -> (title: String, badge: String?) {
        switch productID {
        case PremiumStore.ProductID.yearly: return ("Yıllık", "EN İYİ DEĞER")
        case PremiumStore.ProductID.sixMonths: return ("6 Aylık", nil)
        case PremiumStore.ProductID.monthly: return ("Aylık", nil)
        default: return ("Premium", nil)
        }
    }

    var body: some View {
        ZStack {
            Theme.background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    featureList
                    if premium.products.isEmpty {
                        ProgressView()
                            .tint(Theme.accent)
                            .padding(.vertical, 30)
                    } else {
                        planButtons
                    }
                    if let error = premium.lastErrorTR {
                        Text(error)
                            .font(Theme.font(12, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .multilineTextAlignment(.center)
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .onChange(of: premium.isPremium) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Theme.gold.opacity(0.14)))
                .padding(.top, 26)
            Text("YDS Master Premium")
                .font(Theme.font(26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text("İlk \(WordStore.freeWordCount) kelime ücretsiz. Sınavda çıkan \(store.words.count.formatted()) kelimenin tamamı Premium'da.")
                .font(Theme.font(14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("books.vertical.fill", "Geçmiş sınavlardan derlenen \(store.words.count.formatted()) kelimenin tamamı")
            featureRow("chart.line.uptrend.xyaxis", "Tüm CEFR seviyelerinde (A1–C2) sınırsız ilerleme")
            featureRow("gamecontroller.fill", "6 oyun modunun tamamında sınırsız kelime havuzu")
            featureRow("arrow.triangle.2.circlepath", "Aralıklı tekrar sistemi tüm kelimelerde aktif")
        }
        .padding(16)
        .cardStyle(cornerRadius: 18)
    }

    private func featureRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            Text(text)
                .font(Theme.font(13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var planButtons: some View {
        VStack(spacing: 12) {
            ForEach(premium.products, id: \.id) { product in
                let plan = planTagline(for: product.id)
                Button {
                    Haptics.medium()
                    Task { await premium.purchase(product) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(plan.title)
                                    .font(Theme.font(17, weight: .heavy))
                                    .foregroundStyle(Theme.textPrimary)
                                if let badge = plan.badge {
                                    Text(badge)
                                        .font(Theme.font(9, weight: .heavy))
                                        .foregroundStyle(Color(hex: 0x0F1222))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Theme.gold))
                                }
                            }
                            Text(product.displayName)
                                .font(Theme.font(11, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text(product.displayPrice)
                            .font(Theme.font(18, weight: .heavy))
                            .foregroundStyle(Theme.gold)
                    }
                    .padding(16)
                    .arcadePanel(cornerRadius: 16, tint: plan.badge != nil ? Theme.gold : Theme.accent)
                }
                .disabled(premium.purchaseInFlight)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Task { await premium.restorePurchases() }
            } label: {
                Text("Satın Alımları Geri Yükle")
                    .font(Theme.font(14, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            Text("Abonelik, dönem sonunda iptal edilmediği sürece otomatik yenilenir. İstediğin zaman App Store hesap ayarlarından iptal edebilirsin.")
                .font(Theme.font(11))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Link("Gizlilik Politikası", destination: Self.privacyPolicyURL)
                Link("Kullanım Koşulları", destination: Self.termsURL)
            }
            .font(Theme.font(11, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 4)
    }
}
