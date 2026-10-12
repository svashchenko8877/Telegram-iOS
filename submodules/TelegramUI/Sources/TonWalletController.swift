import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import SwiftSignalKit
import PresentationDataUtils
import UndoUI

/// A single row in the mock TON wallet transaction history.
private struct TonTransaction {
    enum Direction {
        case incoming
        case outgoing
    }
    let direction: Direction
    let amount: Double
    let counterpartyName: String
    let counterpartyAddress: String
    let comment: String?
    let date: Date
    let isPending: Bool
}

/// Deterministic mock data: stable across app launches (no randomness that changes on
/// every screen open), but varied enough to look like a real history.
private func makeMockTonTransactions() -> [TonTransaction] {
    let now = Date()
    func minutesAgo(_ minutes: Double) -> Date {
        return now.addingTimeInterval(-minutes * 60.0)
    }
    return [
        TonTransaction(direction: .incoming, amount: 128.5, counterpartyName: "Alicia Brown", counterpartyAddress: "UQCa1b...f93X", comment: "Thanks for the design files!", date: minutesAgo(12), isPending: true),
        TonTransaction(direction: .outgoing, amount: 42.0, counterpartyName: "TON DNS", counterpartyAddress: "EQD4F...k2mP", comment: "serhii.ton renewal", date: minutesAgo(95), isPending: false),
        TonTransaction(direction: .incoming, amount: 1000.0, counterpartyName: "Getgems Marketplace", counterpartyAddress: "EQAx2...q7Lw", comment: "NFT sale payout", date: minutesAgo(400), isPending: false),
        TonTransaction(direction: .outgoing, amount: 15.75, counterpartyName: "Dmytro K.", counterpartyAddress: "UQBz9...r4Yt", comment: "Coffee ☕️", date: minutesAgo(720), isPending: false),
        TonTransaction(direction: .outgoing, amount: 3.2, counterpartyName: "Telegram Premium", counterpartyAddress: "EQCk7...m1Nz", comment: nil, date: minutesAgo(1500), isPending: false),
        TonTransaction(direction: .incoming, amount: 64.0, counterpartyName: "Rhodora Villaraza", counterpartyAddress: "UQF2p...v8Hc", comment: "Split the trip", date: minutesAgo(2200), isPending: false),
        TonTransaction(direction: .outgoing, amount: 500.0, counterpartyName: "STON.fi Swap", counterpartyAddress: "EQB7x...t3Wq", comment: "TON → USD₮", date: minutesAgo(4300), isPending: false),
        TonTransaction(direction: .incoming, amount: 9.9, counterpartyName: "Validator Rewards", counterpartyAddress: "Kf8nQ...z5Rb", comment: "Staking payout", date: minutesAgo(8800), isPending: false)
    ]
}

private let mockTonBalance: Double = 2_431.68
private let mockTonBalanceUsd: Double = 7_915.26
private let mockTonAddress = "UQAj3kP9mXz2VhN6qL8sYw1Tf4Rb7Gc0Dn5EpKt2WxM8uQcZ"

private func formatTon(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = amount.truncatingRemainder(dividingBy: 1.0) == 0 ? 0 : 2
    formatter.maximumFractionDigits = 2
    formatter.groupingSeparator = ","
    formatter.usesGroupingSeparator = true
    return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
}

private func formatRelativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

/// Soft, living gradient behind the balance card — reuses the same blob-and-breathe
/// language as the profile aurora, but tuned to TON's own blue/teal palette.
private final class TonBalanceAuroraLayer: CAGradientLayer {
    override init() {
        super.init()
        self.type = .radial
        self.colors = [
            UIColor(rgb: 0x33c9ff).withAlphaComponent(0.85).cgColor,
            UIColor(rgb: 0x0a7ea4).withAlphaComponent(0.55).cgColor,
            UIColor(rgb: 0x0a7ea4).withAlphaComponent(0.0).cgColor
        ]
        self.locations = [0.0, 0.55, 1.0]
        self.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.endPoint = CGPoint(x: 1.0, y: 1.0)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func installBreathing() {
        if UIAccessibility.isReduceMotionEnabled {
            return
        }
        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 0.94
        breathe.toValue = 1.08
        breathe.duration = 5.5
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.add(breathe, forKey: "balanceAuroraBreath")
    }
}

private final class TonBalanceCardView: UIView {
    private let auroraLayer = TonBalanceAuroraLayer()
    private let eyebrowLabel = UILabel()
    private let balanceLabel = UILabel()
    private let usdLabel = UILabel()
    private let addressChip = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private let receiveButton = UIButton(type: .system)

    var addressTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.layer.cornerRadius = 24.0
        self.layer.cornerCurve = .continuous
        self.backgroundColor = UIColor(rgb: 0x0e1621)
        self.layer.addSublayer(self.auroraLayer)

        self.eyebrowLabel.text = "TON BALANCE"
        self.eyebrowLabel.font = .systemFont(ofSize: 12.0, weight: .semibold)
        self.eyebrowLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        self.eyebrowLabel.alpha = 0.0

        self.balanceLabel.text = "💎 \(formatTon(mockTonBalance)) TON"
        self.balanceLabel.font = .systemFont(ofSize: 34.0, weight: .bold)
        self.balanceLabel.textColor = .white
        self.balanceLabel.adjustsFontSizeToFitWidth = true
        self.balanceLabel.minimumScaleFactor = 0.6

        self.usdLabel.text = "≈ $\(formatTon(mockTonBalanceUsd)) USD"
        self.usdLabel.font = .systemFont(ofSize: 15.0, weight: .medium)
        self.usdLabel.textColor = UIColor.white.withAlphaComponent(0.7)

        self.addressChip.setTitle("\(String(mockTonAddress.prefix(6)))…\(String(mockTonAddress.suffix(4)))  􀏃", for: .normal)
        self.addressChip.titleLabel?.font = .systemFont(ofSize: 13.0, weight: .medium)
        self.addressChip.setTitleColor(UIColor.white.withAlphaComponent(0.85), for: .normal)
        self.addressChip.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        self.addressChip.layer.cornerRadius = 14.0
        self.addressChip.addTarget(self, action: #selector(self.addressPressed), for: .touchUpInside)

        self.sendButton.setTitle("↑  Send", for: .normal)
        self.receiveButton.setTitle("↓  Receive", for: .normal)
        for button in [self.sendButton, self.receiveButton] {
            button.titleLabel?.font = .systemFont(ofSize: 15.0, weight: .semibold)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
            button.layer.cornerRadius = 18.0
        }

        self.addSubview(self.eyebrowLabel)
        self.addSubview(self.balanceLabel)
        self.addSubview(self.usdLabel)
        self.addSubview(self.addressChip)
        self.addSubview(self.sendButton)
        self.addSubview(self.receiveButton)

        self.auroraLayer.installBreathing()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func addressPressed() {
        self.addressTapped?()
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1.0, 0.92, 1.0]
        pop.keyTimes = [0.0, 0.3, 1.0]
        pop.duration = 0.25
        self.addressChip.layer.add(pop, forKey: "addressPop")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.auroraLayer.frame = CGRect(x: self.bounds.width - 220.0, y: -60.0, width: 280.0, height: 280.0)

        let padding: CGFloat = 20.0
        var y = padding
        self.eyebrowLabel.frame = CGRect(x: padding, y: y, width: self.bounds.width - padding * 2.0, height: 14.0)
        y += 20.0
        self.balanceLabel.frame = CGRect(x: padding, y: y, width: self.bounds.width - padding * 2.0, height: 42.0)
        y += 42.0
        self.usdLabel.frame = CGRect(x: padding, y: y, width: self.bounds.width - padding * 2.0, height: 20.0)
        y += 30.0
        self.addressChip.frame = CGRect(x: padding, y: y, width: 150.0, height: 28.0)
        y += 44.0

        let buttonWidth = (self.bounds.width - padding * 2.0 - 12.0) / 2.0
        self.sendButton.frame = CGRect(x: padding, y: y, width: buttonWidth, height: 44.0)
        self.receiveButton.frame = CGRect(x: padding + buttonWidth + 12.0, y: y, width: buttonWidth, height: 44.0)
    }

    func preferredHeight() -> CGFloat {
        return 236.0
    }
}

private let tonCellReuseIdentifier = "TonTransactionCell"

private final class TonTransactionCell: UITableViewCell {
    private let iconBackground = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let amountLabel = UILabel()
    private let pendingDot = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.selectionStyle = .none
        self.backgroundColor = .clear

        self.iconBackground.layer.cornerRadius = 20.0
        self.iconLabel.font = .systemFont(ofSize: 18.0)
        self.iconLabel.textAlignment = .center

        self.titleLabel.font = .systemFont(ofSize: 16.0, weight: .medium)
        self.subtitleLabel.font = .systemFont(ofSize: 13.0)
        self.subtitleLabel.numberOfLines = 2

        self.amountLabel.font = .systemFont(ofSize: 16.0, weight: .semibold)
        self.amountLabel.textAlignment = .right

        self.pendingDot.backgroundColor = UIColor(rgb: 0xffa033)
        self.pendingDot.layer.cornerRadius = 3.0
        self.pendingDot.isHidden = true

        self.iconBackground.addSubview(self.iconLabel)
        self.contentView.addSubview(self.iconBackground)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.subtitleLabel)
        self.contentView.addSubview(self.amountLabel)
        self.contentView.addSubview(self.pendingDot)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with transaction: TonTransaction, theme: PresentationTheme) {
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor

        switch transaction.direction {
        case .incoming:
            self.iconBackground.backgroundColor = UIColor(rgb: 0x34c759).withAlphaComponent(0.16)
            self.iconLabel.text = "↓"
            self.iconLabel.textColor = UIColor(rgb: 0x34c759)
            self.amountLabel.text = "+\(formatTon(transaction.amount)) TON"
            self.amountLabel.textColor = UIColor(rgb: 0x34c759)
        case .outgoing:
            self.iconBackground.backgroundColor = theme.list.itemAccentColor.withAlphaComponent(0.14)
            self.iconLabel.text = "↑"
            self.iconLabel.textColor = theme.list.itemAccentColor
            self.amountLabel.text = "−\(formatTon(transaction.amount)) TON"
            self.amountLabel.textColor = theme.list.itemPrimaryTextColor
        }

        self.titleLabel.text = transaction.counterpartyName
        var subtitleParts = [formatRelativeDate(transaction.date), transaction.counterpartyAddress]
        if let comment = transaction.comment {
            subtitleParts.append(comment)
        }
        self.subtitleLabel.text = subtitleParts.joined(separator: " · ")
        self.pendingDot.isHidden = !transaction.isPending
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let padding: CGFloat = 16.0
        self.iconBackground.frame = CGRect(x: padding, y: 14.0, width: 40.0, height: 40.0)
        self.iconLabel.frame = self.iconBackground.bounds

        let textX = padding + 40.0 + 12.0
        let amountWidth: CGFloat = 110.0
        let textWidth = self.contentView.bounds.width - textX - amountWidth - padding

        self.titleLabel.frame = CGRect(x: textX, y: 12.0, width: textWidth, height: 20.0)
        self.subtitleLabel.frame = CGRect(x: textX, y: 33.0, width: textWidth, height: 34.0)
        self.amountLabel.frame = CGRect(x: self.contentView.bounds.width - amountWidth - padding, y: 12.0, width: amountWidth, height: 20.0)
        self.pendingDot.frame = CGRect(x: self.contentView.bounds.width - amountWidth - padding - 10.0, y: 19.0, width: 6.0, height: 6.0)
    }
}

/// "TON" tab: a mock wallet screen with a balance card and a transaction history list.
/// All data is local and fake — there is no network call and no real wallet backing it.
public final class TonWalletController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let transactions: [TonTransaction] = makeMockTonTransactions()

    private var tableView: UITableView?
    private var balanceCard: TonBalanceCardView?

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.tabBarItem.title = "TON"
        self.tabBarItem.image = UIImage(systemName: "diamond.fill")
        self.tabBarItem.selectedImage = UIImage(systemName: "diamond.fill")
        self.title = "TON Wallet"
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func displayNodeDidLoad() {
        super.displayNodeDidLoad()

        let theme = self.presentationData.theme

        self.displayNode.backgroundColor = theme.list.blocksBackgroundColor

        let tableView = UITableView(frame: CGRect(), style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(TonTransactionCell.self, forCellReuseIdentifier: tonCellReuseIdentifier)
        tableView.contentInsetAdjustmentBehavior = .never
        self.displayNode.view.addSubview(tableView)
        self.tableView = tableView

        let balanceCard = TonBalanceCardView()
        balanceCard.addressTapped = { [weak self] in
            self?.copyAddressToClipboard()
        }
        self.balanceCard = balanceCard

        // Header is a plain container so it scrolls away with the list, like a real wallet.
        let headerContainer = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: balanceCard.preferredHeight() + 28.0))
        balanceCard.frame = CGRect(x: 16.0, y: 12.0, width: 100.0 - 32.0, height: balanceCard.preferredHeight())
        headerContainer.addSubview(balanceCard)
        tableView.tableHeaderView = headerContainer
    }

    private func copyAddressToClipboard() {
        UIPasteboard.general.string = mockTonAddress

        let presentationData = self.presentationData
        self.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, position: .bottom, action: { _ in return true }), in: .current)
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        guard let tableView = self.tableView else {
            return
        }
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let frame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationHeight))
        transition.updateFrame(view: tableView, frame: frame)

        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
        tableView.scrollIndicatorInsets = tableView.contentInset

        if let headerContainer = tableView.tableHeaderView, let balanceCard = self.balanceCard {
            let headerHeight = balanceCard.preferredHeight() + 28.0
            if abs(headerContainer.frame.width - layout.size.width) > 0.5 {
                headerContainer.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: headerHeight)
                balanceCard.frame = CGRect(x: 16.0, y: 12.0, width: layout.size.width - 32.0, height: balanceCard.preferredHeight())
                // Re-set tableHeaderView so UITableView re-reads the new size.
                tableView.tableHeaderView = headerContainer
            }
        }
    }
}

extension TonWalletController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.transactions.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: tonCellReuseIdentifier, for: indexPath) as! TonTransactionCell
        cell.configure(with: self.transactions[indexPath.row], theme: self.presentationData.theme)
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68.0
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.layer.animateScale(from: 1.0, to: 0.97, duration: 0.08, completion: { _ in
                cell.layer.animateScale(from: 0.97, to: 1.0, duration: 0.18, timingFunction: kCAMediaTimingFunctionSpring)
            })
        }
    }
}
