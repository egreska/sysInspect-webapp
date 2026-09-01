import UIKit

final class FilterChipView: UIView {
    var onRemove: (() -> Void)?
    
    private let label = UILabel()
    private let removeButton = UIButton(type: .system)
    
    init(title: String) {
        super.init(frame: .zero)
        label.text = title
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        
        removeButton.setTitle("✕", for: .normal)
        removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        
        backgroundColor = UIColor.secondarySystemFill
        layer.cornerRadius = 16
        addSubview(label)
        addSubview(removeButton)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 4),
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func removeTapped() {
        onRemove?()
    }
}
