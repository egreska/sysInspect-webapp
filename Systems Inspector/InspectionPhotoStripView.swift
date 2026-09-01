//
//  InspectionPhotoStripView.swift
//  Systems Inspector
//

import UIKit

protocol InspectionPhotoStripViewDelegate: AnyObject {
    func photoStripDidRemovePhoto(at index: Int)
    func photoStripDidSelectPhoto(at index: Int)
}

final class InspectionPhotoStripView: UIView {
    weak var delegate: InspectionPhotoStripViewDelegate?

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 8
        s.alignment = .top
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPhotos(_ images: [UIImage]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, image) in images.enumerated() {
            stack.addArrangedSubview(makeThumb(image: image, index: index, total: images.count))
        }
        isHidden = images.isEmpty
    }

    private func makeThumb(image: UIImage, index: Int, total: Int) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.separator.cgColor
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Photo \(index + 1) of \(total)"
        imageView.accessibilityTraits = .image
        let tap = UITapGestureRecognizer(target: self, action: #selector(thumbTapped(_:)))
        imageView.addGestureRecognizer(tap)
        imageView.tag = index

        let remove = UIButton(type: .system)
        remove.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        remove.tintColor = .systemRed
        remove.backgroundColor = .clear
        remove.contentHorizontalAlignment = .trailing
        remove.contentVerticalAlignment = .top
        remove.translatesAutoresizingMaskIntoConstraints = false
        remove.tag = index
        remove.accessibilityLabel = "Remove photo \(index + 1) of \(total)"
        remove.addTarget(self, action: #selector(removeTapped(_:)), for: .touchUpInside)

        container.addSubview(imageView)
        container.addSubview(remove)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 80),
            container.heightAnchor.constraint(equalToConstant: 80),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            remove.topAnchor.constraint(equalTo: container.topAnchor),
            remove.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            remove.widthAnchor.constraint(equalToConstant: 44),
            remove.heightAnchor.constraint(equalToConstant: 44)
        ])
        return container
    }

    @objc private func thumbTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag else { return }
        delegate?.photoStripDidSelectPhoto(at: index)
    }

    @objc private func removeTapped(_ sender: UIButton) {
        delegate?.photoStripDidRemovePhoto(at: sender.tag)
    }
}

final class PhotoPreviewViewController: UIViewController {
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "Photo"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Full size inspection photo"
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}
