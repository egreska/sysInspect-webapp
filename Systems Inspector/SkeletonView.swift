//
//  SkeletonView.swift
//  Systems Inspector
//
//  Reusable skeleton (shimmer) view for loading states.
//

import UIKit

/// A view that shows a shimmer animation for skeleton loading.
final class SkeletonView: UIView {

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.systemGray5.cgColor,
            UIColor.systemGray6.cgColor,
            UIColor.systemGray5.cgColor
        ]
        layer.locations = [0, 0.5, 1]
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 4
        clipsToBounds = true
        gradientLayer.cornerRadius = 4
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        if gradientLayer.superlayer == nil {
            layer.addSublayer(gradientLayer)
        }
    }

    func startShimmering() {
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-0.5, 0, 0.5]
        animation.toValue = [0.5, 1, 1.5]
        animation.duration = 1.2
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        gradientLayer.add(animation, forKey: "shimmer")
    }

    func stopShimmering() {
        gradientLayer.removeAnimation(forKey: "shimmer")
    }
}

/// Table view cell that displays skeleton placeholders (e.g. for customer or report row).
final class SkeletonCell: UITableViewCell {

    static let reuseId = "SkeletonCell"

    private let line1 = SkeletonView()
    private let line2 = SkeletonView()
    private let line3 = SkeletonView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        selectionStyle = .none
        [line1, line2, line3].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            line1.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            line1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            line1.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            line1.heightAnchor.constraint(equalToConstant: 16),
            line2.topAnchor.constraint(equalTo: line1.bottomAnchor, constant: 8),
            line2.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            line2.widthAnchor.constraint(equalTo: line1.widthAnchor, multiplier: 0.7),
            line2.heightAnchor.constraint(equalToConstant: 12),
            line3.topAnchor.constraint(equalTo: line2.bottomAnchor, constant: 6),
            line3.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            line3.widthAnchor.constraint(equalTo: line1.widthAnchor, multiplier: 0.5),
            line3.heightAnchor.constraint(equalToConstant: 12)
        ])
        // Don't pin bottom at required priority: 12+16+8+12+6+12+12 = 78pt of required
        // height fights UITableView's encapsulated row height (80 / ~79) and spams Auto Layout.
        let bottom = line3.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
        bottom.priority = .defaultHigh
        bottom.isActive = true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            [line1, line2, line3].forEach { $0.startShimmering() }
        } else {
            [line1, line2, line3].forEach { $0.stopShimmering() }
        }
    }
}
