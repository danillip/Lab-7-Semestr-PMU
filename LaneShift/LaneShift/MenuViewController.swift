import UIKit

final class MenuViewController: UIViewController {
    private let titleLabel = UILabel()
    private let lanesLabel = UILabel()
    private let lanesControl = UISegmentedControl(items: ["3 полосы", "4 полосы"])
    private let startButton = UIButton(type: .system)

    // Settinfgs
    private var selectedLaneCount: Int = 3

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Верхушка
        titleLabel.text = "LANE SHIFT"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        view.addSubview(titleLabel)

        lanesLabel.text = "Количество полос"
        lanesLabel.textColor = .lightGray
        lanesLabel.textAlignment = .center
        lanesLabel.font = .systemFont(ofSize: 16, weight: .medium)
        view.addSubview(lanesLabel)

        // Переключкалка базированная
        lanesControl.selectedSegmentIndex = 0
        lanesControl.addTarget(self, action: #selector(onLaneChanged), for: .valueChanged)
        view.addSubview(lanesControl)

        startButton.setTitle("Старт", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        startButton.backgroundColor = UIColor(red: 0.18, green: 0.45, blue: 1.0, alpha: 1)
        startButton.layer.cornerRadius = 12
        startButton.layer.masksToBounds = true
        startButton.addTarget(self, action: #selector(onStart), for: .touchUpInside)
        view.addSubview(startButton)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let W = view.bounds.width
        let H = view.bounds.height
        let safe = view.safeAreaInsets

        titleLabel.frame = CGRect(x: 20, y: safe.top + 60, width: W - 40, height: 50)
        lanesLabel.frame = CGRect(x: 20, y: titleLabel.frame.maxY + 30, width: W - 40, height: 22)
        lanesControl.frame = CGRect(x: 40, y: lanesLabel.frame.maxY + 12, width: W - 80, height: 36)
        startButton.frame = CGRect(x: 60, y: H - safe.bottom - 120, width: W - 120, height: 56)
    }

    @objc private func onLaneChanged() {
        selectedLaneCount = (lanesControl.selectedSegmentIndex == 0) ? 3 : 4
    }

    @objc private func onStart() {
        // Вот сюда потом полоски передайте
        let game = GameViewController()
        game.laneCount = selectedLaneCount
        game.modalPresentationStyle = .fullScreen
        present(game, animated: true, completion: nil)
    }
}
