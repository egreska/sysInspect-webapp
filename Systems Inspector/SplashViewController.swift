//
//  SplashViewController.swift
//  Systems Inspector
//
//  Shows app icon and title until Core Data is ready (at least 0.3s), then transitions to the main flow.
//

import UIKit

final class SplashViewController: UIViewController {

    var onComplete: (() -> Void)?

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(named: "LaunchIcon")
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Systems Inspector"
        label.font = .boldSystemFont(ofSize: 32)
        label.textAlignment = .center
        label.textColor = UIColor(named: "LaunchText") ?? AppTheme.primaryContrast
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "LaunchBackground") ?? AppTheme.primary
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            iconImageView.widthAnchor.constraint(equalToConstant: 150),
            iconImageView.heightAnchor.constraint(equalToConstant: 150),
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let startedAt = Date()
        let minimumDuration: TimeInterval = 0.3
        CoreDataManager.shared.waitForStoreToLoad { _ in
            let elapsed = Date().timeIntervalSince(startedAt)
            let delay = max(0, minimumDuration - elapsed)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.onComplete?()
            }
        }
    }
}
