import UIKit

final class GameViewController: UIViewController {

    // ========== КОНФИГ ==========
    var laneCount: Int = 3

    private let laneSwitchDuration: TimeInterval = 0.12
    private let laneSwitchDamping: CGFloat = 0.9
    private let playerSizeRatio: CGFloat = 0.12

    private var worldSpeed: CGFloat = 280
    private var timeScale: CGFloat = 1.0
    private var timeScaleTarget: CGFloat = 1.0
    private let timeScaleMin: CGFloat = 0.35
    private let timeScaleLerpSpeed: CGFloat = 8.0

    private var spawnIntervalRange: ClosedRange<TimeInterval> = 0.9...1.2
    private var timeSinceSpawn: TimeInterval = 0
    private var nextSpawnIn: TimeInterval = 1.0

    private var pickupIntervalRange: ClosedRange<TimeInterval> = 0.6...0.9
    private var timeSincePickup: TimeInterval = 0
    private var nextPickupIn: TimeInterval = 0.7

    private let pickupScoreValue: Int = 10

    private let nearMissEligibleWindow: TimeInterval = 0.35
    private let nearMissGapY: CGFloat = 6.0
    private var lastLaneChangeAt: CFTimeInterval = 0
    private var nearMissCooldown: TimeInterval = 0
    private let nearMissCooldownDur: TimeInterval = 0.45

    private var btHoldTimer: TimeInterval = 0
    private let btHoldDur: TimeInterval = 0.55
    private var bulletActive: Bool = false

    // ========== СОСТОЯНИЕ ==========
    private var laneCentersX: [CGFloat] = []
    private var currentLane: Int = 1

    private enum GameState { case ready, running, paused, gameOver }
    private var state: GameState = .ready

    private var score: Int = 0 {
        didSet { scoreLabel.text = "SCORE: \(score)" }
    }

    // ========== ВЬЮХИ ==========
    private let worldView = UIView()
    private let player = UIView()
    private let scoreLabel = UILabel()

    private var backLayer: ParallaxLayerView!
    private var midLayer: ParallaxLayerView!
    private var frontLayer: ParallaxLayerView!

    private let bulletOverlay = UIView()

    // Кнопка паузы
    private let pauseButton = UIButton(type: .system)

    // Оверлей паузы
    private let pauseOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let pauseTitle = UILabel()
    private let btnResume = UIButton(type: .system)
    private let btnRestart = UIButton(type: .system)
    private let btnExit = UIButton(type: .system)

    // ========== ПУЛЫ ==========
    private final class ObstacleView: UIView { }
    private struct Obstacle {
        var view: ObstacleView
        var active: Bool
        var lane: Int
        var nearMissTagged: Bool
    }
    private var obstacles: [Obstacle] = []
    private let obstaclePoolSize = 24

    private final class PickupView: UIView { }
    private struct Pickup {
        var view: PickupView
        var active: Bool
        var lane: Int
    }
    private var pickups: [Pickup] = []
    private let pickupPoolSize = 24

    // ========== ЛУП ==========
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var layoutPrepared = false

    // Хаптик
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)

    // TODO: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Параллакс
        backLayer = ParallaxLayerView(
            speedMultiplier: 0.30,
            topColor: UIColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1),
            bottomColor: UIColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1),
            alpha: 1.0
        )
        midLayer = ParallaxLayerView(
            speedMultiplier: 0.60,
            topColor: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1),
            bottomColor: UIColor(red: 0.10, green: 0.13, blue: 0.20, alpha: 1),
            alpha: 0.9
        )
        frontLayer = ParallaxLayerView(
            speedMultiplier: 0.95,
            topColor: UIColor(red: 0.12, green: 0.15, blue: 0.24, alpha: 1),
            bottomColor: UIColor(red: 0.15, green: 0.19, blue: 0.30, alpha: 1),
            alpha: 0.8
        )
        view.addSubview(backLayer)
        view.addSubview(midLayer)
        view.addSubview(frontLayer)

        // Мир
        worldView.backgroundColor = .clear
        view.addSubview(worldView)

        // Игрок
        player.backgroundColor = .systemBlue
        player.layer.cornerRadius = 8
        player.layer.masksToBounds = true
        worldView.addSubview(player)

        // HUD
        scoreLabel.text = "SCORE: 0"
        scoreLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        scoreLabel.textColor = .white
        scoreLabel.textAlignment = .center
        view.addSubview(scoreLabel)

        // Overlay bullet
        bulletOverlay.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
        bulletOverlay.isUserInteractionEnabled = false
        bulletOverlay.alpha = 0.0
        view.addSubview(bulletOverlay)

        // Кнопка паузы
        configurePauseButton()

        // Жесты
        configureGestures()

        // Пулы
        prewarmObstaclePool()
        prewarmPickupPool()

        // Хаптик
        hapticLight.prepare()
        hapticMedium.prepare()

        configurePauseOverlay()

        // Старт
        startGame()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let full = view.bounds
        backLayer.frame  = full
        midLayer.frame   = full
        frontLayer.frame = full

        worldView.frame = view.bounds.inset(by: view.safeAreaInsets)

        let hudHeight: CGFloat = 28
        scoreLabel.frame = CGRect(x: 0,
                                  y: view.safeAreaInsets.top + 6,
                                  width: view.bounds.width,
                                  height: hudHeight)

        let btnSide: CGFloat = 36
        pauseButton.frame = CGRect(
            x: view.bounds.width - view.safeAreaInsets.right - btnSide - 10,
            y: view.safeAreaInsets.top + 6,
            width: btnSide, height: btnSide
        )
        pauseButton.layer.cornerRadius = btnSide / 2

        bulletOverlay.frame = view.bounds
        pauseOverlay.frame = view.bounds

        if !layoutPrepared {
            layoutPrepared = true
            computeLaneCenters()
            placePlayerInitially()
        }
    }

    // TODO: - UI helpers

    private func configurePauseButton() {
        pauseButton.setTitle("II", for: .normal)
        pauseButton.setTitleColor(.white, for: .normal)
        pauseButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .heavy)
        pauseButton.backgroundColor = UIColor(white: 1, alpha: 0.15)
        pauseButton.addTarget(self, action: #selector(onPauseTapped), for: .touchUpInside)
        view.addSubview(pauseButton)
    }

    private func configurePauseOverlay() {
        pauseOverlay.alpha = 0.0
        pauseOverlay.isHidden = true
        view.addSubview(pauseOverlay)

        pauseTitle.text = "Пауза"
        pauseTitle.textColor = .white
        pauseTitle.font = .systemFont(ofSize: 28, weight: .bold)
        pauseTitle.textAlignment = .center

        [btnResume, btnRestart, btnExit].forEach {
            $0.setTitleColor(.white, for: .normal)
            $0.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
            $0.backgroundColor = UIColor(white: 1, alpha: 0.15)
            $0.layer.cornerRadius = 10
            $0.layer.masksToBounds = true
            pauseOverlay.contentView.addSubview($0)
        }

        btnResume.setTitle("Продолжить", for: .normal)
        btnRestart.setTitle("Рестарт", for: .normal)
        btnExit.setTitle("В меню", for: .normal)

        btnResume.addTarget(self, action: #selector(onResumeTapped), for: .touchUpInside)
        btnRestart.addTarget(self, action: #selector(onRestartTapped), for: .touchUpInside)
        btnExit.addTarget(self, action: #selector(onExitTapped), for: .touchUpInside)

        pauseOverlay.contentView.addSubview(pauseTitle)
    }

    private func layoutPauseOverlay() {
        // Базированный лэйаут
        let W = view.bounds.width
        let H = view.bounds.height
        let safe = view.safeAreaInsets

        pauseTitle.frame = CGRect(x: 20, y: safe.top + 80, width: W - 40, height: 40)

        let btnW = W - 80
        let btnH: CGFloat = 50
        let startY = pauseTitle.frame.maxY + 30
        btnResume.frame  = CGRect(x: 40, y: startY,              width: btnW, height: btnH)
        btnRestart.frame = CGRect(x: 40, y: startY + 60,         width: btnW, height: btnH)
        btnExit.frame    = CGRect(x: 40, y: startY + 120,        width: btnW, height: btnH)
    }

    // TODO: - Полосы/позиции

    private func computeLaneCenters() {
        let w = worldView.bounds.width
        let laneWidth = w / CGFloat(laneCount)
        laneCentersX = (0..<laneCount).map { i in
            CGFloat(i) * laneWidth + laneWidth/2
        }
        // центр для чётных берём лево средний
        currentLane = max(0, min(laneCount-1, laneCount/2))
    }

    private func placePlayerInitially() {
        let side = worldView.bounds.width * playerSizeRatio
        let startX = laneCentersX[currentLane]
        let startY = worldView.bounds.height * 0.78

        player.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        player.center = CGPoint(x: startX, y: startY)
    }

    // TODO: - управление

    private func configureGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(onSwipe(_:)))
        swipeLeft.direction = .left
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(onSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        addKeyCommands()
    }

    @objc private func onSwipe(_ gr: UISwipeGestureRecognizer) {
        guard state == .running else { return }
        switch gr.direction {
        case .left:  moveByLaneDelta(-1)
        case .right: moveByLaneDelta(1)
        default: break
        }
    }

    @objc private func onPan(_ gr: UIPanGestureRecognizer) {
        guard state == .running else { return }
        if gr.state == .ended {
            let v = gr.velocity(in: view)
            if abs(v.x) > abs(v.y) && abs(v.x) > 400 {
                moveByLaneDelta(v.x < 0 ? -1 : 1)
            }
        }
    }

    private func addKeyCommands() {
        let left = UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(onKey(_:)))
        let right = UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(onKey(_:)))
        addKeyCommand(left)
        addKeyCommand(right)
    }
    @objc private func onKey(_ cmd: UIKeyCommand) {
        guard state == .running else { return }
        if cmd.input == UIKeyCommand.inputLeftArrow { moveByLaneDelta(-1) }
        if cmd.input == UIKeyCommand.inputRightArrow { moveByLaneDelta(1) }
    }

    private func moveByLaneDelta(_ d: Int) {
        guard !laneCentersX.isEmpty else { return }
        let next = max(0, min(laneCount - 1, currentLane + d))
        guard next != currentLane else { return }

        currentLane = next
        let targetX = laneCentersX[currentLane]
        lastLaneChangeAt = CACurrentMediaTime()

        let animator = UIViewPropertyAnimator(duration: laneSwitchDuration, dampingRatio: laneSwitchDamping)
        animator.addAnimations { [weak self] in
            self?.player.center.x = targetX
        }
        animator.startAnimation()
    }

    // TODO: - Пауза

    @objc private func onPauseTapped() {
        switch state {
        case .running:
            setPaused(true)
        case .paused:
            setPaused(false)
        default:
            break
        }
    }

    private func setPaused(_ pause: Bool) {
        if pause {
            state = .paused
            // Леха Придумай сам тут
            timeScaleTarget = 1.0
            showPauseOverlay(true)
        } else {
            state = .running
            showPauseOverlay(false)
        }
    }

    private func showPauseOverlay(_ show: Bool) {
        layoutPauseOverlay()
        pauseOverlay.isHidden = false
        let targetAlpha: CGFloat = show ? 1.0 : 0.0
        UIView.animate(withDuration: 0.18, animations: {
            self.pauseOverlay.alpha = targetAlpha
        }, completion: { _ in
            if !show { self.pauseOverlay.isHidden = true }
        })
    }

    @objc private func onResumeTapped() {
        setPaused(false)
    }

    @objc private func onRestartTapped() {
        // быстрый рестарт придумайть
        startGame()
        setPaused(false)
    }

    @objc private func onExitTapped() {
        // Выход в меню сделаю сам
        displayLink?.invalidate()
        displayLink = nil
        dismiss(animated: true, completion: nil)
    }

    // TODO: - Пулы

    private func prewarmObstaclePool() {
        obstacles.reserveCapacity(obstaclePoolSize)
        for _ in 0..<obstaclePoolSize {
            let v = ObstacleView(frame: .zero)
            v.backgroundColor = .systemRed
            v.layer.cornerRadius = 6
            v.layer.masksToBounds = true
            v.isHidden = true
            worldView.addSubview(v)
            obstacles.append(.init(view: v, active: false, lane: 0, nearMissTagged: false))
        }
    }

    private func prewarmPickupPool() {
        pickups.reserveCapacity(pickupPoolSize)
        for _ in 0..<pickupPoolSize {
            let v = PickupView(frame: .zero)
            v.backgroundColor = UIColor.systemTeal
            v.layer.cornerRadius = 10
            v.layer.masksToBounds = true
            v.isHidden = true
            worldView.addSubview(v)
            pickups.append(.init(view: v, active: false, lane: 0))
        }
    }

    private func dequeueObstacle() -> Obstacle? {
        if let idx = obstacles.firstIndex(where: { !$0.active }) { return obstacles[idx] }
        return nil
    }
    private func storeObstacle(_ ob: Obstacle) {
        if let idx = obstacles.firstIndex(where: { $0.view === ob.view }) { obstacles[idx] = ob }
    }

    private func dequeuePickup() -> Pickup? {
        if let idx = pickups.firstIndex(where: { !$0.active }) { return pickups[idx] }
        return nil
    }
    private func storePickup(_ pk: Pickup) {
        if let idx = pickups.firstIndex(where: { $0.view === pk.view }) { pickups[idx] = pk }
    }

    // MARK: - Спавн

    private func spawnObstacle() {
        guard layoutPrepared else { return }
        guard var ob = dequeueObstacle() else { return }

        let lane = Int.random(in: 0..<laneCount)
        let laneCenterX = laneCentersX[lane]

        let laneWidth = worldView.bounds.width / CGFloat(laneCount)
        let width = laneWidth * 0.8
        let height = player.bounds.height

        ob.view.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        ob.view.center = CGPoint(x: laneCenterX, y: -height)
        ob.view.isHidden = false

        ob.active = true
        ob.lane = lane
        ob.nearMissTagged = false
        storeObstacle(ob)
    }

    private func spawnPickup() {
        guard layoutPrepared else { return }
        guard var pk = dequeuePickup() else { return }

        let lane = Int.random(in: 0..<laneCount)
        let laneCenterX = laneCentersX[lane]

        let size = player.bounds.width * 0.55
        pk.view.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        pk.view.layer.cornerRadius = size / 2
        pk.view.center = CGPoint(x: laneCenterX, y: -size)
        pk.view.isHidden = false

        pk.active = true
        pk.lane = lane
        storePickup(pk)
    }

    // MARK: - Старт/Луп/Апдейт

    private func startGame() {
        state = .running
        score = 0

        timeSinceSpawn = 0
        nextSpawnIn = Double.random(in: spawnIntervalRange)
        timeSincePickup = 0
        nextPickupIn = Double.random(in: pickupIntervalRange)

        worldSpeed = 280
        timeScale = 1.0
        timeScaleTarget = 1.0
        bulletActive = false
        btHoldTimer = 0
        nearMissCooldown = 0
        lastLaneChangeAt = 0

        for i in 0..<obstacles.count {
            obstacles[i].active = false
            obstacles[i].view.isHidden = true
            obstacles[i].nearMissTagged = false
        }
        for i in 0..<pickups.count {
            pickups[i].active = false
            pickups[i].view.isHidden = true
        }

        lastTimestamp = 0
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(onTick(_:)))
        link.add(to: .main, forMode: .default)
        displayLink = link

        // если до этого был открыт оверлей паузы (после рестарта) спрячем
        pauseOverlay.isHidden = true
        pauseOverlay.alpha = 0.0
    }

    private func endGame() {
        state = .gameOver
        displayLink?.invalidate()
        displayLink = nil

        let alert = UIAlertController(title: "Game Over", message: "Счёт: \(score)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Restart", style: .default, handler: { [weak self] _ in
            self?.startGame()
        }))
        alert.addAction(UIAlertAction(title: "Menu", style: .cancel, handler: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

    @objc private func onTick(_ link: CADisplayLink) {
        if lastTimestamp == 0 { lastTimestamp = link.timestamp; return }
        let dt = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp

        guard state == .running else { return } // Пауза
        update(delta: dt, now: link.timestamp)
    }

    private func update(delta: TimeInterval, now: CFTimeInterval) {
        // A) timeScale к цели
        let lerpFactor = min(1.0, Double(timeScaleLerpSpeed) * delta)
        timeScale = timeScale + (timeScaleTarget - timeScale) * CGFloat(lerpFactor)

        let clampedTS = max(timeScaleMin, min(1.0, timeScale))
        let t = (1.0 - (clampedTS - timeScaleMin) / (1.0 - timeScaleMin)) // 0..1
        bulletOverlay.alpha = max(0, min(0.35, 0.35 * t))

        if bulletActive {
            btHoldTimer -= delta
            if btHoldTimer <= 0 {
                bulletActive = false
                timeScaleTarget = 1.0
            }
        }
        if nearMissCooldown > 0 { nearMissCooldown -= delta }

        let scaled = CGFloat(delta) * timeScale

        // B) Параллакс
        backLayer.update(baseSpeed: worldSpeed,  delta: scaled)
        midLayer.update(baseSpeed: worldSpeed,   delta: scaled)
        frontLayer.update(baseSpeed: worldSpeed, delta: scaled)

        // C) Препятствия
        var passedObstacles = 0
        for i in 0..<obstacles.count where obstacles[i].active {
            var c = obstacles[i].view.center
            c.y += worldSpeed * scaled
            obstacles[i].view.center = c

            if c.y - obstacles[i].view.bounds.height/2 > worldView.bounds.maxY {
                obstacles[i].active = false
                obstacles[i].view.isHidden = true
                obstacles[i].nearMissTagged = false
                passedObstacles += 1
            }
        }
        if passedObstacles > 0 { score += passedObstacles }

        // D) Пикапы
        for i in 0..<pickups.count where pickups[i].active {
            var c = pickups[i].view.center
            c.y += worldSpeed * scaled
            pickups[i].view.center = c

            if player.frame.intersects(pickups[i].view.frame) {
                pickups[i].active = false
                pickups[i].view.isHidden = true
                onPickupCollected()
                continue
            }
            if c.y - pickups[i].view.bounds.height/2 > worldView.bounds.maxY {
                pickups[i].active = false
                pickups[i].view.isHidden = true
            }
        }

        // E) Столкновения
        for i in 0..<obstacles.count where obstacles[i].active {
            if player.frame.intersects(obstacles[i].view.frame) {
                endGame()
                return
            }
        }

        // F) Near-miss (строго)
        if nearMissCooldown <= 0,
           now - lastLaneChangeAt <= nearMissEligibleWindow,
           checkNearMissStrictAndTag() {
            triggerBulletTime()
        }

        // G) Спавн
        timeSinceSpawn += delta
        if timeSinceSpawn >= nextSpawnIn {
            timeSinceSpawn = 0
            nextSpawnIn = Double.random(in: spawnIntervalRange)
            spawnObstacle()
        }

        timeSincePickup += delta
        if timeSincePickup >= nextPickupIn {
            timeSincePickup = 0
            nextPickupIn = Double.random(in: pickupIntervalRange)
            spawnPickup()
        }

        // H) Рост сложности
        worldSpeed = min(worldSpeed + 0.35 * CGFloat(delta) * 100, 540)
    }

    // TODO: Near-miss & Bullet Time

    private func verticalGap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        max(a.minY - b.maxY, b.minY - a.maxY)
    }

    private func checkNearMissStrictAndTag() -> Bool {
        let pf = player.frame
        for i in 0..<obstacles.count where obstacles[i].active && !obstacles[i].nearMissTagged {
            let laneDiff = abs(obstacles[i].lane - currentLane)
            if laneDiff == 1 {
                let of = obstacles[i].view.frame
                if pf.intersects(of) { continue }
                let gap = verticalGap(pf, of)
                if gap >= 0 && gap <= nearMissGapY {
                    obstacles[i].nearMissTagged = true
                    return true
                }
            }
        }
        return false
    }

    private func triggerBulletTime() {
        bulletActive = true
        btHoldTimer = btHoldDur
        timeScaleTarget = timeScaleMin
        nearMissCooldown = nearMissCooldownDur

        hapticMedium.impactOccurred()
        screenShake(intensity: 2.0, duration: 0.18)
        flashPlayer()
    }

    private func screenShake(intensity: CGFloat, duration: TimeInterval) {
        let original = view.transform
        UIView.animateKeyframes(withDuration: duration, delay: 0, options: [], animations: {
            let steps = 4
            for i in 0..<steps {
                UIView.addKeyframe(withRelativeStartTime: Double(i)/Double(steps),
                                   relativeDuration: 1.0/Double(steps)) {
                    let dx = CGFloat(Int.random(in: -1...1)) * intensity
                    let dy = CGFloat(Int.random(in: -1...1)) * intensity
                    self.view.transform = original.translatedBy(x: dx, y: dy)
                }
            }
        }, completion: { _ in
            self.view.transform = original
        })
    }

    // TODO: - Эффекты

    private func onPickupCollected() {
        score += pickupScoreValue
        hapticLight.impactOccurred()
        flashPlayer()
    }

    private func flashPlayer() {
        let overlay = UIView(frame: player.bounds)
        overlay.backgroundColor = .white
        overlay.alpha = 0.0
        overlay.isUserInteractionEnabled = false
        overlay.layer.cornerRadius = player.layer.cornerRadius
        player.addSubview(overlay)

        let pulse = { self.player.transform = CGAffineTransform(scaleX: 1.12, y: 1.12) }
        let unpulse = { self.player.transform = .identity }

        UIView.animate(withDuration: 0.07, animations: {
            overlay.alpha = 0.35
            pulse()
        }) { _ in
            UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut], animations: {
                overlay.alpha = 0.0
                unpulse()
            }) { _ in
                overlay.removeFromSuperview()
            }
        }
    }
}
